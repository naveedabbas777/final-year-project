import { Router } from 'express';

import { admin } from '../config/firebaseAdmin.js';
import { requireAuth, requireRole } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { ListingModel } from '../models/listing.model.js';
import { OfferModel } from '../models/offer.model.js';
import { OrderModel } from '../models/order.model.js';

export const usersRouter = Router();

function normalizeUser(user) {
  if (!user) return null;
  return {
    id: user.id ?? user._id?.toString?.() ?? null,
    firebaseUid: user.firebaseUid ?? user.uid ?? '',
    name: user.name ?? user.displayName ?? '',
    displayName: user.displayName ?? user.name ?? '',
    phone: user.phone ?? user.phoneNumber ?? '',
    phoneNumber: user.phoneNumber ?? user.phone ?? '',
    role: user.role ?? 'farmer',
    district: user.district ?? '',
    province: user.province ?? '',
    address: user.address ?? '',
    lat: user.lat ?? null,
    lon: user.lon ?? null,
    locationUpdatedAt: user.locationUpdatedAt ?? null,
    createdAt: user.createdAt ?? null,
    email: user.email ?? '',
    photoUrl: user.photoUrl ?? user.photoURL ?? '',
  };
}

async function enrichUserFromFirebaseAuth(user) {
  const normalized = normalizeUser(user);
  const uid = normalized?.firebaseUid || normalized?.id;
  if (!uid) return normalized;

  try {
    const authUser = await admin.auth().getUser(uid);
    return {
      ...normalized,
      email: normalized.email || authUser.email || '',
      photoUrl: normalized.photoUrl || authUser.photoURL || '',
      displayName: normalized.displayName || authUser.displayName || normalized.name || '',
      createdAt: normalized.createdAt || authUser.metadata?.creationTime || null,
    };
  } catch (_) {
    return normalized;
  }
}

function redactSensitiveProfileFields(normalizedUser) {
  if (!normalizedUser) return normalizedUser;
  const copy = { ...normalizedUser };
  // Treat these as sensitive contact/location fields
  copy.phone = '';
  copy.phoneNumber = '';
  copy.email = '';
  copy.address = '';
  copy.lat = null;
  copy.lon = null;
  return copy;
}

async function canViewSensitiveFields({ viewerUid, viewerRole, targetUid }) {
  if (!viewerUid || !targetUid) return false;
  if (viewerUid === targetUid) return true;
  if (viewerRole === 'admin') return true;

  // Buyer-seller counterpart check:
  // allow if viewer has an order with target (either direction)
  const orderExists = await OrderModel.exists({
    $or: [
      { buyerUid: viewerUid, sellerUid: targetUid },
      { buyerUid: targetUid, sellerUid: viewerUid },
    ],
  });
  if (orderExists) return true;

  // Offers are only stored with buyerUid + listingId, so we map listingIds by seller.
  // viewer -> target as seller
  const targetListings = await ListingModel.find({ sellerUid: targetUid }).select('_id').limit(2000).lean();
  if (targetListings.length > 0) {
    const listingIds = targetListings.map((l) => l._id);
    const offerExists = await OfferModel.exists({
      buyerUid: viewerUid,
      listingId: { $in: listingIds },
    });
    if (offerExists) return true;
  }

  // target -> viewer as seller (viewer is seller, target is buyer)
  const viewerListings = await ListingModel.find({ sellerUid: viewerUid }).select('_id').limit(2000).lean();
  if (viewerListings.length > 0) {
    const listingIds = viewerListings.map((l) => l._id);
    const offerExists = await OfferModel.exists({
      buyerUid: targetUid,
      listingId: { $in: listingIds },
    });
    if (offerExists) return true;
  }

  return false;
}

usersRouter.get('/me', requireAuth, attachDbUser, async (req, res) => {
  res.json(await enrichUserFromFirebaseAuth({ id: req.dbUser?.id, ...req.dbUser?.toObject?.(), ...req.dbUser }));
});

