import { Router } from 'express';

import { RatingModel } from '../models/rating.model.js';
import { requireAuth } from '../middlewares/auth.js';
import { attachDbUser } from '../middlewares/attachDbUser.js';

export const ratingsRouter = Router();

// Post a rating for a user
ratingsRouter.post('/', requireAuth, attachDbUser, async (req, res, next) => {
  try {
    const { targetUid, score, comment } = req.body || {};
    if (!targetUid || !score) {
      return res.status(400).json({ message: 'targetUid and score are required' });
    }

    const numeric = Number(score);
    if (Number.isNaN(numeric) || numeric < 1 || numeric > 5) {
      return res.status(400).json({ message: 'Score must be 1-5' });
    }

    const doc = await RatingModel.create({ targetUid, raterUid: req.user.uid, score: numeric, comment: comment || '' });
    res.status(201).json(doc);
  } catch (err) {
    next(err);
  }
});

// Fetch ratings for a user (summary + recent)
ratingsRouter.get('/:uid', async (req, res, next) => {
  try {
    const uid = req.params.uid;
    const recent = await RatingModel.find({ targetUid: uid }).sort({ createdAt: -1 }).limit(20);
    const agg = await RatingModel.aggregate([
      { $match: { targetUid: uid } },
      { $group: { _id: '$targetUid', avgScore: { $avg: '$score' }, count: { $sum: 1 } } },
    ]);

    const stats = agg && agg.length ? { avgScore: agg[0].avgScore, count: agg[0].count } : { avgScore: 0, count: 0 };
    res.json({ stats, recent });
  } catch (err) {
    next(err);
  }
});
