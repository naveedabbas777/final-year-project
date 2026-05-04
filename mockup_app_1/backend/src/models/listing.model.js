import mongoose from 'mongoose';

const listingSchema = new mongoose.Schema(
  {
    sellerUid: { type: String, required: true, index: true },
    sellerRef: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    cropName: { type: String, required: true, index: true },
    qualityGrade: { type: String, default: 'A' },
    quantity: { type: Number, required: true },
    unit: { type: String, required: true, default: '40kg' },
    askingPrice: { type: Number, required: true },
    district: { type: String, required: true, index: true },
    description: { type: String, default: '' },
    imageUrls: { type: [String], default: [] },
    status: {
      type: String,
      enum: ['open', 'reserved', 'sold', 'cancelled'],
      default: 'open',
      index: true,
    },
  },
  { timestamps: true },
);

listingSchema.index({ cropName: 1, district: 1, status: 1, createdAt: -1 });

export const ListingModel = mongoose.model('Listing', listingSchema);
