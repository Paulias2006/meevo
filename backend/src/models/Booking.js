import mongoose from 'mongoose';

const bookingSchema = new mongoose.Schema(
  {
    customer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    venue: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Venue',
      required: true,
    },
    provider: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Provider',
    },
    customerName: {
      type: String,
      trim: true,
      default: '',
    },
    customerPhone: {
      type: String,
      trim: true,
      default: '',
    },
    source: {
      type: String,
      enum: ['platform', 'manual'],
      default: 'platform',
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
    },
    startTime: {
      type: String,
      required: true,
      trim: true,
      default: '08:00',
    },
    endTime: {
      type: String,
      required: true,
      trim: true,
      default: '23:00',
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
    depositAmount: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalAmount: {
      type: Number,
      default: 0,
      min: 0,
    },
    status: {
      type: String,
      enum: ['pending', 'confirmed', 'rejected', 'cancelled'],
      default: 'pending',
    },
    notes: {
      type: String,
      trim: true,
      default: '',
    },
    customerArchivedAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
  },
);

bookingSchema.index({
  venue: 1,
  eventDate: 1,
  startTime: 1,
  endTime: 1,
  status: 1,
});

bookingSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    customer: this.customer,
    venue: this.venue,
    provider: this.provider,
    customerName: this.customerName,
    customerPhone: this.customerPhone,
    source: this.source,
    eventType: this.eventType,
    eventDate: this.eventDate,
    startTime: this.startTime,
    endTime: this.endTime,
    guestCount: this.guestCount,
    budget: this.budget,
    depositAmount: this.depositAmount,
    totalAmount: this.totalAmount,
    status: this.status,
    notes: this.notes,
    customerArchivedAt: this.customerArchivedAt,
    createdAt: this.createdAt,
  };
};

export const Booking = mongoose.model('Booking', bookingSchema);
