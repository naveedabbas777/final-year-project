import { Router } from 'express';

import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { admin } from '../config/firebaseAdmin.js';
import { col, docToJson, queryToJson, serverTimestamp } from '../utils/firestoreHelpers.js';
import { sendPushToUsers } from '../utils/fcmHelper.js';
import { asyncHandler } from '../utils/errors.js';
import { validateListingInput } from '../utils/validators.js';

export const listingsRouter = Router();

function parseCursorDate(value) {
  if (typeof value !== 'string' || !value.trim()) return null;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed;
}

listingsRouter.get('/', asyncHandler(async (req, res) => {
  const {
    crop,
    district,
    sellerUid,
    status,
    sort = 'new',
    limit = 50,
    before,
  } = req.query;

  let query = col('listings');

  if (typeof crop === 'string' && crop.trim()) {
    query = query.where('cropName', '==', crop.trim());
  }
  if (typeof district === 'string' && district.trim()) {
    query = query.where('district', '==', district.trim());
  }
  if (typeof sellerUid === 'string' && sellerUid.trim()) {
    query = query.where('sellerUid', '==', sellerUid.trim());
  }
  if (typeof status === 'string' && status.trim() && status.trim() !== 'all') {
    query = query.where('status', '==', status.trim());
  }

  if (sort === 'price_asc') {
    query = query.orderBy('askingPrice', 'asc');
  } else if (sort === 'price_desc') {
    query = query.orderBy('askingPrice', 'desc');
  } else {
    query = query.orderBy('createdAt', 'desc');
    const cursor = parseCursorDate(before);
    if (cursor) {
      query = query.startAfter(cursor);
    }
  }

  query = query.limit(Math.min(Number(limit) || 50, 200));

  const snapshot = await query.get();
  res.json(queryToJson(snapshot));
}));

listingsRouter.post('/', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  const payload = req.body || {};

  // Validate input before processing
  const errors = validateListingInput(payload);
  if (errors) {
    res.status(400).json({ message: 'Validation failed', fields: errors });
    return;
  }

  const data = {
    sellerUid: req.user.uid,
    cropName: payload.cropName,
    qualityGrade: payload.qualityGrade || 'A',
    quantity: Number(payload.quantity),
    unit: payload.unit || '40kg',
    askingPrice: Number(payload.askingPrice),
    district: payload.district,
    locationName: typeof payload.locationName === 'string' ? payload.locationName.trim() : '',
    latitude: payload.latitude != null ? Number(payload.latitude) : null,
    longitude: payload.longitude != null ? Number(payload.longitude) : null,
    description: payload.description || '',
    imageUrls: Array.isArray(payload.imageUrls) ? payload.imageUrls : [],
    status: 'open',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const docRef = await col('listings').add(data);
  const snap = await docRef.get();
  res.status(201).json(docToJson(snap));
}));

listingsRouter.patch('/:id', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  const docRef = col('listings').doc(req.params.id);
  const snap = await docRef.get();
  if (!snap.exists) {
    res.status(404).json({ message: 'Listing not found' });
    return;
  }

  const listing = snap.data();
  if (listing.sellerUid !== req.user.uid && req.dbUser.role !== 'admin') {
    res.status(403).json({ message: 'Only seller or admin can update listing' });
    return;
  }

  const payload = req.body || {};
  const updates = { updatedAt: serverTimestamp() };
  const textFields = ['cropName', 'qualityGrade', 'unit', 'district', 'locationName', 'description'];

  textFields.forEach((field) => {
    if (typeof payload[field] === 'string' && payload[field].trim()) {
      updates[field] = payload[field].trim();
    }
  });

  if (payload.quantity != null) {
    const quantity = Number(payload.quantity);
    if (!Number.isNaN(quantity)) updates.quantity = quantity;
  }

  if (payload.askingPrice != null) {
    const askingPrice = Number(payload.askingPrice);
    if (!Number.isNaN(askingPrice)) updates.askingPrice = askingPrice;
  }

  if (payload.latitude != null) {
    const latitude = Number(payload.latitude);
    if (!Number.isNaN(latitude)) updates.latitude = latitude;
  }

  if (payload.longitude != null) {
    const longitude = Number(payload.longitude);
    if (!Number.isNaN(longitude)) updates.longitude = longitude;
  }

  if (Array.isArray(payload.imageUrls)) {
    updates.imageUrls = payload.imageUrls.filter((url) => typeof url === 'string' && url.trim());
  }

  await docRef.update(updates);
  const updated = await docRef.get();
  res.json(docToJson(updated));
}));

listingsRouter.patch('/:id/status', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  const docRef = col('listings').doc(req.params.id);
  const snap = await docRef.get();
  if (!snap.exists) {
    res.status(404).json({ message: 'Listing not found' });
    return;
  }

  const listing = snap.data();
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

  await docRef.update({ status: nextStatus, updatedAt: serverTimestamp() });
  const updated = await docRef.get();

  // Notify users who have pending offers on this listing about the status change
  try {
    const offersSnap = await col('offers')
      .where('listingId', '==', req.params.id)
      .where('status', '==', 'pending')
      .get();
    const buyerUids = [...new Set(offersSnap.docs.map((d) => d.data().buyerUid).filter(Boolean))];
    if (buyerUids.length > 0) {
      const statusLabel = nextStatus.replace(/_/g, ' ');
      await sendPushToUsers(
        buyerUids,
        `Listing ${statusLabel.charAt(0).toUpperCase() + statusLabel.slice(1)}`,
        `A listing for ${listing.cropName} you offered on is now ${statusLabel}.`,
        { type: 'listing_status', listingId: req.params.id, status: nextStatus },
      );
    }
  } catch (err) {
    console.error('FCM notify error (listing status):', err.message);
  }

  res.json(docToJson(updated));
}));

listingsRouter.delete('/:id', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  const docRef = col('listings').doc(req.params.id);
  const snap = await docRef.get();
  if (!snap.exists) {
    res.status(404).json({ message: 'Listing not found' });
    return;
  }

  const listing = snap.data();
  if (listing.sellerUid !== req.user.uid && req.dbUser.role !== 'admin') {
    res.status(403).json({ message: 'Only seller or admin can delete listing' });
    return;
  }

  // Cancel all pending offers on this listing before deleting it.
  // Without this, buyers see stale 'Pending' offers for a deleted listing.
  try {
    const pendingOffers = await col('offers')
      .where('listingId', '==', req.params.id)
      .where('status', '==', 'pending')
      .get();
    if (!pendingOffers.empty) {
      const batch = admin.firestore().batch();
      pendingOffers.docs.forEach((d) =>
        batch.update(d.ref, { status: 'cancelled', updatedAt: serverTimestamp() }),
      );
      await batch.commit();
    }
  } catch (err) {
    console.error('Failed to cancel offers on listing delete:', err.message);
  }

  await docRef.delete();
  res.json({ message: 'Listing deleted', id: req.params.id });
}));
