import { Router } from 'express';

import { admin } from '../config/firebaseAdmin.js';
import { requireAuth } from '../middlewares/auth.js';

export const messagesRouter = Router();

function firestoreReady() {
  return Boolean(admin?.apps && admin.apps.length > 0);
}

messagesRouter.get('/', requireAuth, async (req, res, next) => {
  try {
    if (!firestoreReady()) {
      res.status(503).json({ message: 'Firestore is not available on the backend' });
      return;
    }

    const limit = Math.min(Number(req.query.limit) || 20, 100);
    const snapshot = await admin
      .firestore()
      .collection('messages')
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .get();

    const rows = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(rows.reverse());
  } catch (err) {
    next(err);
  }
});

messagesRouter.post('/', requireAuth, async (req, res, next) => {
  try {
    if (!firestoreReady()) {
      res.status(503).json({ message: 'Firestore is not available on the backend' });
      return;
    }

    const message = String(req.body?.message || '').trim();
    if (!message) {
      res.status(400).json({ message: 'Message is required' });
      return;
    }

    const doc = await admin.firestore().collection('messages').add({
      message,
      userId: req.user.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.status(201).json({ id: doc.id, message });
  } catch (err) {
    next(err);
  }
});