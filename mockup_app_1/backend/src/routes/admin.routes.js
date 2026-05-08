import { Router } from 'express';

import { admin } from '../config/firebaseAdmin.js';
import { requireAuth, requireRole } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { col, queryToJson } from '../utils/firestoreHelpers.js';
import { refreshAllWeatherCaches } from '../services/weatherAlerts.service.js';
import { asyncHandler } from '../utils/errors.js';

export const adminRouter = Router();

function normalizeUser(user) {
  if (!user) return null;
  return {
    id: user.id ?? null,
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

function serializeNotificationLog(doc) {
  return {
    ...doc,
    createdAt: serializeDate(doc.createdAt),
  };
}

function collectFcmTokens(userData) {
  const tokens = [];
  if (Array.isArray(userData?.fcmTokens)) {
    tokens.push(...userData.fcmTokens.filter(Boolean));
  }
  if (typeof userData?.fcmToken === 'string' && userData.fcmToken.trim()) {
    tokens.push(userData.fcmToken.trim());
  }
  return [...new Set(tokens)];
}

async function removeInvalidTokens(userId, invalidTokens) {
  if (!userId || invalidTokens.length === 0) return;
  await admin.firestore().collection('users').doc(userId).set(
    { fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens) },
    { merge: true },
  );
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

async function countFirestoreCollection(collectionName, where) {
  try {
    const base = admin.firestore().collection(collectionName);
    const q = where ? base.where(where.field, where.op, where.value) : base;
    const result = await q.count().get();
    return Number(result.data().count || 0);
  } catch (_) {
    const base = admin.firestore().collection(collectionName);
    const q = where ? base.where(where.field, where.op, where.value) : base;
    const snap = await q.get();
    return snap.size;
  }
}

adminRouter.get('/overview', requireAuth, attachDbUser, requireRole('admin'), asyncHandler(async (_req, res) => {
  const [userCount, adminCount, listingCount, openListingCount, orderCount, offerCount, rateCount, presenceMap, alertsSnap] = await Promise.all([
    countFirestoreCollection('users', null),
    countFirestoreCollection('users', { field: 'role', op: '==', value: 'admin' }),
    countFirestoreCollection('listings', null),
    countFirestoreCollection('listings', { field: 'status', op: '==', value: 'open' }),
    countFirestoreCollection('orders', null),
    countFirestoreCollection('offers', null),
    countFirestoreCollection('crop_rates', null),
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
}));

adminRouter.get('/users', requireAuth, attachDbUser, requireRole('admin'), asyncHandler(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const role = String(req.query.role || '').trim();
  const presenceMap = await getPresenceMap();

  let query = admin.firestore().collection('users');
  if (role && ['farmer', 'buyer', 'admin'].includes(role)) {
    query = query.where('role', '==', role);
  }

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
}));

adminRouter.get('/listings', requireAuth, attachDbUser, requireRole('admin'), asyncHandler(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const status = String(req.query.status || '').trim();

  let query = col('listings');
  if (status && status !== 'all') {
    query = query.where('status', '==', status);
  }

  const snap = await query.orderBy('createdAt', 'desc').limit(limit).get();
  res.json(queryToJson(snap));
}));

adminRouter.get('/rates', requireAuth, attachDbUser, requireRole('admin'), asyncHandler(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const snap = await col('crop_rates').orderBy('rateDate', 'desc').limit(limit).get();
  res.json(queryToJson(snap));
}));

adminRouter.get('/orders', requireAuth, attachDbUser, requireRole('admin'), asyncHandler(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 100, 300);
  const status = String(req.query.status || '').trim();

  let query = col('orders');
  if (status && status !== 'all') {
    query = query.where('status', '==', status);
  }

  const snap = await query.get();
  const rows = queryToJson(snap).sort((a, b) => {
    const da = a.createdAt ? new Date(a.createdAt).getTime() : 0;
    const db = b.createdAt ? new Date(b.createdAt).getTime() : 0;
    return db - da;
  });
  res.json(rows.slice(0, limit));
}));

adminRouter.get('/alerts', requireAuth, attachDbUser, requireRole('admin'), asyncHandler(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 100);
  const snap = await admin.firestore().collection('weather_alerts').orderBy('createdAt', 'desc').limit(limit).get();
  res.json(snap.docs.map((doc) => serializeAlert({ id: doc.id, ...doc.data() })));
}));

