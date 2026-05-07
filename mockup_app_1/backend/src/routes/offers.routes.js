import { Router } from 'express';

import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { admin } from '../config/firebaseAdmin.js';
import { col, docToJson, queryToJson, serverTimestamp } from '../utils/firestoreHelpers.js';
import { sendPushToUser } from '../utils/fcmHelper.js';
import { asyncHandler } from '../utils/errors.js';
import { validateOfferInput } from '../utils/validators.js';

export const offersRouter = Router();

offersRouter.get('/me', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  const snapshot = await col('offers')
    .where('buyerUid', '==', req.user.uid)
    .orderBy('createdAt', 'desc')
    .get();

  const offers = queryToJson(snapshot);

  // Batch-fetch listing data (fixes N+1 query)
  const listingIds = [...new Set(offers.map((o) => o.listingId).filter(Boolean))];
  const listingMap = new Map();
  if (listingIds.length > 0) {
    const refs = listingIds.map(id => col('listings').doc(id));
    const snaps = await admin.firestore().getAll(...refs);
    snaps.forEach(snap => {
      if (snap.exists) listingMap.set(snap.id, docToJson(snap));
    });
  }

  const enriched = offers.map((o) => ({
    ...o,
    listing: listingMap.get(o.listingId) || null,
  }));

  res.json(enriched);
}));

offersRouter.get('/incoming', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  // Find all listings owned by the current user
  const myListingsSnap = await col('listings')
    .where('sellerUid', '==', req.user.uid)
    .get();

  const myListingIds = myListingsSnap.docs.map((d) => d.id);

  if (myListingIds.length === 0) {
    res.json([]);
    return;
  }

  // Firestore 'in' queries support max 30 values; batch if needed
  const allOffers = [];
  const listingMap = new Map();
  myListingsSnap.docs.forEach((d) => listingMap.set(d.id, docToJson(d)));

  for (let i = 0; i < myListingIds.length; i += 30) {
    const batch = myListingIds.slice(i, i + 30);
    const offersSnap = await col('offers')
      .where('listingId', 'in', batch)
      .orderBy('createdAt', 'desc')
      .get();
    allOffers.push(...queryToJson(offersSnap));
  }

  // Sort all combined results by createdAt desc
  allOffers.sort((a, b) => {
    const da = a.createdAt ? new Date(a.createdAt).getTime() : 0;
    const db = b.createdAt ? new Date(b.createdAt).getTime() : 0;
    return db - da;
  });

  const enriched = allOffers.map((o) => ({
    ...o,
    listing: listingMap.get(o.listingId) || null,
  }));

  res.json(enriched);
}));

offersRouter.post('/', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  const payload = req.body || {};

  // Validate input before processing
  const errors = validateOfferInput(payload);
  if (errors) {
    res.status(400).json({ message: 'Validation failed', fields: errors });
    return;
  }

  const listingRef = col('listings').doc(payload.listingId);
  const listingSnap = await listingRef.get();
  if (!listingSnap.exists) {
    res.status(404).json({ message: 'Listing not found' });
    return;
  }

  const listing = listingSnap.data();
  if (listing.status !== 'open') {
    res.status(400).json({ message: 'Listing is not open for offers' });
    return;
  }

  if (listing.sellerUid === req.user.uid) {
    res.status(400).json({ message: 'Seller cannot place an offer on own listing' });
    return;
  }

  const offerData = {
    listingId: listingSnap.id,
    buyerUid: req.user.uid,
    offerPrice: Number(payload.offerPrice),
    quantity: Number(payload.quantity),
    status: 'pending',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const offerRef = await col('offers').add(offerData);
  const offerSnap = await offerRef.get();
  const offer = docToJson(offerSnap);

  // Notify the seller via FCM
  try {
    await sendPushToUser(
      listing.sellerUid,
      'New Offer Received',
      `You have a new offer for ${listing.cropName}: PKR ${offer.offerPrice}`,
      { type: 'offer', listingId: listingSnap.id, offerId: offer._id || offerSnap.id },
    );
  } catch (err) {
    console.error('FCM notify error (new offer):', err.message);
  }

  res.status(201).json(offer);
}));

