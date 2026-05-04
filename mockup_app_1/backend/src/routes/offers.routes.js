import { Router } from 'express';

import { OfferModel } from '../models/offer.model.js';
import { ListingModel } from '../models/listing.model.js';
import { OrderModel } from '../models/order.model.js';
import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';

export const offersRouter = Router();

offersRouter.get('/me', requireAuth, attachDbUser, async (req, res) => {
  const rows = await OfferModel.find({ buyerUid: req.user.uid })
    .populate('listingId')
    .sort({ createdAt: -1 });

  res.json(rows);
});

offersRouter.get('/incoming', requireAuth, attachDbUser, async (req, res) => {
  const myListings = await ListingModel.find({ sellerUid: req.user.uid }).select('_id');
  const listingIds = myListings.map((row) => row._id);

  const rows = await OfferModel.find({ listingId: { $in: listingIds } })
    .populate('listingId')
    .sort({ createdAt: -1 });

  res.json(rows);
});

offersRouter.post('/', requireAuth, attachDbUser, async (req, res) => {
  const payload = req.body || {};

  const listing = await ListingModel.findById(payload.listingId);
  if (!listing) {
    res.status(404).json({ message: 'Listing not found' });
    return;
  }

  if (listing.status !== 'open') {
    res.status(400).json({ message: 'Listing is not open for offers' });
    return;
  }

  if (listing.sellerUid === req.user.uid) {
    res.status(400).json({ message: 'Seller cannot place an offer on own listing' });
    return;
  }

  const offer = await OfferModel.create({
    listingId: listing._id,
    buyerUid: req.user.uid,
    buyerRef: req.dbUser._id,
    offerPrice: Number(payload.offerPrice),
    quantity: Number(payload.quantity),
    status: 'pending',
  });

  res.status(201).json(offer);
});

offersRouter.post('/:id/accept', requireAuth, attachDbUser, async (req, res) => {
  const offer = await OfferModel.findById(req.params.id);
  if (!offer) {
    res.status(404).json({ message: 'Offer not found' });
    return;
  }

  const listing = await ListingModel.findById(offer.listingId);
  if (!listing) {
    res.status(404).json({ message: 'Listing not found' });
    return;
  }

  if (listing.sellerUid !== req.user.uid && req.dbUser.role !== 'admin') {
    res.status(403).json({ message: 'Only seller can accept this offer' });
    return;
  }

  if (offer.status !== 'pending') {
    res.status(400).json({ message: 'Offer is not pending' });
    return;
  }

  offer.status = 'accepted';
  await offer.save();

  await OfferModel.updateMany(
    { listingId: listing._id, _id: { $ne: offer._id }, status: 'pending' },
    { $set: { status: 'rejected' } },
  );

  listing.status = 'reserved';
  await listing.save();

  const order = await OrderModel.create({
    listingId: listing._id,
    offerId: offer._id,
    buyerUid: offer.buyerUid,
    sellerUid: listing.sellerUid,
    finalPrice: offer.offerPrice,
    quantity: offer.quantity,
    unit: listing.unit,
    status: 'created',
  });

  res.json({ message: 'Offer accepted', order });
});

offersRouter.post('/:id/reject', requireAuth, attachDbUser, async (req, res) => {
  const offer = await OfferModel.findById(req.params.id);
  if (!offer) {
    res.status(404).json({ message: 'Offer not found' });
    return;
  }

  const listing = await ListingModel.findById(offer.listingId);
  if (!listing) {
    res.status(404).json({ message: 'Listing not found' });
    return;
  }

  if (listing.sellerUid !== req.user.uid && req.dbUser.role !== 'admin') {
    res.status(403).json({ message: 'Only seller can reject this offer' });
    return;
  }

  if (offer.status !== 'pending') {
    res.status(400).json({ message: 'Offer is not pending' });
    return;
  }

  offer.status = 'rejected';
  await offer.save();

  res.json({ message: 'Offer rejected', offer });
});

offersRouter.post('/:id/cancel', requireAuth, attachDbUser, async (req, res) => {
  const offer = await OfferModel.findById(req.params.id);
  if (!offer) {
    res.status(404).json({ message: 'Offer not found' });
    return;
  }

  if (offer.buyerUid !== req.user.uid && req.dbUser.role !== 'admin') {
    res.status(403).json({ message: 'Only buyer can cancel this offer' });
    return;
  }

  if (offer.status !== 'pending') {
    res.status(400).json({ message: 'Only pending offers can be cancelled' });
    return;
  }

  offer.status = 'cancelled';
  await offer.save();

  res.json({ message: 'Offer cancelled', offer });
});
