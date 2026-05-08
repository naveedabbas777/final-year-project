import { Router } from 'express';

import { admin } from '../config/firebaseAdmin.js';
import { requireAuth } from '../middlewares/auth.js';
import { col } from '../utils/firestoreHelpers.js';
import { asyncHandler } from '../utils/errors.js';

export const messagesRouter = Router();

function firestoreReady() {
  return Boolean(admin?.apps && admin.apps.length > 0);
}

// SECURITY: Helper to verify user is a participant in listing chat
async function isUserListingParticipant(userId, listingId) {
  if (!firestoreReady()) return false;

  try {
    console.log(`[Debug] isUserListingParticipant check user=${userId} listing=${listingId}`);
    // Check if user is the listing seller (Firestore)
    const listingSnap = await col('listings').doc(listingId).get();
    if (listingSnap.exists && listingSnap.data().sellerUid === userId) return true;

    // Check if user is a valid buyer participant:
    // - has an offer on this listing, OR
    // - has an order tied to this listing
    if (listingSnap.exists) {
      const [offerSnap, orderSnap] = await Promise.all([
        col('offers').where('listingId', '==', listingId).where('buyerUid', '==', userId).limit(1).get(),
        col('orders').where('listingId', '==', listingId).where('buyerUid', '==', userId).limit(1).get(),
      ]);
      if (!offerSnap.empty || !orderSnap.empty) return true;
    }

    // Check if user has sent or received messages for this listing
    const snapshot = await admin
      .firestore()
      .collection('messages')
      .where('listingId', '==', listingId)
      .where('fromUid', '==', userId)
      .limit(1)
      .get();

    if (!snapshot.empty) return true;

    // Check if user is recipient in any message for this listing
    const recipientSnapshot = await admin
      .firestore()
      .collection('messages')
      .where('listingId', '==', listingId)
      .where('toUid', '==', userId)
      .limit(1)
      .get();

    return !recipientSnapshot.empty;
  } catch (error) {
    console.error('[Auth] Error checking listing participant:', error);
    return false;
  }
}

messagesRouter.get('/', requireAuth, asyncHandler(async (req, res) => {
  if (!firestoreReady()) {
    res.status(503).json({ message: 'Firestore is not available on the backend' });
    return;
  }

  const limit = Math.min(Number(req.query.limit) || 20, 100);
  const snapshot = await admin
    .firestore()
    .collection('messages')
    .orderBy('timestamp', 'desc')
    .limit(limit)
    .get();

  const rows = snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));

  res.json(rows.reverse());
}));

messagesRouter.post('/', requireAuth, asyncHandler(async (req, res) => {
  if (!firestoreReady()) {
    res.status(503).json({ message: 'Firestore is not available on the backend' });
    return;
  }

  const message = String(req.body?.message || '').trim();
  const listingId = req.body?.listingId || null;
  const toUid = req.body?.toUid || null;

  if (!message) {
    res.status(400).json({ message: 'Message is required' });
    return;
  }

  const payload = {
    message,
    fromUid: req.user.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  };
  payload.readBy = [req.user.uid];
  payload.readAt = null;
  if (listingId) payload.listingId = listingId;
  if (toUid) payload.toUid = toUid;

  const doc = await admin.firestore().collection('messages').add(payload);

  res.status(201).json({ id: doc.id, message });

  // Send notification to recipient (toUid) or listing owner — fire-and-forget
  try {
    let targetUid = toUid || null;
    if (!targetUid && listingId) {
      const lsnap = await col('listings').doc(listingId).get();
      if (lsnap.exists) targetUid = lsnap.data()?.sellerUid || null;
    }

    if (targetUid && targetUid !== req.user.uid) {
      const userSnap = await admin.firestore().collection('users').doc(targetUid).get();
      const userData = userSnap.exists ? userSnap.data() : null;
      const tokens = Array.isArray(userData?.fcmTokens) ? userData.fcmTokens.filter(Boolean) : [];
      if (tokens.length > 0) {
        const notifPayload = {
          notification: {
            title: 'New Message',
            body: message.length > 100 ? `${message.substring(0, 100)}...` : message,
          },
          data: {
            type: 'message',
            listingId: listingId || '',
            fromUid: req.user.uid,
          },
        };

        const resp = await admin.messaging().sendMulticast({ tokens, ...notifPayload });
        if (resp.failureCount > 0) {
          const invalidTokens = [];
          resp.responses.forEach((r, i) => {
            if (!r.success) invalidTokens.push(tokens[i]);
          });
          if (invalidTokens.length > 0) {
            await admin.firestore().collection('users').doc(targetUid).set({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens) }, { merge: true });
          }
        }
      }
    }
  } catch (err) {
    // don't block response
    console.error('FCM notify error', err);
  }
}));

// Get messages for a listing
messagesRouter.get('/listing/:listingId', requireAuth, asyncHandler(async (req, res) => {
  if (!firestoreReady()) {
    res.status(503).json({ message: 'Firestore is not available on the backend' });
    return;
  }

  const listingId = req.params.listingId;

  // SECURITY: Verify user is a participant
  const isParticipant = await isUserListingParticipant(req.user.uid, listingId);
  if (!isParticipant) {
    res.status(403).json({ message: 'Unauthorized: not a participant in this chat' });
    return;
  }

  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const before = typeof req.query.before === 'string' && req.query.before.trim()
    ? new Date(req.query.before)
    : null;
  const beforeIsValid = before && !Number.isNaN(before.getTime());

  let query = admin
    .firestore()
    .collection('messages')
    .where('listingId', '==', listingId)
    .orderBy('timestamp', 'desc');

  if (beforeIsValid) {
    query = query.startAfter(before);
  }

  const snapshot = await query.limit(limit).get();
  const rows = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })).reverse();
  res.json(rows);
}));

