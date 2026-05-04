import { Router } from 'express';

import { ListingModel } from '../models/listing.model.js';
import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';

export const listingsRouter = Router();

listingsRouter.get('/', async (req, res) => {
  const {
    crop,
    district,
    status = 'open',
    sort = 'new',
    limit = 50,
  } = req.query;

  const query = {};
  if (typeof crop === 'string' && crop.trim()) query.cropName = crop.trim();
  if (typeof district === 'string' && district.trim()) {
    query.district = district.trim();
  }
  if (typeof status === 'string' && status.trim()) query.status = status.trim();

  const order = sort === 'price_asc' ? { askingPrice: 1 } : sort === 'price_desc' ? { askingPrice: -1 } : { createdAt: -1 };

  const rows = await ListingModel.find(query)
    .sort(order)
    .limit(Math.min(Number(limit) || 50, 200));

  res.json(rows);
});

listingsRouter.post('/', requireAuth, attachDbUser, async (req, res) => {
  const payload = req.body || {};

  const row = await ListingModel.create({
    sellerUid: req.user.uid,
    sellerRef: req.dbUser._id,
    cropName: payload.cropName,
    qualityGrade: payload.qualityGrade || 'A',
    quantity: Number(payload.quantity),
    unit: payload.unit || '40kg',
    askingPrice: Number(payload.askingPrice),
    district: payload.district,
    description: payload.description || '',
    imageUrls: Array.isArray(payload.imageUrls) ? payload.imageUrls : [],
    status: 'open',
  });

  res.status(201).json(row);
});

listingsRouter.patch('/:id/status', requireAuth, attachDbUser, async (req, res) => {
  const listing = await ListingModel.findById(req.params.id);
  if (!listing) {
    res.status(404).json({ message: 'Listing not found' });
    return;
  }

  if (listing.sellerUid !== req.user.uid && req.dbUser.role !== 'admin') {
    res.status(403).json({ message: 'Only seller or admin can update listing' });
    return;
  }

  const allowed = ['open', 'reserved', 'sold', 'cancelled'];
  const nextStatus = String(req.body?.status || '');
  if (!allowed.includes(nextStatus)) {
    res.status(400).json({ message: 'Invalid status' });
    return;
  }

  listing.status = nextStatus;
  await listing.save();

  res.json(listing);
});
