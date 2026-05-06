import mongoose from 'mongoose';

const ratingSchema = new mongoose.Schema(
  {
    targetUid: { type: String, required: true, index: true },
    raterUid: { type: String, required: true, index: true },
    score: { type: Number, required: true, min: 1, max: 5 },
    comment: { type: String, default: '' },
  },
  { timestamps: true },
);

ratingSchema.index({ targetUid: 1, createdAt: -1 });

export const RatingModel = mongoose.model('Rating', ratingSchema);
