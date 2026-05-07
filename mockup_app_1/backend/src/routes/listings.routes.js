import { Router } from 'express';

import { ListingModel } from '../models/listing.model.js';
import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';

export const listingsRouter = Router();

listingsRouter.get('/', async (req, res) => {
  const {
    crop,
    district,
    sellerUid,
    status,
    sort = 'new',
    limit = 50,
  } = req.query;

  const query = {};
  if (typeof crop === 'string' && crop.trim()) query.cropName = crop.trim();
  if (typeof district === 'string' && district.trim()) {
    query.district = district.trim();
  }
  if (typeof sellerUid === 'string' && sellerUid.trim()) {
    query.sellerUid = sellerUid.trim();
  }
  if (typeof status === 'string' && status.trim() && status.trim() !== 'all') query.status = status.trim();

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
    latitude: payload.latitude != null ? Number(payload.latitude) : null,
    longitude: payload.longitude != null ? Number(payload.longitude) : null,
    description: payload.description || '',
    imageUrls: Array.isArray(payload.imageUrls) ? payload.imageUrls : [],
    status: 'open',
  });

  res.status(201).json(row);
});

listingsRouter.patch('/:id', requireAuth, attachDbUser, async (req, res) => {
  const listing = await ListingModel.findById(req.params.id);
  if (!listing) {
    res.status(404).json({ message: 'Listing not found' });
    return;
  }

  if (listing.sellerUid !== req.user.uid && req.dbUser.role !== 'admin') {
    res.status(403).json({ message: 'Only seller or admin can update listing' });
    return;
  }

  const payload = req.body || {};
  const textFields = ['cropName', 'qualityGrade', 'unit', 'district', 'description'];

  textFields.forEach((field) => {
    if (typeof payload[field] === 'string' && payload[field].trim()) {
      listing[field] = payload[field].trim();
    }
  });

  if (payload.quantity != null) {
    const quantity = Number(payload.quantity);
    if (!Number.isNaN(quantity)) {
      listing.quantity = quantity;
    }
  }

  if (payload.askingPrice != null) {
    const askingPrice = Number(payload.askingPrice);
    if (!Number.isNaN(askingPrice)) {
      listing.askingPrice = askingPrice;
    }
  }

  if (payload.latitude != null) {
    const latitude = Number(payload.latitude);
    if (!Number.isNaN(latitude)) {
      listing.latitude = latitude;
    }
  }

  if (payload.longitude != null) {
    const longitude = Number(payload.longitude);
    if (!Number.isNaN(longitude)) {
      listing.longitude = longitude;
    }
  }

  if (Array.isArray(payload.imageUrls)) {
    listing.imageUrls = payload.imageUrls.filter((url) => typeof url === 'string' && url.trim());
  }

  await listing.save();
  res.json(listing);
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

listingsRouter.delete('/:id', requireAuth, attachDbUser, async (req, res) => {
  const listing = await ListingModel.findById(req.params.id);
  if (!listing) {
    res.status(404).json({ message: 'Listing not found' });
    return;
  }

  if (listing.sellerUid !== req.user.uid && req.dbUser.role !== 'admin') {
    res.status(403).json({ message: 'Only seller or admin can delete listing' });
    return;
  }

  await listing.deleteOne();
  res.json({ message: 'Listing deleted', id: req.params.id });
});
