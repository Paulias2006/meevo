import mongoose from 'mongoose';

const providerSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },
    category: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      trim: true,
      default: '',
    },
    city: {
      type: String,
      required: true,
      trim: true,
    },
    startingPrice: {
      type: Number,
      required: true,
      min: 0,
    },
    currency: {
      type: String,
      default: 'FCFA',
    },
    rating: {
      type: Number,
      default: 0,
      min: 0,
      max: 5,
    },
    reviewCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    photoUrl: {
      type: String,
      trim: true,
      default: '',
    },
    phone: {
      type: String,
      trim: true,
      default: '',
    },
    whatsapp: {
      type: String,
      trim: true,
      default: '',
    },
    email: {
      type: String,
      trim: true,
      default: '',
    },
    partner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    isFeatured: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  },
);

providerSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    name: this.name,
    category: this.category,
    description: this.description,
    city: this.city,
    startingPrice: this.startingPrice,
    currency: this.currency,
    rating: this.rating,
    reviewCount: this.reviewCount,
    photoUrl: this.photoUrl,
    phone: this.phone,
    whatsapp: this.whatsapp,
    email: this.email,
    isFeatured: this.isFeatured,
    createdAt: this.createdAt,
  };
};

export const Provider = mongoose.model('Provider', providerSchema);
