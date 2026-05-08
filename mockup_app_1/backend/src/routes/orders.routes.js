import { Router } from 'express';

import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { admin } from '../config/firebaseAdmin.js';
import { col, docToJson, queryToJson, serverTimestamp } from '../utils/firestoreHelpers.js';
import { sendPushToUser } from '../utils/fcmHelper.js';
import { asyncHandler } from '../utils/errors.js';

export const ordersRouter = Router();

// SECURITY: Define valid order status transitions
const orderStateTransitions = {
  created: {
    seller: ['in_transit', 'cancelled'],
    buyer: ['cancelled'],
    admin: ['in_transit', 'cancelled', 'disputed'],
  },
  in_transit: {
    seller: ['delivered'],
    buyer: ['disputed'],
    admin: ['delivered', 'disputed', 'cancelled'],
  },
  delivered: {
    seller: [],
    buyer: ['completed', 'disputed'],
    admin: ['completed', 'disputed'],
  },
  completed: {
    seller: [],
    buyer: [],
    admin: ['disputed'],
  },
  cancelled: {
    seller: [],
    buyer: [],
    admin: [],
  },
  disputed: {
    seller: [],
    buyer: [],
    admin: ['completed', 'cancelled'],
  },
};

function getActorRole(order, userId, userRole) {
  if (userRole === 'admin') return 'admin';
  if (order.buyerUid === userId) return 'buyer';
  if (order.sellerUid === userId) return 'seller';
  return null;
}

function canTransitionOrder(currentStatus, nextStatus, actorRole) {
  if (!actorRole) return false;
  const allowed = orderStateTransitions[currentStatus]?.[actorRole] || [];
  return allowed.includes(nextStatus);
}

ordersRouter.get('/me', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  // Firestore doesn't support $or, so we query twice and merge
  const [buyerSnap, sellerSnap] = await Promise.all([
    col('orders').where('buyerUid', '==', req.user.uid).get(),
    col('orders').where('sellerUid', '==', req.user.uid).get(),
  ]);

  const seen = new Set();
  const all = [];

  for (const snap of [buyerSnap, sellerSnap]) {
    for (const doc of snap.docs) {
      if (!seen.has(doc.id)) {
        seen.add(doc.id);
        all.push(docToJson(doc));
      }
    }
  }

  // Sort by createdAt desc
  all.sort((a, b) => {
    const da = a.createdAt ? new Date(a.createdAt).getTime() : 0;
    const db = b.createdAt ? new Date(b.createdAt).getTime() : 0;
    return db - da;
  });

  // Batch-fetch listing data so each order card can show the crop name
  const listingIds = [...new Set(all.map((o) => o.listingId).filter(Boolean))];
  const listingMap = new Map();
  if (listingIds.length > 0) {
    const refs = listingIds.map((id) => col('listings').doc(id));
    const snaps = await admin.firestore().getAll(...refs);
    snaps.forEach((snap) => {
      if (snap.exists) listingMap.set(snap.id, snap.data());
    });
  }

  const enriched = all.map((order) => ({
    ...order,
    cropName: listingMap.get(order.listingId)?.cropName ?? '',
    listingDistrict: listingMap.get(order.listingId)?.district ?? '',
  }));

  res.json(enriched);
}));

ordersRouter.patch('/:id/status', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  const docRef = col('orders').doc(req.params.id);
  const snap = await docRef.get();
  if (!snap.exists) {
    res.status(404).json({ message: 'Order not found' });
    return;
  }

  const order = snap.data();

  // SECURITY: Determine actor role
  const actorRole = getActorRole(order, req.user.uid, req.dbUser.role);
  if (!actorRole) {
    res.status(403).json({ message: 'Forbidden: not a participant in this order' });
    return;
  }

  const nextStatus = String(req.body?.status || '').trim();

  // SECURITY: Validate status transition using state machine
  if (!canTransitionOrder(order.status, nextStatus, actorRole)) {
    res.status(409).json({
      message: 'Invalid status transition',
      currentStatus: order.status,
      requestedStatus: nextStatus,
      actorRole,
      allowedTransitions: orderStateTransitions[order.status]?.[actorRole] || [],
    });
    return;
  }

  await docRef.update({ status: nextStatus, updatedAt: serverTimestamp() });
  const updated = await docRef.get();

  // Notify the counterpart about the status change
  try {
    const counterpartUid = req.user.uid === order.buyerUid ? order.sellerUid : order.buyerUid;
    const shortId = req.params.id.substring(0, 8).toUpperCase();
    const statusLabel = nextStatus.replace(/_/g, ' ');
    await sendPushToUser(
      counterpartUid,
      `Order #${shortId} Updated`,
      `Order status changed to: ${statusLabel}`,
      { type: 'order_status', orderId: req.params.id, status: nextStatus },
    );
  } catch (err) {
    console.error('FCM notify error (order status):', err.message);
  }

  res.json(docToJson(updated));
}));