usersRouter.get('/by-phone/:phone', requireAuth, attachDbUser, async (req, res) => {
  const phone = String(req.params.phone || '').trim();
  if (!phone) {
    res.status(400).json({ message: 'Phone number is required' });
    return;
  }

  try {
    const snap = await admin
      .firestore()
      .collection('users')
      .where('phoneNumber', '==', phone)
      .limit(1)
      .get();

    if (!snap.empty) {
      const doc = snap.docs[0];
      res.json(normalizeUser({ id: doc.id, ...doc.data() }));
      return;
    }

    res.status(404).json({ message: 'User not found' });
  } catch (error) {
    throw error;
  }
});

// Public profile by uid (firebase uid or document id)
usersRouter.get('/:uid', requireAuth, attachDbUser, async (req, res, next) => {
  try {
    const uid = String(req.params.uid || '').trim();
    if (!uid) {
      res.status(400).json({ message: 'User id is required' });
      return;
    }

    // Try document by id first
    const docRef = admin.firestore().collection('users').doc(uid);
    const doc = await docRef.get();
    if (doc.exists) {
      const enriched = await enrichUserFromFirebaseAuth({ id: doc.id, ...doc.data() });
      const canSeeSensitive = await canViewSensitiveFields({
        viewerUid: req.user?.uid,
        viewerRole: req.dbUser?.role || 'farmer',
        targetUid: enriched.firebaseUid || uid,
      });
      res.json(canSeeSensitive ? enriched : redactSensitiveProfileFields(enriched));
      return;
    }

    // Fallback: query by firebaseUid or uid field
    const snap = await admin.firestore().collection('users').where('firebaseUid', '==', uid).limit(1).get();
    if (!snap.empty) {
      const d = snap.docs[0];
      const enriched = await enrichUserFromFirebaseAuth({ id: d.id, ...d.data() });
      const canSeeSensitive = await canViewSensitiveFields({
        viewerUid: req.user?.uid,
        viewerRole: req.dbUser?.role || 'farmer',
        targetUid: enriched.firebaseUid || d.id,
      });
      res.json(canSeeSensitive ? enriched : redactSensitiveProfileFields(enriched));
      return;
    }

    res.status(404).json({ message: 'User not found' });
  } catch (err) {
    next(err);
  }
});

// SECURITY: Role changes MUST go through admin-only endpoint only
usersRouter.patch('/me', requireAuth, attachDbUser, async (req, res) => {
  const {
    name,
    displayName,
    phone,
    phoneNumber,
    photoUrl,
    photo,
    district,
    province,
    address,
    lat,
    lon,
  } = req.body || {};

  // SECURITY: role is explicitly NOT allowed in self-edit
  if (req.body?.role !== undefined) {
    res.status(403).json({ message: 'Role cannot be changed via profile update' });
    return;
  }

  const resolvedName = typeof name === 'string' ? name.trim() : typeof displayName === 'string' ? displayName.trim() : undefined;
  const resolvedPhone = typeof phone === 'string' ? phone.trim() : typeof phoneNumber === 'string' ? phoneNumber.trim() : undefined;
  const resolvedPhotoUrl = typeof photoUrl === 'string' ? photoUrl.trim() : typeof photo === 'string' ? photo.trim() : undefined;

  if (typeof resolvedName === 'string') {
    req.dbUser.name = resolvedName;
    req.dbUser.displayName = resolvedName;
  }
  if (typeof resolvedPhone === 'string') {
    req.dbUser.phone = resolvedPhone;
    req.dbUser.phoneNumber = resolvedPhone;
  }
  if (typeof resolvedPhotoUrl === 'string' && resolvedPhotoUrl.length > 0) {
    req.dbUser.photoUrl = resolvedPhotoUrl;
    req.dbUser.photo = resolvedPhotoUrl;
  }
  if (typeof district === 'string') req.dbUser.district = district.trim();
  if (typeof province === 'string') req.dbUser.province = province.trim();
  if (typeof address === 'string') req.dbUser.address = address.trim();
  if (typeof lat === 'number' && Number.isFinite(lat)) req.dbUser.lat = lat;
  if (typeof lon === 'number' && Number.isFinite(lon)) req.dbUser.lon = lon;
  if (typeof address === 'string' || typeof lat === 'number' || typeof lon === 'number') {
    req.dbUser.locationUpdatedAt = new Date().toISOString();
  }

  try {
    await req.dbUser.save();
  } catch (error) {
    throw error;
  }

  res.json({ message: 'Profile updated', user: normalizeUser(req.dbUser) });
});

