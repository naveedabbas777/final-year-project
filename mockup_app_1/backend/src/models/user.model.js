import mongoose from 'mongoose';

const userSchema = new mongoose.Schema(
  {
    firebaseUid: { type: String, required: true, unique: true, index: true },
    name: { type: String, trim: true },
    phone: { 
      type: String, 
      trim: true, 
      sparse: true,
      default: null
    },
    countryCode: { type: String, default: '+92', trim: true }, // Pakistan default
    role: {
      type: String,
      enum: ['farmer', 'buyer', 'admin'],
      default: 'farmer',
      index: true,
    },
    district: { type: String, trim: true },
    province: { type: String, trim: true },
  },
  { timestamps: true },
);

// Compound index to ensure unique phone+countryCode combinations (when both exist)
userSchema.index({ phone: 1, countryCode: 1 }, { sparse: true, unique: true });

export const UserModel = mongoose.model('User', userSchema);
