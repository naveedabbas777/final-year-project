import { Router } from 'express';

import { admin } from '../config/firebaseAdmin.js';
import { requireAuth } from '../middlewares/auth.js';
import { col } from '../utils/firestoreHelpers.js';
import { asyncHandler } from '../utils/errors.js';

export const messagesRouter = Router();

const listingThreadsCol = () => admin.firestore().collection('listing_threads');

function firestoreReady() {
  return Boolean(admin?.apps && admin.apps.length > 0);
}

function toMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (typeof value.toDate === 'function') return value.toDate().getTime();
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  if (typeof value === 'object' && typeof value.seconds === 'number') {
    return value.seconds * 1000 + Math.floor((value.nanoseconds || 0) / 1e6);
  }
  return 0;
}

function toStringList(value) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item)).filter(Boolean);
}

async function getListingMeta(listingId) {
  const listingSnap = await col('listings').doc(listingId).get();
  if (!listingSnap.exists) return null;
  const data = listingSnap.data() || {};
  const imageUrls = Array.isArray(data.imageUrls) ? data.imageUrls : [];
  return {
    listingId,
    sellerUid: String(data.sellerUid || '').trim(),
    productName: String(data.cropName || data.productName || 'Product').trim() || 'Product',
    productImageUrl: typeof imageUrls[0] === 'string' ? imageUrls[0] : '',
  };
}

async function getListingThread(listingId) {
  const snap = await listingThreadsCol().doc(listingId).get();
  if (!snap.exists) return null;
  return { id: snap.id, ...snap.data() };
}

async function ensureListingThread({ listingId, userId, createIfMissing = false }) {
  const meta = await getListingMeta(listingId);
  if (!meta) return { ok: false, status: 404, message: 'Listing not found' };

  // Determine buyer and seller
  const isSeller = userId === meta.sellerUid;
  const buyerUid = isSeller ? null : userId;
  const sellerUid = meta.sellerUid;

  if (isSeller && !createIfMissing) {
    return {
      ok: false,
      status: 409,
      message: 'The buyer must start the product chat first',
      meta,
      isExisting: false,
    };
  }

  // For existing threads, check if user is participant
  const threadId = buyerUid ? `${listingId}_${buyerUid}_${sellerUid}` : null;
  if (threadId) {
    const threadRef = listingThreadsCol().doc(threadId);
    const threadSnap = await threadRef.get();
    if (threadSnap.exists) {
      const thread = { id: threadId, ...threadSnap.data() };
      const participantUids = toStringList(thread.participantUids);
      const isParticipant = participantUids.includes(userId);
      return {
        ok: isParticipant,
        status: isParticipant ? 200 : 403,
        message: isParticipant ? '' : 'Unauthorized: not a participant in this product chat',
        thread,
        meta,
        isExisting: true,
      };
    }
  }

  // Check for legacy single-buyer threads
  const legacySnap = await admin.firestore()
    .collection('messages')
    .where('listingId', '==', listingId)
    .get();

  if (!legacySnap.empty) {
    const legacyRows = legacySnap.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .sort((a, b) => toMillis(a.timestamp) - toMillis(b.timestamp));

    const buyers = [...new Set(
      legacyRows
        .map((row) => String(row.fromUid || '').trim())
        .filter((uid) => uid && uid !== meta.sellerUid),
    )];

    if (buyers.length === 1 && userId === buyers[0]) {
      // Migrate legacy thread for this buyer
      const buyerUid = buyers[0];
      const newThreadId = `${listingId}_${buyerUid}_${sellerUid}`;
      const threadRef = listingThreadsCol().doc(newThreadId);
      const thread = {
        listingId,
        sellerUid,
        buyerUid,
        participantUids: [sellerUid, buyerUid],
        productName: meta.productName,
        productImageUrl: meta.productImageUrl || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessage: legacyRows.at(-1)?.message || '',
        lastMessageAt: legacyRows.at(-1)?.timestamp || null,
        lastMessageFromUid: legacyRows.at(-1)?.fromUid || null,
      };

      await threadRef.set(thread);
      return {
        ok: true,
        status: 200,
        message: '',
        thread: { id: newThreadId, ...thread },
        meta,
        isExisting: false,
      };
    }

    if (buyers.length > 1) {
      // For multiple buyers, create thread for this specific buyer if they have messages
      if (buyers.includes(userId)) {
        const newThreadId = `${listingId}_${userId}_${sellerUid}`;
        const threadRef = listingThreadsCol().doc(newThreadId);
        const userMessages = legacyRows.filter(row => row.fromUid === userId || row.toUid === userId);
        const thread = {
          listingId,
          sellerUid,
          buyerUid: userId,
          participantUids: [sellerUid, userId],
          productName: meta.productName,
          productImageUrl: meta.productImageUrl || '',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastMessage: userMessages.at(-1)?.message || '',
          lastMessageAt: userMessages.at(-1)?.timestamp || null,
          lastMessageFromUid: userMessages.at(-1)?.fromUid || null,
        };

        await threadRef.set(thread);
        return {
          ok: true,
          status: 200,
          message: '',
          thread: { id: newThreadId, ...thread },
          meta,
          isExisting: false,
        };
      }
    }
  }

  if (!createIfMissing) {
    return {
      ok: false,
      status: 404,
      message: 'Chat thread has not been started yet',
      meta,
      isExisting: false,
    };
  }

  if (isSeller) {
    return {
      ok: false,
      status: 409,
      message: 'The buyer must start the product chat first',
      meta,
      isExisting: false,
    };
  }

  // Create new thread for buyer-seller pair
  const newThreadId = `${listingId}_${buyerUid}_${sellerUid}`;
  const threadRef = listingThreadsCol().doc(newThreadId);
  const thread = {
    listingId,
    sellerUid,
    buyerUid,
    participantUids: [sellerUid, buyerUid],
    productName: meta.productName,
    productImageUrl: meta.productImageUrl || '',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMessage: '',
    lastMessageAt: null,
    lastMessageFromUid: null,
  };

  await threadRef.set(thread);
  return {
    ok: true,
    status: 200,
    thread: { id: newThreadId, ...thread, createdAt: new Date().toISOString() },
    meta,
    isExisting: false,
  };
}

