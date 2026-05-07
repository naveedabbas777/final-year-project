import { Router } from 'express';

import { admin } from '../config/firebaseAdmin.js';
import { requireAuth, requireRole } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { ListingModel } from '../models/listing.model.js';
import { CropRateModel } from '../models/cropRate.model.js';
import { OrderModel } from '../models/order.model.js';
import { OfferModel } from '../models/offer.model.js';
import { refreshAllWeatherCaches } from '../services/weatherAlerts.service.js';

export const adminRouter = Router();

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

function serializeDate(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

function serializeAlert(doc) {
  return {
    ...doc,
    createdAt: serializeDate(doc.createdAt),
    readAt: serializeDate(doc.readAt),
    weatherUpdatedAt: serializeDate(doc.weatherUpdatedAt),
  };
}

async function getPresenceMap() {
  const snap = await admin.firestore().collection('presence').get();
  const map = new Map();
  snap.docs.forEach((doc) => {
    const data = doc.data();
    map.set(doc.id, {
      isOnline: Boolean(data?.isOnline),
      lastSeen: data?.lastSeen?.toDate?.()?.toISOString?.() || serializeDate(data?.lastSeen),
    });
  });
  return map;
}

async function countFirestoreUsers(where) {
  // Admin SDK supports count() aggregation (Firestore backend must allow it).
  // Fall back to snapshot size only if count() fails.
  try {
    const base = admin.firestore().collection('users');
    const q = where ? base.where(where.field, where.op, where.value) : base;
    const result = await q.count().get();
    return Number(result.data().count || 0);
  } catch (_) {
    const base = admin.firestore().collection('users');
    const q = where ? base.where(where.field, where.op, where.value) : base;
    const snap = await q.get();
    return snap.size;
  }
}

adminRouter.get('/overview', requireAuth, attachDbUser, requireRole('admin'), async (_req, res, next) => {
  try {
    const [userCount, adminCount, listingCount, openListingCount, orderCount, offerCount, rateCount, presenceMap, alertsSnap] = await Promise.all([
      countFirestoreUsers(null),
      countFirestoreUsers({ field: 'role', op: '==', value: 'admin' }),
      ListingModel.countDocuments(),
      ListingModel.countDocuments({ status: 'open' }),
      OrderModel.countDocuments(),
      OfferModel.countDocuments(),
      CropRateModel.countDocuments(),
      getPresenceMap(),
      admin.firestore().collection('weather_alerts').orderBy('createdAt', 'desc').limit(25).get(),
    ]);

    const onlineUsers = [...presenceMap.values()].filter((value) => value.isOnline).length;

    res.json({
      counts: {
        users: userCount,
        admins: adminCount,
        listings: listingCount,
        openListings: openListingCount,
        offers: offerCount,
        orders: orderCount,
        rates: rateCount,
        onlineUsers,
        recentAlerts: alertsSnap.size,
      },
    });
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/users', requireAuth, attachDbUser, requireRole('admin'), async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 50, 200);
    const role = String(req.query.role || '').trim();
    const presenceMap = await getPresenceMap();

    // Firebase-only users: read from Firestore users/{uid}
    let query = admin.firestore().collection('users');
    if (role && ['farmer', 'buyer', 'admin'].includes(role)) {
      query = query.where('role', '==', role);
    }

    // Prefer createdAt ordering; if missing, Firestore will still return deterministically.
    const snap = await query.orderBy('createdAt', 'desc').limit(limit).get();
    const rows = snap.docs.map((doc) => normalizeUser({ id: doc.id, ...doc.data() }));

    res.json(
      rows.map((normalized) => {
        const presence = presenceMap.get(normalized.firebaseUid) || null;
        return {
          ...normalized,
          isOnline: presence?.isOnline ?? false,
          lastSeen: presence?.lastSeen ?? null,
        };
      }),
    );
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/listings', requireAuth, attachDbUser, requireRole('admin'), async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 50, 200);
    const status = String(req.query.status || '').trim();
    const query = {};
    if (status && status !== 'all') query.status = status;

    const rows = await ListingModel.find(query).sort({ createdAt: -1 }).limit(limit);
    res.json(rows);
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/rates', requireAuth, attachDbUser, requireRole('admin'), async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 50, 200);
    const rows = await CropRateModel.find({}).sort({ rateDate: -1, createdAt: -1 }).limit(limit);
    res.json(rows);
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/orders', requireAuth, attachDbUser, requireRole('admin'), async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 100, 300);
    const status = String(req.query.status || '').trim();
    const query = {};
    if (status && status !== 'all') query.status = status;

    const rows = await OrderModel.find(query).sort({ createdAt: -1 }).limit(limit);
    res.json(rows);
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/alerts', requireAuth, attachDbUser, requireRole('admin'), async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 50, 100);
    const snap = await admin.firestore().collection('weather_alerts').orderBy('createdAt', 'desc').limit(limit).get();
    res.json(snap.docs.map((doc) => serializeAlert({ id: doc.id, ...doc.data() })));
  } catch (error) {
    next(error);
  }
});

adminRouter.post('/weather/refresh', requireAuth, attachDbUser, requireRole('admin'), async (_req, res, next) => {
  try {
    const results = await refreshAllWeatherCaches();
    res.json({ message: 'Weather refresh complete', refreshed: results.length });
  } catch (error) {
    next(error);
  }
});