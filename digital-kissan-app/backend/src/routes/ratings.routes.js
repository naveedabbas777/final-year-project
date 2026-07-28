import { Router } from 'express';

import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { col, docToJson, queryToJson, serverTimestamp } from '../utils/firestoreHelpers.js';
import { asyncHandler } from '../utils/errors.js';

export const ratingsRouter = Router();

// ─────────────────────────────────────────────────────────────────────────────
// Helper: verify buyer has a completed order with the seller
// ─────────────────────────────────────────────────────────────────────────────
async function hasCompletedOrderWithSeller(buyerUid, sellerUid) {
  const snap = await col('orders')
    .where('buyerUid', '==', buyerUid)
    .where('sellerUid', '==', sellerUid)
    .where('status', '==', 'completed')
    .limit(1)
    .get();
  return !snap.empty;
}

// Helper: check if buyer has already rated this seller
async function hasAlreadyRated(raterUid, targetUid) {
  const snap = await col('ratings')
    .where('raterUid', '==', raterUid)
    .where('targetUid', '==', targetUid)
    .limit(1)
    .get();
  return !snap.empty;
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/ratings/eligibility/:targetUid
// Returns whether the authenticated user is allowed to rate this seller.
// Rules:
//   1. Must have at least one completed order as buyer with this seller.
//   2. Must not have already submitted a rating for this seller.
// ─────────────────────────────────────────────────────────────────────────────
ratingsRouter.get('/eligibility/:targetUid', requireAuth, asyncHandler(async (req, res) => {
  const raterUid = req.user.uid;
  const targetUid = String(req.params.targetUid || '').trim();

  if (!targetUid) {
    return res.status(400).json({ canRate: false, reason: 'targetUid is required' });
  }

  // Cannot rate yourself
  if (raterUid === targetUid) {
    return res.json({ canRate: false, reason: 'cannot_rate_self' });
  }

  const [hasOrder, alreadyRated] = await Promise.all([
    hasCompletedOrderWithSeller(raterUid, targetUid),
    hasAlreadyRated(raterUid, targetUid),
  ]);

  if (!hasOrder) {
    return res.json({ canRate: false, reason: 'no_completed_order' });
  }
  if (alreadyRated) {
    return res.json({ canRate: false, reason: 'already_rated' });
  }

  res.json({ canRate: true, reason: 'eligible' });
}));

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/ratings
// Submit a rating for a seller.
// Security:
//   - Must be authenticated.
//   - Must have a completed order as buyer with the targetUid seller.
//   - Cannot rate the same seller twice.
//   - Score must be 1–5.
// ─────────────────────────────────────────────────────────────────────────────
ratingsRouter.post('/', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  const { targetUid, score, comment } = req.body || {};
  const raterUid = req.user.uid;

  if (!targetUid || score == null) {
    return res.status(400).json({ message: 'targetUid and score are required' });
  }

  const numeric = Number(score);
  if (Number.isNaN(numeric) || numeric < 1 || numeric > 5) {
    return res.status(400).json({ message: 'score must be between 1 and 5' });
  }

  // Cannot rate yourself
  if (raterUid === targetUid) {
    return res.status(403).json({ message: 'You cannot rate yourself' });
  }

  // Must have a completed order with this seller as buyer
  const hasOrder = await hasCompletedOrderWithSeller(raterUid, targetUid);
  if (!hasOrder) {
    return res.status(403).json({
      message: 'You can only rate a seller after a completed order with them.',
      reason: 'no_completed_order',
    });
  }

  // Prevent duplicate ratings (one per buyer-seller pair)
  const alreadyRated = await hasAlreadyRated(raterUid, targetUid);
  if (alreadyRated) {
    return res.status(409).json({
      message: 'You have already rated this seller.',
      reason: 'already_rated',
    });
  }

  const trimmedComment = typeof comment === 'string' ? comment.trim() : '';
  if (trimmedComment.length > 500) {
    return res.status(400).json({ message: 'comment must be 500 characters or fewer' });
  }

  const data = {
    targetUid,
    raterUid,
    score: numeric,
    comment: trimmedComment,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const ref = await col('ratings').add(data);
  const snap = await ref.get();
  res.status(201).json(docToJson(snap));
}));

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/ratings/:uid
// Public: fetch ratings summary + recent reviews for a seller.
// ─────────────────────────────────────────────────────────────────────────────
ratingsRouter.get('/:uid', asyncHandler(async (req, res) => {
  const uid = req.params.uid;

  const [recentSnap, allSnap] = await Promise.all([
    col('ratings').where('targetUid', '==', uid).orderBy('createdAt', 'desc').limit(20).get(),
    col('ratings').where('targetUid', '==', uid).get(),
  ]);

  const recent = queryToJson(recentSnap);

  let totalScore = 0;
  let count = 0;
  allSnap.docs.forEach((doc) => {
    const data = doc.data();
    if (typeof data.score === 'number') {
      totalScore += data.score;
      count += 1;
    }
  });

  const stats = count > 0
    ? { avgScore: +(totalScore / count).toFixed(2), count }
    : { avgScore: 0, count: 0 };

  res.json({ stats, recent });
}));