async function requireThreadParticipant(listingId, userId) {
  const result = await ensureListingThread({ listingId, userId, createIfMissing: false });
  if (!result.ok) return result;
  return result;
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

messagesRouter.get('/conversations', requireAuth, asyncHandler(async (req, res) => {
  if (!firestoreReady()) {
    res.status(503).json({ message: 'Firestore is not available on the backend' });
    return;
  }

  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const userId = req.user.uid;

  const threadSnap = await listingThreadsCol()
    .where('participantUids', 'array-contains', userId)
    .get();

  const merged = new Map();

  for (const doc of threadSnap.docs) {
    const thread = { id: doc.id, ...doc.data() };
    const threadId = doc.id;
    const listingId = String(thread.listingId || '').trim();
    const meta = {
      productName: String(thread.productName || 'Product').trim() || 'Product',
      productImageUrl: String(thread.productImageUrl || '').trim(),
      sellerUid: String(thread.sellerUid || '').trim(),
      buyerUid: String(thread.buyerUid || '').trim(),
    };

    const messagesSnap = await admin.firestore()
      .collection('messages')
      .where('threadId', '==', threadId)
      .get();

    let lastMessage = '';
    let lastTimestamp = 0;
    let unreadCount = 0;
    let lastFromUid = null;
    let lastToUid = null;

    messagesSnap.docs.forEach((messageDoc) => {
      const row = messageDoc.data() || {};
      const timestamp = toMillis(row.timestamp);
      if (timestamp >= lastTimestamp) {
        lastTimestamp = timestamp;
        lastMessage = String(row.message || '');
        lastFromUid = row.fromUid || null;
        lastToUid = row.toUid || null;
      }
      const readBy = toStringList(row.readBy);
      if (row.fromUid !== userId && !readBy.includes(userId)) {
        unreadCount += 1;
      }
    });

    if (lastTimestamp === 0 && thread.lastMessageAt) {
      lastTimestamp = toMillis(thread.lastMessageAt);
      lastMessage = String(thread.lastMessage || '');
      lastFromUid = thread.lastMessageFromUid || null;
    }

    merged.set(threadId, {
      threadId,
      listingId,
      productName: meta.productName,
      productImageUrl: meta.productImageUrl,
      sellerUid: meta.sellerUid,
      buyerUid: meta.buyerUid,
      peerUid: userId === meta.sellerUid ? meta.buyerUid : meta.sellerUid,
      lastMessage,
      lastTimestamp,
      fromUid: lastFromUid,
      toUid: lastToUid,
      unreadCount,
    });
  }

  const conversations = Array.from(merged.values())
    .sort((a, b) => b.lastTimestamp - a.lastTimestamp)
    .slice(0, limit)
    .map((item) => ({
      ...item,
      lastTimestamp: new Date(item.lastTimestamp).toISOString(),
    }));

  res.json(conversations);
}));

messagesRouter.post('/', requireAuth, asyncHandler(async (req, res) => {
  if (!firestoreReady()) {
    res.status(503).json({ message: 'Firestore is not available on the backend' });
    return;
  }

  const message = String(req.body?.message || '').trim();
  const listingId = req.body?.listingId || null;
  const userId = req.user.uid;

  if (!message) {
    res.status(400).json({ message: 'Message is required' });
    return;
  }

  if (message.length > 5000) {
    res.status(400).json({ message: 'Message is too long (max 5000 characters)' });
    return;
  }

  if (!listingId) {
    res.status(400).json({ message: 'listingId is required' });
    return;
  }

  const threadResult = await ensureListingThread({ listingId, userId, createIfMissing: true });
  if (!threadResult.ok) {
    res.status(threadResult.status || 403).json({ message: threadResult.message || 'Unauthorized: not a participant in this product chat' });
    return;
  }

  const thread = threadResult.thread;
  const threadId = thread.id;
  const sellerUid = String(thread.sellerUid || '').trim();
  const buyerUid = String(thread.buyerUid || '').trim();
  const toUid = userId === sellerUid ? buyerUid : sellerUid;

  if (!toUid) {
    res.status(409).json({ message: 'Chat participant is not available yet' });
    return;
  }

  if (userId !== sellerUid && userId !== buyerUid) {
    res.status(403).json({ message: 'Unauthorized: not a participant in this product chat' });
    return;
  }

  const payload = {
    message,
    fromUid: userId,
    toUid,
    listingId,
    threadId,
    sellerUid,
    buyerUid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  };
  payload.readBy = [userId];
  payload.readAt = null;

  const doc = await admin.firestore().collection('messages').add(payload);

  await listingThreadsCol().doc(threadId).set({
    lastMessage: message,
    lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMessageFromUid: userId,
    lastMessageToUid: toUid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  res.status(201).json({ id: doc.id, message });

  // Send notification to recipient (toUid) or listing owner — fire-and-forget
  try {
    const targetUid = toUid;

    if (targetUid && targetUid !== userId) {
      const userSnap = await admin.firestore().collection('users').doc(targetUid).get();
      const userData = userSnap.exists ? userSnap.data() : null;
      if (userData?.notificationsEnabled === false) {
        return;
      }
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
            fromUid: userId,
          },
        };

        const resp = await admin.messaging().sendEachForMulticast({ tokens, ...notifPayload });
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

  const threadResult = await requireThreadParticipant(listingId, req.user.uid);
  if (!threadResult.ok) {
    res.status(threadResult.status || 403).json({ message: threadResult.message || 'Unauthorized: not a participant in this product chat' });
    return;
  }

  const threadId = threadResult.thread.id;

  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const before = typeof req.query.before === 'string' && req.query.before.trim()
    ? new Date(req.query.before)
    : null;
  const beforeIsValid = before && !Number.isNaN(before.getTime());

  const snapshot = await admin
    .firestore()
    .collection('messages')
    .where('threadId', '==', threadId)
    .get();

  const rows = snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((row) => {
      if (!beforeIsValid) return true;
      return toMillis(row.timestamp) < before.getTime();
    })
    .sort((a, b) => toMillis(a.timestamp) - toMillis(b.timestamp))
    .slice(-limit);
  res.json(rows);
}));

messagesRouter.post('/listing/:listingId/read', requireAuth, asyncHandler(async (req, res) => {
  if (!firestoreReady()) {
    res.status(503).json({ message: 'Firestore is not available on the backend' });
    return;
  }

  const listingId = req.params.listingId;

  const threadResult = await requireThreadParticipant(listingId, req.user.uid);
  if (!threadResult.ok) {
    res.status(threadResult.status || 403).json({ message: threadResult.message || 'Unauthorized: not a participant in this product chat' });
    return;
  }

  const threadId = threadResult.thread.id;

  const snapshot = await admin
    .firestore()
    .collection('messages')
    .where('threadId', '==', threadId)
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

  const threadResult = await requireThreadParticipant(listingId, req.user.uid);
  if (!threadResult.ok) {
    res.status(threadResult.status || 403).json({ message: threadResult.message || 'Unauthorized: not a participant in this product chat' });
    return;
  }

  const threadId = threadResult.thread.id;

  const docId = `${threadId}_${req.user.uid}`;
  await admin.firestore().collection('typing_status').doc(docId).set(
    {
      threadId,
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

  const threadResult = await requireThreadParticipant(listingId, req.user.uid);
  console.log(`[Debug] Stream request user=${req.user.uid} listing=${listingId} participant=${threadResult.ok}`);
  if (!threadResult.ok) {
    res.status(threadResult.status || 403).json({ message: threadResult.message || 'Unauthorized: not a participant in this product chat' });
    return;
  }

  const threadId = threadResult.thread.id;

  const limit = Math.min(Number(req.query.limit) || 100, 200);

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  const sendEvent = (event, payload) => {
    res.write(`event: ${event}\n`);
    res.write(`data: ${JSON.stringify(payload)}\n\n`);
  };

  sendEvent('ready', { ok: true, listingId, threadId });

  const query = admin
    .firestore()
    .collection('messages')
    .where('threadId', '==', threadId)
    .limit(limit);

  const unsubscribeMessages = query.onSnapshot(
    (snapshot) => {
      const rows = snapshot.docs
        .map((doc) => ({ id: doc.id, ...doc.data() }))
        .sort((a, b) => toMillis(a.timestamp) - toMillis(b.timestamp));
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
    .where('threadId', '==', threadId)
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
  const userId = req.user.uid;

  // Find all threads for this listing where user is a participant
  const threadSnap = await listingThreadsCol()
    .where('listingId', '==', listingId)
    .where('participantUids', 'array-contains', userId)
    .get();

  let totalUnreadCount = 0;

  for (const doc of threadSnap.docs) {
    const threadId = doc.id;

    // Count messages where threadId matches and current user is NOT in readBy array
    const snapshot = await admin
      .firestore()
      .collection('messages')
      .where('threadId', '==', threadId)
      .get();

    snapshot.docs.forEach((doc) => {
      const data = doc.data() || {};
      const readBy = Array.isArray(data.readBy) ? data.readBy : [];
      // Count as unread if current user is not in readBy array AND sender is not current user
      if (!readBy.includes(userId) && data.fromUid !== userId) {
        totalUnreadCount += 1;
      }
    });
  }

  res.json({ unreadCount: totalUnreadCount, listingId });
}));

messagesRouter.post('/listing/:listingId/thread', requireAuth, asyncHandler(async (req, res) => {
  if (!firestoreReady()) {
    res.status(503).json({ message: 'Firestore is not available on the backend' });
    return;
  }

  const listingId = req.params.listingId;
  const result = await ensureListingThread({ listingId, userId: req.user.uid, createIfMissing: true });
  if (!result.ok) {
    res.status(result.status || 403).json({ message: result.message || 'Unable to open this product chat' });
    return;
  }

  res.json({
    threadId: listingId,
    ...result.thread,
  });
}));