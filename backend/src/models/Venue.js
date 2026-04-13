import mongoose from 'mongoose';

const venueSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },
    venueType: {
      type: String,
      trim: true,
      default: 'salle',
    },
    slug: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    shortDescription: {
      type: String,
      trim: true,
      default: '',
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
    district: {
      type: String,
      trim: true,
      default: '',
    },
    address: {
      type: String,
      trim: true,
      default: '',
    },
    googleMapsUrl: {
      type: String,
      trim: true,
      default: '',
    },
    country: {
      type: String,
      trim: true,
      default: 'Togo',
    },
    coordinates: {
      latitude: {
        type: Number,
      },
      longitude: {
        type: Number,
      },
    },
    capacity: {
      type: Number,
      required: true,
      min: 1,
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
    eventTypes: {
      type: [String],
      default: [],
    },
    amenities: {
      type: [String],
      default: [],
    },
    photos: {
      type: [String],
      default: [],
    },
    videoUrl: {
      type: String,
      trim: true,
      default: '',
    },
    coverPhoto: {
      type: String,
      trim: true,
      default: '',
    },
    businessHours: {
      opensAt: {
        type: String,
        default: '08:00',
      },
      closesAt: {
        type: String,
        default: '23:00',
      },
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
    isPopular: {
      type: Boolean,
      default: false,
    },
    isFeatured: {
      type: Boolean,
      default: false,
    },
    status: {
      type: String,
      enum: ['draft', 'published', 'archived'],
      default: 'published',
    },
    partner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    blockedDates: {
      type: [String],
      default: [],
    },
    manualBlocks: {
      type: [
        new mongoose.Schema(
          {
            date: {
              type: String,
              required: true,
              trim: true,
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
            reason: {
              type: String,
              trim: true,
              default: '',
            },
          },
          { _id: false },
        ),
      ],
      default: [],
    },
  },
  {
    timestamps: true,
  },
);

venueSchema.index({ name: 'text', city: 'text', district: 'text' });

venueSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    name: this.name,
    venueType: this.venueType,
    slug: this.slug,
    shortDescription: this.shortDescription,
    description: this.description,
    city: this.city,
    district: this.district,
    address: this.address,
    googleMapsUrl: this.googleMapsUrl,
    country: this.country,
    coordinates: this.coordinates,
    capacity: this.capacity,
    startingPrice: this.startingPrice,
    currency: this.currency,
    eventTypes: this.eventTypes,
    amenities: this.amenities,
    photos: this.photos,
    videoUrl: this.videoUrl,
    coverPhoto: this.coverPhoto,
    businessHours: this.businessHours,
    rating: this.rating,
    reviewCount: this.reviewCount,
    isPopular: this.isPopular,
    isFeatured: this.isFeatured,
    status: this.status,
    blockedDates: this.blockedDates,
    manualBlocks: this.manualBlocks,
    createdAt: this.createdAt,
  };
};

export const Venue = mongoose.model('Venue', venueSchema);
