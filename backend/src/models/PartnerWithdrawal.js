import mongoose from 'mongoose';

const partnerWithdrawalSchema = new mongoose.Schema(
  {
    partner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    amount: {
      type: Number,
      required: true,
      min: 0,
    },
    currency: {
      type: String,
      trim: true,
      default: 'XOF',
    },
    network: {
      type: String,
      enum: ['MOOV', 'TOGOCEL'],
      required: true,
    },
    phoneNumber: {
      type: String,
      required: true,
      trim: true,
    },
    accountName: {
      type: String,
      trim: true,
      default: '',
    },
    clientTransferId: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    cinetpayTransferId: {
      type: String,
      trim: true,
      default: '',
    },
    lot: {
      type: String,
      trim: true,
      default: '',
    },
    transferStatus: {
      type: String,
      trim: true,
      default: '',
    },
    sendingStatus: {
      type: String,
      trim: true,
      default: '',
    },
    comment: {
      type: String,
      trim: true,
      default: '',
    },
    status: {
      type: String,
      enum: ['pending', 'processing', 'paid', 'rejected', 'failed'],
      default: 'pending',
      index: true,
    },
    adminNotes: {
      type: String,
      trim: true,
      default: '',
    },
    requestedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
    processedAt: {
      type: Date,
    },
    paidAt: {
      type: Date,
    },
    lastProviderPayload: {
      type: mongoose.Schema.Types.Mixed,
    },
  },
  {
    timestamps: true,
  },
);

partnerWithdrawalSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    partner: this.partner,
    amount: this.amount,
    currency: this.currency,
    network: this.network,
    phoneNumber: this.phoneNumber,
    accountName: this.accountName,
    clientTransferId: this.clientTransferId,
    cinetpayTransferId: this.cinetpayTransferId,
    lot: this.lot,
    transferStatus: this.transferStatus,
    sendingStatus: this.sendingStatus,
    comment: this.comment,
    status: this.status,
    adminNotes: this.adminNotes,
    requestedAt: this.requestedAt,
    processedAt: this.processedAt,
    paidAt: this.paidAt,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt,
  };
};

export const PartnerWithdrawal = mongoose.model(
  'PartnerWithdrawal',
  partnerWithdrawalSchema,
);