messagesRouter.post('/listing/:listingId/read', requireAuth, asyncHandler(async (req, res) => {
  if (!firestoreReady()) {
    res.status(503).json({ message: 'Firestore is not available on the backend' });
    return;
  }

  const listingId = req.params.listingId;

  // SECURITY: Verify user is a participant
  const isParticipant = await isUserListingParticipant(req.user.uid, listingId);
  if (!isParticipant) {
    res.status(403).json({ message: 'Unauthorized: not a participant in this chat' });
    return;
  }

  const snapshot = await admin
    .firestore()
    .collection('messages')
    .where('listingId', '==', listingId)
    .where('toUid', '==', req.user.uid)
    .get();

  const batch = admin.firestore().batch();
  let updated = 0;

  snapshot.docs.forEach((doc) => {
    const data = doc.data() || {};
    const readBy = Array.isArray(data.readBy) ? data.readBy : [];
    if (!readBy.includes(req.user.uid)) {
      batch.update(doc.ref, {
        readBy: admin.firestore.FieldValue.arrayUnion(req.user.uid),
        readAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      updated += 1;
    }
  });

  if (updated > 0) {
    await batch.commit();
  }

  res.json({ updated });
}));

messagesRouter.post('/typing', requireAuth, asyncHandler(async (req, res) => {
  if (!firestoreReady()) {
    res.status(503).json({ message: 'Firestore is not available on the backend' });
    return;
  }

  const listingId = String(req.body?.listingId || '').trim();
  const isTyping = Boolean(req.body?.isTyping);

  if (!listingId) {
    res.status(400).json({ message: 'listingId is required' });
    return;
  }

  const docId = `${listingId}_${req.user.uid}`;
  await admin.firestore().collection('typing_status').doc(docId).set(
    {
      listingId,
      uid: req.user.uid,
      isTyping,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  res.json({ ok: true });
}));

// Realtime stream (SSE) for listing chat
messagesRouter.get('/stream/listing/:listingId', requireAuth, asyncHandler(async (req, res) => {
  if (!firestoreReady()) {
    res.status(503).json({ message: 'Firestore is not available on the backend' });
    return;
  }

  const listingId = req.params.listingId;

  // SECURITY: Verify user is a participant before streaming
  const isParticipant = await isUserListingParticipant(req.user.uid, listingId);
  console.log(`[Debug] Stream request user=${req.user.uid} listing=${listingId} participant=${isParticipant}`);
  if (!isParticipant) {
    res.status(403).json({ message: 'Unauthorized: not a participant in this chat' });
    return;
  }

  const limit = Math.min(Number(req.query.limit) || 100, 200);

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  const sendEvent = (event, payload) => {
    res.write(`event: ${event}\n`);
    res.write(`data: ${JSON.stringify(payload)}\n\n`);
  };

  sendEvent('ready', { ok: true, listingId });

  const query = admin
    .firestore()
    .collection('messages')
    .where('listingId', '==', listingId)
    .orderBy('timestamp', 'asc')
    .limit(limit);

  const unsubscribeMessages = query.onSnapshot(
    (snapshot) => {
      const rows = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
      // log snapshot size for debugging
      console.log(`[Debug] messages snapshot for listing=${listingId} size=${rows.length}`);
      sendEvent('snapshot', rows);
    },
    (err) => {
      console.error(`[Debug] messages snapshot error for listing=${listingId}:`, err?.message || err);
      sendEvent('error', { message: err?.message || 'stream_error' });
    },
  );

  const typingQuery = admin
    .firestore()
    .collection('typing_status')
    .where('listingId', '==', listingId)
    .limit(50);

  const unsubscribeTyping = typingQuery.onSnapshot(
    (snapshot) => {
      const activeUids = snapshot.docs
        .map((doc) => doc.data())
        .filter((row) => row?.isTyping === true)
        .map((row) => row.uid)
        .filter(Boolean);
      console.log(`[Debug] typing snapshot for listing=${listingId} active=${activeUids.length}`);
      sendEvent('typing', { uids: activeUids });
    },
    (err) => {
      console.error(`[Debug] typing snapshot error for listing=${listingId}:`, err?.message || err);
      sendEvent('error', { message: err?.message || 'typing_stream_error' });
    },
  );

  const keepAlive = setInterval(() => {
    res.write(': keepalive\n\n');
  }, 20000);

  req.on('close', () => {
    clearInterval(keepAlive);
    unsubscribeMessages();
    unsubscribeTyping();
    res.end();
  });
}));

// Get unread message count for a listing
messagesRouter.get('/listing/:listingId/unread-count', requireAuth, asyncHandler(async (req, res) => {
  if (!firestoreReady()) {
    res.status(503).json({ message: 'Firestore is not available on the backend' });
    return;
  }

  const listingId = req.params.listingId;

  // SECURITY: Verify user is a participant
  const isParticipant = await isUserListingParticipant(req.user.uid, listingId);
  if (!isParticipant) {
    res.status(403).json({ message: 'Unauthorized: not a participant in this chat' });
    return;
  }

  // Count messages where listingId matches and current user is NOT in readBy array
  const snapshot = await admin
    .firestore()
    .collection('messages')
    .where('listingId', '==', listingId)
    .get();

  let unreadCount = 0;
  snapshot.docs.forEach((doc) => {
    const data = doc.data() || {};
    const readBy = Array.isArray(data.readBy) ? data.readBy : [];
    // Count as unread if current user is not in readBy array AND sender is not current user
    if (!readBy.includes(req.user.uid) && data.fromUid !== req.user.uid) {
      unreadCount += 1;
    }
  });

  res.json({ unreadCount, listingId });
}));