// SECURITY: Admin-only role update endpoint
usersRouter.patch('/:userId/role', requireAuth, attachDbUser, requireRole('admin'), async (req, res, next) => {
  const targetUserId = String(req.params.userId || '').trim();
  const newRole = req.body?.role;

  if (!newRole || !['farmer', 'buyer', 'admin'].includes(newRole)) {
    res.status(400).json({ message: 'Invalid role. Must be one of: farmer, buyer, admin' });
    return;
  }

  try {
    if (!targetUserId) {
      res.status(400).json({ message: 'User id is required' });
      return;
    }

    // Firebase-only: roles are stored in Firestore users/{uid}
    const docRef = admin.firestore().collection('users').doc(targetUserId);
    const snap = await docRef.get();
    if (!snap.exists) {
      res.status(404).json({ message: 'User not found' });
      return;
    }

    await docRef.set(
      {
        role: newRole,
        roleUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    res.json({
      message: 'User role updated by admin',
      user: normalizeUser({ id: targetUserId, ...snap.data(), role: newRole }),
    });
  } catch (error) {
    next(error);
  }
});

// Register FCM device token for current user
usersRouter.post('/me/fcm-token', requireAuth, attachDbUser, async (req, res, next) => {
  try {
    const token = String(req.body?.token || '').trim();
    if (!token) {
      res.status(400).json({ message: 'token is required' });
      return;
    }

    const docRef = admin.firestore().collection('users').doc(req.user.uid);
    await docRef.set({ fcmTokens: admin.firestore.FieldValue.arrayUnion(token) }, { merge: true });
    res.json({ message: 'Token registered' });
  } catch (err) {
    next(err);
  }
});

// Unregister FCM device token for current user
usersRouter.post('/me/fcm-token/remove', requireAuth, attachDbUser, async (req, res, next) => {
  try {
    const token = String(req.body?.token || '').trim();
    if (!token) {
      res.status(400).json({ message: 'token is required' });
      return;
    }

    const docRef = admin.firestore().collection('users').doc(req.user.uid);
    await docRef.set({ fcmTokens: admin.firestore.FieldValue.arrayRemove(token) }, { merge: true });
    res.json({ message: 'Token removed' });
  } catch (err) {
    next(err);
  }
});

// Update user presence status (online/offline)
usersRouter.post('/me/presence', requireAuth, async (req, res, next) => {
  try {
    const isOnline = Boolean(req.body?.isOnline);

    const presenceData = {
      uid: req.user.uid,
      isOnline,
      lastSeen: admin.firestore.FieldValue.serverTimestamp(),
    };

    const docRef = admin.firestore().collection('presence').doc(req.user.uid);
    await docRef.set(presenceData, { merge: true });

    res.json({ ok: true, isOnline });
  } catch (err) {
    next(err);
  }
});

// Get presence status for a user
usersRouter.get('/:uid/presence', async (req, res, next) => {
  try {
    const uid = String(req.params.uid || '').trim();
    if (!uid) {
      res.status(400).json({ message: 'uid is required' });
      return;
    }

    const docRef = admin.firestore().collection('presence').doc(uid);
    const doc = await docRef.get();

    if (doc.exists) {
      const data = doc.data();
      res.json({
        uid,
        isOnline: Boolean(data.isOnline),
        lastSeen: data.lastSeen?.toDate?.() || data.lastSeen || null,
      });
    } else {
      // User has no presence record, assume offline
      res.json({
        uid,
        isOnline: false,
        lastSeen: null,
      });
    }
  } catch (err) {
    next(err);
  }
});
