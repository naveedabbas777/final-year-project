import { Router } from 'express';

import { OrderModel } from '../models/order.model.js';
import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';

export const ordersRouter = Router();

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

  const isParticipant =
    order.buyerUid === req.user.uid ||
    order.sellerUid === req.user.uid ||
    req.dbUser.role === 'admin';

  if (!isParticipant) {
    res.status(403).json({ message: 'Forbidden' });
    return;
  }

  const allowed = ['created', 'in_transit', 'delivered', 'completed', 'cancelled', 'disputed'];
  const nextStatus = String(req.body?.status || '');

  if (!allowed.includes(nextStatus)) {
    res.status(400).json({ message: 'Invalid status' });
    return;
  }

  order.status = nextStatus;
  await order.save();

  res.json(order);
});
