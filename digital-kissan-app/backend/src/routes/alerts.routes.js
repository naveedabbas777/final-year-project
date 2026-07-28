import { Router } from 'express';

import { requireAuth } from '../middlewares/auth.js';
import { listUserAlerts } from '../services/weatherAlerts.service.js';
import { admin } from '../config/firebaseAdmin.js';

export const alertsRouter = Router();

function serializeAlert(doc) {
  const createdAt = doc.createdAt?.toDate ? doc.createdAt.toDate().toISOString() : (doc.createdAt ? new Date(doc.createdAt).toISOString() : null);
  const readAt = doc.readAt?.toDate ? doc.readAt.toDate().toISOString() : (doc.readAt ? new Date(doc.readAt).toISOString() : null);

  return {
    ...doc,
    createdAt,
    readAt,
  };
}

alertsRouter.get('/', requireAuth, async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 50, 100);
    const alerts = await listUserAlerts(req.user.uid, limit);
    res.json(alerts.map(serializeAlert));
  } catch (err) {
    next(err);
  }
});

alertsRouter.patch('/:id/read', requireAuth, async (req, res, next) => {
  try {
    const id = String(req.params.id || '').trim();
    if (!id) {
      res.status(400).json({ message: 'Alert id is required' });
      return;
    }

    const ref = admin.firestore().collection('weather_alerts').doc(id);
    const snap = await ref.get();
    if (!snap.exists || snap.data()?.userId !== req.user.uid) {
      res.status(404).json({ message: 'Alert not found' });
      return;
    }

    await ref.set(
      {
        read: true,
        readAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    res.json({ message: 'Alert marked as read' });
  } catch (err) {
    next(err);
  }
});