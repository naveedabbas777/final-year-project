import mongoose from 'mongoose';

const orderSchema = new mongoose.Schema(
  {
    listingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Listing',
      required: true,
      index: true,
    },
    offerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Offer',
      required: true,
      index: true,
    },
    buyerUid: { type: String, required: true, index: true },
    sellerUid: { type: String, required: true, index: true },
    finalPrice: { type: Number, required: true },
    quantity: { type: Number, required: true },
    unit: { type: String, required: true },
    status: {
      type: String,
      enum: ['created', 'in_transit', 'delivered', 'completed', 'cancelled', 'disputed'],
      default: 'created',
      index: true,
    },
  },
  { timestamps: true },
);

orderSchema.index({ buyerUid: 1, createdAt: -1 });
orderSchema.index({ sellerUid: 1, createdAt: -1 });

export const OrderModel = mongoose.model('Order', orderSchema);
