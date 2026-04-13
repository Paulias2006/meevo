import mongoose from 'mongoose';

const reservationPaymentSchema = new mongoose.Schema(
  {
    customer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    partner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    venue: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Venue',
      required: true,
      index: true,
    },
    provider: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Provider',
    },
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      index: true,
    },
    identifier: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    description: {
      type: String,
      trim: true,
      default: '',
    },
    customerName: {
      type: String,
      trim: true,
      default: '',
    },
    customerEmail: {
      type: String,
      trim: true,
      default: '',
    },
    eventType: {
      type: String,
      required: true,
      trim: true,
    },
    eventDate: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    startTime: {
      type: String,
      required: true,
      trim: true,
    },
    endTime: {
      type: String,
      required: true,
      trim: true,
    },
    guestCount: {
      type: Number,
      required: true,
      min: 1,
    },
    budget: {
      type: Number,
      min: 0,
    },
    notes: {
      type: String,
      trim: true,
      default: '',
    },
    grossAmount: {
      type: Number,
      required: true,
      min: 0,
    },
    platformFeeRate: {
      type: Number,
      required: true,
      min: 0,
      default: 0.05,
    },
    platformFeeAmount: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },
    partnerNetAmount: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
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
    bookingCreatedAt: {
      type: Date,
    },
    holdExpiresAt: {
      type: Date,
      index: true,
    },
    payoutStatus: {
      type: String,
      enum: ['pending_profile', 'ready', 'paid'],
      default: 'pending_profile',
      index: true,
    },
    payoutPhoneNumber: {
      type: String,
      trim: true,
      default: '',
    },
    payoutNetwork: {
      type: String,
      enum: ['', 'MOOV', 'TOGOCEL'],
      default: '',
    },
    payoutAccountName: {
      type: String,
      trim: true,
      default: '',
    },
    payoutPaidAt: {
      type: Date,
    },
    payoutReference: {
      type: String,
      trim: true,
      default: '',
    },
    payoutNotes: {
      type: String,
      trim: true,
      default: '',
    },
    lastStatusPayload: {
      type: mongoose.Schema.Types.Mixed,
    },
  },
  {
    timestamps: true,
  },
);

reservationPaymentSchema.index({
  venue: 1,
  eventDate: 1,
  startTime: 1,
  endTime: 1,
  status: 1,
  holdExpiresAt: 1,
});

reservationPaymentSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    customer: this.customer,
    partner: this.partner,
    venue: this.venue,
    provider: this.provider,
    booking: this.booking,
    identifier: this.identifier,
    description: this.description,
    customerName: this.customerName,
    customerEmail: this.customerEmail,
    eventType: this.eventType,
    eventDate: this.eventDate,
    startTime: this.startTime,
    endTime: this.endTime,
    guestCount: this.guestCount,
    budget: this.budget,
    notes: this.notes,
    grossAmount: this.grossAmount,
    platformFeeRate: this.platformFeeRate,
    platformFeeAmount: this.platformFeeAmount,
    partnerNetAmount: this.partnerNetAmount,
    network: this.network,
    phoneNumber: this.phoneNumber,
    paymentUrl: this.paymentUrl,
    status: this.status,
    txReference: this.txReference,
    paymentReference: this.paymentReference,
    paymentMethod: this.paymentMethod,
    paidAt: this.paidAt,
    bookingCreatedAt: this.bookingCreatedAt,
    holdExpiresAt: this.holdExpiresAt,
    payoutStatus: this.payoutStatus,
    payoutPhoneNumber: this.payoutPhoneNumber,
    payoutNetwork: this.payoutNetwork,
    payoutAccountName: this.payoutAccountName,
    payoutPaidAt: this.payoutPaidAt,
    payoutReference: this.payoutReference,
    payoutNotes: this.payoutNotes,
    createdAt: this.createdAt,
  };
};

export const ReservationPayment = mongoose.model(
  'ReservationPayment',
  reservationPaymentSchema,
);