offersRouter.post('/:id/accept', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  const offerRef = col('offers').doc(req.params.id);
  const offerSnap = await offerRef.get();
  if (!offerSnap.exists) {
    res.status(404).json({ message: 'Offer not found' });
    return;
  }
  const offer = offerSnap.data();

  const listingRef = col('listings').doc(offer.listingId);
  const listingSnap = await listingRef.get();
  if (!listingSnap.exists) {
    res.status(404).json({ message: 'Listing not found' });
    return;
  }
  const listing = listingSnap.data();

  if (listing.sellerUid !== req.user.uid && req.dbUser.role !== 'admin') {
    res.status(403).json({ message: 'Only seller can accept this offer' });
    return;
  }

  if (offer.status !== 'pending') {
    res.status(400).json({ message: 'Offer is not pending' });
    return;
  }

  // Accept this offer
  await offerRef.update({ status: 'accepted', updatedAt: serverTimestamp() });

  // Reject all other pending offers on this listing
  const otherOffers = await col('offers')
    .where('listingId', '==', offer.listingId)
    .where('status', '==', 'pending')
    .get();

  const batch = admin.firestore().batch();
  otherOffers.docs.forEach((doc) => {
    if (doc.id !== req.params.id) {
      batch.update(doc.ref, { status: 'rejected', updatedAt: serverTimestamp() });
    }
  });
  await batch.commit();

  // Mark listing as reserved
  await listingRef.update({ status: 'reserved', updatedAt: serverTimestamp() });

  // Create order
  const orderData = {
    listingId: listingSnap.id,
    offerId: offerSnap.id,
    buyerUid: offer.buyerUid,
    sellerUid: listing.sellerUid,
    finalPrice: offer.offerPrice,
    quantity: offer.quantity,
    unit: listing.unit,
    status: 'created',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const orderRef = await col('orders').add(orderData);
  const orderSnap = await orderRef.get();
  const order = docToJson(orderSnap);

  // Notify buyer that their offer was accepted
  try {
    await sendPushToUser(
      offer.buyerUid,
      'Offer Accepted! 🎉',
      `Your offer for ${listing.cropName} (PKR ${offer.offerPrice}) has been accepted. An order has been created.`,
      { type: 'offer_accepted', listingId: listingSnap.id, offerId: offerSnap.id, orderId: orderSnap.id },
    );
  } catch (err) {
    console.error('FCM notify error (offer accepted):', err.message);
  }

  res.json({ message: 'Offer accepted', order });
}));

offersRouter.post('/:id/reject', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  const offerRef = col('offers').doc(req.params.id);
  const offerSnap = await offerRef.get();
  if (!offerSnap.exists) {
    res.status(404).json({ message: 'Offer not found' });
    return;
  }
  const offer = offerSnap.data();

  const listingRef = col('listings').doc(offer.listingId);
  const listingSnap = await listingRef.get();
  if (!listingSnap.exists) {
    res.status(404).json({ message: 'Listing not found' });
    return;
  }
  const listing = listingSnap.data();

  if (listing.sellerUid !== req.user.uid && req.dbUser.role !== 'admin') {
    res.status(403).json({ message: 'Only seller can reject this offer' });
    return;
  }

  if (offer.status !== 'pending') {
    res.status(400).json({ message: 'Offer is not pending' });
    return;
  }

  await offerRef.update({ status: 'rejected', updatedAt: serverTimestamp() });
  const updated = await offerRef.get();

  // Notify buyer that their offer was declined
  try {
    await sendPushToUser(
      offer.buyerUid,
      'Offer Declined',
      `Your offer for ${listing.cropName} (PKR ${offer.offerPrice}) was not accepted.`,
      { type: 'offer_rejected', listingId: offer.listingId, offerId: req.params.id },
    );
  } catch (err) {
    console.error('FCM notify error (offer rejected):', err.message);
  }

  res.json({ message: 'Offer rejected', offer: docToJson(updated) });
}));

offersRouter.post('/:id/cancel', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  const offerRef = col('offers').doc(req.params.id);
  const offerSnap = await offerRef.get();
  if (!offerSnap.exists) {
    res.status(404).json({ message: 'Offer not found' });
    return;
  }
  const offer = offerSnap.data();

  if (offer.buyerUid !== req.user.uid && req.dbUser.role !== 'admin') {
    res.status(403).json({ message: 'Only buyer can cancel this offer' });
    return;
  }

  if (offer.status !== 'pending') {
    res.status(400).json({ message: 'Only pending offers can be cancelled' });
    return;
  }

  await offerRef.update({ status: 'cancelled', updatedAt: serverTimestamp() });
  const updated = await offerRef.get();
  res.json({ message: 'Offer cancelled', offer: docToJson(updated) });
}));
