import mongoose from 'mongoose';

const subscriptionPaymentSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    identifier: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    months: {
      type: Number,
      required: true,
      min: 1,
    },
    cycle: {
      type: String,
      enum: ['monthly', 'annual', 'custom'],
      required: true,
    },
    monthlyPrice: {
      type: Number,
      required: true,
      min: 0,
    },
    grossAmount: {
      type: Number,
      required: true,
      min: 0,
    },
    discountAmount: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },
    totalAmount: {
      type: Number,
      required: true,
      min: 0,
    },
    network: {
      type: String,
      enum: ['MOOV', 'TOGOCEL'],
      required: true,
    },
    phoneNumber: {
      type: String,
      trim: true,
      default: '',
    },
    partnerType: {
      type: String,
      trim: true,
      default: '',
    },
    modules: {
      type: [String],
      default: [],
    },
    description: {
      type: String,
      trim: true,
      default: '',
    },
    paymentUrl: {
      type: String,
      trim: true,
      default: '',
    },
    status: {
      type: String,
      enum: ['pending', 'processing', 'success', 'expired', 'cancelled', 'failed'],
      default: 'pending',
      index: true,
    },
    txReference: {
      type: String,
      trim: true,
      default: '',
    },
    paymentReference: {
      type: String,
      trim: true,
      default: '',
    },
    paymentMethod: {
      type: String,
      trim: true,
      default: '',
    },
    paidAt: {
      type: Date,
    },
    appliedAt: {
      type: Date,
    },
    lastStatusPayload: {
      type: mongoose.Schema.Types.Mixed,
    },
  },
  {
    timestamps: true,
  },
);

subscriptionPaymentSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    identifier: this.identifier,
    months: this.months,
    cycle: this.cycle,
    monthlyPrice: this.monthlyPrice,
    grossAmount: this.grossAmount,
    discountAmount: this.discountAmount,
    totalAmount: this.totalAmount,
    network: this.network,
    phoneNumber: this.phoneNumber,
    partnerType: this.partnerType,
    modules: this.modules,
    description: this.description,
    paymentUrl: this.paymentUrl,
    status: this.status,
    txReference: this.txReference,
    paymentReference: this.paymentReference,
    paymentMethod: this.paymentMethod,
    paidAt: this.paidAt,
    appliedAt: this.appliedAt,
    createdAt: this.createdAt,
  };
};

export const SubscriptionPayment = mongoose.model(
  'SubscriptionPayment',
  subscriptionPaymentSchema,
);
