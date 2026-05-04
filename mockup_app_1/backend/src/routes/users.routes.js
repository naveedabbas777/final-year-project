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
  };
}

usersRouter.get('/me', requireAuth, attachDbUser, async (req, res) => {
  res.json(normalizeUser(req.dbUser));
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
