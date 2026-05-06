import { Router } from 'express';

import { admin } from '../config/firebaseAdmin.js';
import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';

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
usersRouter.get('/:uid', async (req, res, next) => {
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
      res.json(await enrichUserFromFirebaseAuth({ id: doc.id, ...doc.data() }));
      return;
    }

    // Fallback: query by firebaseUid or uid field
    const snap = await admin.firestore().collection('users').where('firebaseUid', '==', uid).limit(1).get();
    if (!snap.empty) {
      const d = snap.docs[0];
      res.json(await enrichUserFromFirebaseAuth({ id: d.id, ...d.data() }));
      return;
    }

    res.status(404).json({ message: 'User not found' });
  } catch (err) {
    next(err);
  }
});

usersRouter.patch('/me', requireAuth, attachDbUser, async (req, res) => {
  const {
    name,
    displayName,
    phone,
    phoneNumber,
    district,
    province,
    address,
    lat,
    lon,
    role,
  } = req.body || {};

  const resolvedName = typeof name === 'string' ? name.trim() : typeof displayName === 'string' ? displayName.trim() : undefined;
  const resolvedPhone = typeof phone === 'string' ? phone.trim() : typeof phoneNumber === 'string' ? phoneNumber.trim() : undefined;

  if (typeof resolvedName === 'string') {
    req.dbUser.name = resolvedName;
    req.dbUser.displayName = resolvedName;
  }
  if (typeof resolvedPhone === 'string') {
    req.dbUser.phone = resolvedPhone;
    req.dbUser.phoneNumber = resolvedPhone;
  }
  if (typeof district === 'string') req.dbUser.district = district.trim();
  if (typeof province === 'string') req.dbUser.province = province.trim();
  if (typeof address === 'string') req.dbUser.address = address.trim();
  if (typeof lat === 'number' && Number.isFinite(lat)) req.dbUser.lat = lat;
  if (typeof lon === 'number' && Number.isFinite(lon)) req.dbUser.lon = lon;
  if (typeof address === 'string' || typeof lat === 'number' || typeof lon === 'number') {
    req.dbUser.locationUpdatedAt = new Date().toISOString();
  }

  // Role update allowed only in local-dev style bootstrap route behavior.
  if (typeof role === 'string' && ['farmer', 'buyer', 'admin'].includes(role)) {
    req.dbUser.role = role;
  }

  try {
    await req.dbUser.save();
  } catch (error) {
    throw error;
  }

  res.json({ message: 'Profile updated', user: normalizeUser(req.dbUser) });
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
