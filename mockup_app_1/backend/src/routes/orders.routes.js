import { Router } from 'express';

import { OrderModel } from '../models/order.model.js';
import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';

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

ordersRouter.get('/me', requireAuth, attachDbUser, async (req, res) => {
  const rows = await OrderModel.find({
    $or: [{ buyerUid: req.user.uid }, { sellerUid: req.user.uid }],
  }).sort({ createdAt: -1 });

  res.json(rows);
});

ordersRouter.patch('/:id/status', requireAuth, attachDbUser, async (req, res) => {
  const order = await OrderModel.findById(req.params.id);
  if (!order) {
    res.status(404).json({ message: 'Order not found' });
    return;
  }

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

  order.status = nextStatus;
  order.updatedAt = new Date();
  await order.save();

  res.json(order);
});