adminRouter.post('/weather/refresh', requireAuth, attachDbUser, requireRole('admin'), asyncHandler(async (_req, res) => {
  const results = await refreshAllWeatherCaches();
  res.json({ message: 'Weather refresh complete', refreshed: results.length });
}));

adminRouter.post('/notifications/send', requireAuth, attachDbUser, requireRole('admin'), asyncHandler(async (req, res) => {
  const mode = String(req.body?.mode || '').trim();
  const title = String(req.body?.title || '').trim();
  const body = String(req.body?.body || '').trim();
  const targetUserIds = Array.isArray(req.body?.targetUserIds)
    ? req.body.targetUserIds.map((id) => String(id || '').trim()).filter(Boolean)
    : [];

  if (!['all', 'some', 'single'].includes(mode)) {
    res.status(400).json({ message: 'mode must be one of: all, some, single' });
    return;
  }
  if (!title || !body) {
    res.status(400).json({ message: 'title and body are required' });
    return;
  }
  if ((mode === 'some' || mode === 'single') && targetUserIds.length === 0) {
    res.status(400).json({ message: 'targetUserIds are required for some/single mode' });
    return;
  }

  let query = admin.firestore().collection('users').where('role', '==', 'farmer');
  if (mode === 'single') {
    query = query.where('firebaseUid', '==', targetUserIds[0]);
  }

  const usersSnap = await query.get();
  let recipients = usersSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  if (mode === 'some') {
    const allow = new Set(targetUserIds);
    recipients = recipients.filter((user) => allow.has(user.firebaseUid || user.id));
  }

  let pushSent = 0;
  let alertCreated = 0;

  for (const user of recipients) {
    const uid = user.firebaseUid || user.id;
    if (!uid) continue;

    await admin.firestore().collection('weather_alerts').add({
      userId: uid,
      userName: user.displayName || user.name || '',
      address: user.address || '',
      lat: user.lat ?? null,
      lon: user.lon ?? null,
      type: 'admin_notice',
      title,
      body,
      source: 'admin-manual-notification',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      weatherUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    alertCreated += 1;

    const tokens = collectFcmTokens(user);
    if (tokens.length === 0) continue;

    const resp = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: {
        type: 'admin_notice',
        userId: uid,
        mode,
      },
    });
    pushSent += resp.successCount;

    if (resp.failureCount > 0) {
      const invalidTokens = [];
      resp.responses.forEach((r, i) => {
        if (!r.success) invalidTokens.push(tokens[i]);
      });
      await removeInvalidTokens(uid, invalidTokens);
    }
  }

  await admin.firestore().collection('admin_notification_logs').add({
    senderUid: req.user?.uid || '',
    senderName: req.dbUser?.displayName || req.dbUser?.name || '',
    mode,
    title,
    body,
    targetUserIds: targetUserIds,
    recipients: recipients.length,
    alertCreated,
    pushSent,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  res.json({
    message: 'Notifications processed',
    mode,
    recipients: recipients.length,
    alertCreated,
    pushSent,
  });
}));

adminRouter.get('/notifications/history', requireAuth, attachDbUser, requireRole('admin'), asyncHandler(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const mode = String(req.query.mode || '').trim();
  const from = String(req.query.from || '').trim();
  const to = String(req.query.to || '').trim();

  let query = admin.firestore().collection('admin_notification_logs');
  if (mode && ['all', 'some', 'single'].includes(mode)) {
    query = query.where('mode', '==', mode);
  }

  // Firestore requires inequalities on an indexed field; apply on createdAt.
  const fromDate = from ? new Date(from) : null;
  const toDate = to ? new Date(to) : null;
  if (fromDate && !Number.isNaN(fromDate.getTime())) {
    query = query.where('createdAt', '>=', fromDate);
  }
  if (toDate && !Number.isNaN(toDate.getTime())) {
    query = query.where('createdAt', '<=', toDate);
  }

  const snap = await query.orderBy('createdAt', 'desc').limit(limit).get();
  res.json(
    snap.docs.map((doc) => serializeNotificationLog({ id: doc.id, ...doc.data() })),
  );
}));