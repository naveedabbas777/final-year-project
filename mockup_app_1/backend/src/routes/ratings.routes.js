import { Router } from 'express';

import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';
import { col, docToJson, queryToJson, serverTimestamp } from '../utils/firestoreHelpers.js';
import { asyncHandler } from '../utils/errors.js';

export const ratingsRouter = Router();

// Post a rating for a user
ratingsRouter.post('/', requireAuth, attachDbUser, asyncHandler(async (req, res) => {
  const { targetUid, score, comment } = req.body || {};
  if (!targetUid || !score) {
    return res.status(400).json({ message: 'targetUid and score are required' });
  }

  const numeric = Number(score);
  if (Number.isNaN(numeric) || numeric < 1 || numeric > 5) {
    return res.status(400).json({ message: 'Score must be 1-5' });
  }

  const data = {
    targetUid,
    raterUid: req.user.uid,
    score: numeric,
    comment: comment || '',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  const ref = await col('ratings').add(data);
  const snap = await ref.get();
  res.status(201).json(docToJson(snap));
}));

// Fetch ratings for a user (summary + recent)
ratingsRouter.get('/:uid', asyncHandler(async (req, res) => {
  const uid = req.params.uid;
  const recentSnap = await col('ratings')
    .where('targetUid', '==', uid)
    .orderBy('createdAt', 'desc')
    .limit(20)
    .get();

  const recent = queryToJson(recentSnap);

  // Compute avg and count in JS (replaces MongoDB aggregate)
  let totalScore = 0;
  let count = 0;
  // To get accurate count/avg, we may need all ratings (not just 20)
  const allSnap = await col('ratings')
    .where('targetUid', '==', uid)
    .get();

  allSnap.docs.forEach((doc) => {
    const data = doc.data();
    if (typeof data.score === 'number') {
      totalScore += data.score;
      count += 1;
    }
  });

  const stats = count > 0
    ? { avgScore: totalScore / count, count }
    : { avgScore: 0, count: 0 };

  res.json({ stats, recent });
}));
