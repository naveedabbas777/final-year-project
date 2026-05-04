import mongoose from 'mongoose';

const offerSchema = new mongoose.Schema(
  {
    listingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Listing',
      required: true,
      index: true,
    },
    buyerUid: { type: String, required: true, index: true },
    buyerRef: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    offerPrice: { type: Number, required: true },
    quantity: { type: Number, required: true },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'rejected', 'cancelled'],
      default: 'pending',
      index: true,
    },
  },
  { timestamps: true },
);

offerSchema.index({ listingId: 1, status: 1, createdAt: -1 });

export const OfferModel = mongoose.model('Offer', offerSchema);
