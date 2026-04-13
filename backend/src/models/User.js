import mongoose from 'mongoose';

function hasActiveSubscription(subscription) {
  if (!subscription || subscription.status !== 'active' || !subscription.endsAt) {
    return false;
  }

  return new Date(subscription.endsAt).getTime() >= Date.now();
}

const userSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: true,
      trim: true,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    phone: {
      type: String,
      trim: true,
    },
    passwordHash: {
      type: String,
      required: true,
    },
    role: {
      type: String,
      enum: ['customer', 'partner', 'admin'],
      default: 'customer',
    },
    city: {
      type: String,
      trim: true,
    },
    partnerProfile: {
      businessName: {
        type: String,
        trim: true,
      },
      partnerType: {
        type: String,
        trim: true,
      },
      whatsapp: {
        type: String,
        trim: true,
      },
      district: {
        type: String,
        trim: true,
      },
      description: {
        type: String,
        trim: true,
      },
      payoutPhoneNumber: {
        type: String,
        trim: true,
      },
      payoutNetwork: {
        type: String,
        trim: true,
      },
      payoutAccountName: {
        type: String,
        trim: true,
      },
      payoutUpdatedAt: {
        type: Date,
      },
      submittedAt: {
        type: Date,
      },
    },
    subscription: {
      status: {
        type: String,
        enum: ['inactive', 'pending', 'active', 'expired', 'cancelled'],
        default: 'inactive',
      },
      cycle: {
        type: String,
        enum: ['monthly', 'annual', 'custom'],
        default: 'monthly',
      },
      months: {
        type: Number,
        default: 0,
      },
      monthlyPrice: {
        type: Number,
        default: 0,
      },
      grossAmount: {
        type: Number,
        default: 0,
      },
      discountAmount: {
        type: Number,
        default: 0,
      },
      totalAmount: {
        type: Number,
        default: 0,
      },
      paygateNetwork: {
        type: String,
        trim: true,
        default: '',
      },
      paymentMethod: {
        type: String,
        trim: true,
        default: '',
      },
      currentPaymentIdentifier: {
        type: String,
        trim: true,
        default: '',
      },
      startedAt: {
        type: Date,
      },
      endsAt: {
        type: Date,
      },
      lastPaymentAt: {
        type: Date,
      },
    },
  },
  {
    timestamps: true,
  },
);

userSchema.methods.hasOperationalPartnerAccess = function hasOperationalPartnerAccess() {
  if (this.role === 'admin') {
    return true;
  }

  if (this.role !== 'partner') {
    return false;
  }

  return hasActiveSubscription(this.subscription);
};

userSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    fullName: this.fullName,
    email: this.email,
    phone: this.phone,
    role: this.role,
    city: this.city,
    partnerProfile: this.partnerProfile
      ? {
          businessName: this.partnerProfile.businessName,
          partnerType: this.partnerProfile.partnerType,
          whatsapp: this.partnerProfile.whatsapp,
          district: this.partnerProfile.district,
          description: this.partnerProfile.description,
          payoutPhoneNumber: this.partnerProfile.payoutPhoneNumber,
          payoutNetwork: this.partnerProfile.payoutNetwork,
          payoutAccountName: this.partnerProfile.payoutAccountName,
          payoutUpdatedAt: this.partnerProfile.payoutUpdatedAt,
          submittedAt: this.partnerProfile.submittedAt,
        }
      : null,
    subscription: this.subscription
      ? {
          status: this.subscription.status,
          cycle: this.subscription.cycle,
          months: this.subscription.months,
          monthlyPrice: this.subscription.monthlyPrice,
          grossAmount: this.subscription.grossAmount,
          discountAmount: this.subscription.discountAmount,
          totalAmount: this.subscription.totalAmount,
          paymentNetwork: this.subscription.paygateNetwork,
          paymentMethod: this.subscription.paymentMethod,
          currentPaymentIdentifier: this.subscription.currentPaymentIdentifier,
          startedAt: this.subscription.startedAt,
          endsAt: this.subscription.endsAt,
          lastPaymentAt: this.subscription.lastPaymentAt,
          isActive: hasActiveSubscription(this.subscription),
        }
      : null,
    createdAt: this.createdAt,
  };
};

export const User = mongoose.model('User', userSchema);
