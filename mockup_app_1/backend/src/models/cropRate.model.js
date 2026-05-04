import mongoose from 'mongoose';

const cropRateSchema = new mongoose.Schema(
  {
    cropName: { type: String, required: true, index: true },
    marketName: { type: String, required: true, index: true },
    district: { type: String, required: true, index: true },
    minPrice: { type: Number, required: true },
    maxPrice: { type: Number, required: true },
    unit: { type: String, required: true, default: '40kg' },
    sourceName: { type: String, required: true },
    sourceUrl: { type: String, required: true },
    isOfficialSource: { type: Boolean, default: true },
    rateDate: { type: Date, required: true, index: true },
  },
  { timestamps: true },
);

cropRateSchema.index({ cropName: 1, district: 1, rateDate: -1 });

export const CropRateModel = mongoose.model('CropRate', cropRateSchema);
