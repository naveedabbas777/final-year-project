import { initFirebaseAdmin, admin } from '../config/firebaseAdmin.js';

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

async function commitBatches(ops, dryRun) {
  if (dryRun || ops.length === 0) return;
  const firestore = admin.firestore();
  let batch = firestore.batch();
  let count = 0;

  for (const op of ops) {
    if (op.type === 'set') {
      batch.set(op.ref, op.data, op.options || {});
    } else if (op.type === 'update') {
      batch.update(op.ref, op.data);
    } else if (op.type === 'delete') {
      batch.delete(op.ref);
    }
    count += 1;

    if (count === 450) {
      await batch.commit();
      batch = firestore.batch();
      count = 0;
    }
  }

  if (count > 0) {
    await batch.commit();
  }
}

function pickEarliestBuyer(messages, sellerUid) {
  const firstSeen = new Map();
  for (const message of messages) {
    const timestamp = toMillis(message.timestamp);
    const candidates = [String(message.fromUid || '').trim(), String(message.toUid || '').trim()]
      .filter((uid) => uid && uid !== sellerUid);
    for (const uid of candidates) {
      if (!firstSeen.has(uid) || timestamp < firstSeen.get(uid)) {
        firstSeen.set(uid, timestamp);
      }
    }
  }

  if (firstSeen.size === 0) return { buyerUid: null, buyerCount: 0 };
  const sorted = [...firstSeen.entries()].sort((a, b) => a[1] - b[1]);
  return {
    buyerUid: sorted[0][0],
    buyerCount: firstSeen.size,
  };
}

async function cleanup({ dryRun }) {
  initFirebaseAdmin();
  const firestore = admin.firestore();

  const messagesSnap = await firestore.collection('messages').get();
  const byListing = new Map();

  messagesSnap.docs.forEach((doc) => {
    const row = { id: doc.id, ref: doc.ref, ...doc.data() };
    const listingId = String(row.listingId || '').trim();
    if (!listingId) return;
    if (!byListing.has(listingId)) byListing.set(listingId, []);
    byListing.get(listingId).push(row);
  });

  let touchedListings = 0;
  let archivedMessages = 0;
  let updatedMessages = 0;
  let createdThreads = 0;
  let skippedNoSeller = 0;
  let skippedNoBuyer = 0;

  const ops = [];

  for (const [listingId, listingMessages] of byListing.entries()) {
    const listingSnap = await firestore.collection('listings').doc(listingId).get();
    if (!listingSnap.exists) continue;
    const listing = listingSnap.data() || {};
    const sellerUid = String(listing.sellerUid || '').trim();
    if (!sellerUid) {
      skippedNoSeller += 1;
      continue;
    }

    const sortedMessages = [...listingMessages].sort(
      (a, b) => toMillis(a.timestamp) - toMillis(b.timestamp),
    );
    const { buyerUid, buyerCount } = pickEarliestBuyer(sortedMessages, sellerUid);
    if (!buyerUid) {
      skippedNoBuyer += 1;
      continue;
    }

    touchedListings += 1;

    const keepParticipants = new Set([sellerUid, buyerUid]);
    const kept = [];
    const removed = [];

    for (const row of sortedMessages) {
      const fromUid = String(row.fromUid || '').trim();
      const toUid = String(row.toUid || '').trim();
      const fromValid = !fromUid || keepParticipants.has(fromUid);
      const toValid = !toUid || keepParticipants.has(toUid);
      if (fromValid && toValid) {
        kept.push(row);
      } else {
        removed.push(row);
      }
    }

    for (const row of removed) {
      const archiveRef = firestore.collection('messages_archive').doc();
      ops.push({
        type: 'set',
        ref: archiveRef,
        data: {
          ...row,
          originalMessageId: row.id,
          archiveReason: 'multi_buyer_cleanup_part1',
          keptBuyerUid: buyerUid,
          archivedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
      ops.push({ type: 'delete', ref: row.ref });
      archivedMessages += 1;
    }

    let lastMessage = '';
    let lastMessageAt = null;
    let lastMessageFromUid = null;
    let lastMessageToUid = null;

    for (const row of kept) {
      const fromUid = String(row.fromUid || '').trim();
      const patchedToUid = String(row.toUid || '').trim() || (fromUid === sellerUid ? buyerUid : sellerUid);
      ops.push({
        type: 'update',
        ref: row.ref,
        data: {
          listingId,
          threadId: listingId,
          sellerUid,
          buyerUid,
          toUid: patchedToUid,
        },
      });
      updatedMessages += 1;
      lastMessage = String(row.message || lastMessage);
      lastMessageAt = row.timestamp || lastMessageAt;
      lastMessageFromUid = fromUid || lastMessageFromUid;
      lastMessageToUid = patchedToUid || lastMessageToUid;
    }

    const threadRef = firestore.collection('listing_threads').doc(listingId);
    const imageUrls = Array.isArray(listing.imageUrls) ? listing.imageUrls : [];
    ops.push({
      type: 'set',
      ref: threadRef,
      data: {
        listingId,
        sellerUid,
        buyerUid,
        participantUids: [sellerUid, buyerUid],
        productName: String(listing.cropName || listing.productName || 'Product').trim() || 'Product',
        productImageUrl: typeof imageUrls[0] === 'string' ? imageUrls[0] : '',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        buyerCountBeforeCleanup: buyerCount,
        lastMessage,
        lastMessageAt: lastMessageAt || null,
        lastMessageFromUid,
        lastMessageToUid,
      },
      options: { merge: true },
    });
    createdThreads += 1;
  }

  await commitBatches(ops, dryRun);

  console.log('[Cleanup] Completed');
  console.log(`[Cleanup] dryRun=${dryRun}`);
  console.log(`[Cleanup] listingsTouched=${touchedListings}`);
  console.log(`[Cleanup] messagesArchived=${archivedMessages}`);
  console.log(`[Cleanup] messagesUpdated=${updatedMessages}`);
  console.log(`[Cleanup] threadsUpserted=${createdThreads}`);
  console.log(`[Cleanup] skippedNoSeller=${skippedNoSeller}`);
  console.log(`[Cleanup] skippedNoBuyer=${skippedNoBuyer}`);
}

const dryRun = !process.argv.includes('--apply');

cleanup({ dryRun })
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('[Cleanup] Failed', error);
    process.exit(1);
  });
