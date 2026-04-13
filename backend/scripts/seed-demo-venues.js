import mongoose from 'mongoose';
import slugify from 'slugify';
import { connectDatabase } from '../src/config/database.js';
import { env } from '../src/config/env.js';
import { User } from '../src/models/User.js';
import { Venue } from '../src/models/Venue.js';
import { hashPassword } from '../src/utils/auth.js';
import { normalizeCityLabel } from '../src/utils/cities.js';

const demoPartner = {
  fullName: 'Meevo Demo Partner',
  email: 'demo.partner@meevo.tg',
  phone: '+22890000000',
  password: 'MeevoPartner2026!',
  city: 'Lome',
  partnerProfile: {
    businessName: 'Meevo Collection Demo',
    partnerType: 'Lieu hybride',
    whatsapp: '+22890000000',
    district: 'Adidogome',
    description:
      'Compte partenaire de demonstration pour afficher des lieux de test dans Meevo.',
  },
};

const sampleVideos = [
  'https://samplelib.com/lib/preview/mp4/sample-5s.mp4',
  'https://samplelib.com/lib/preview/mp4/sample-10s.mp4',
  'https://samplelib.com/lib/preview/mp4/sample-15s.mp4',
  'https://www.w3schools.com/html/mov_bbb.mp4',
  'https://filesamples.com/samples/video/mp4/sample_640x360.mp4',
];

const cityConfigs = [
  {
    city: 'Lome',
    latitude: 6.1319,
    longitude: 1.2228,
    districts: ['Adidogome', 'Agoe', 'Tokoin', 'Baguida', 'Kodjoviakope'],
  },
  {
    city: 'Kara',
    latitude: 9.5511,
    longitude: 1.1861,
    districts: ['Tomde', 'Kpewa', 'Dongoyo', 'Lama', 'Pya'],
  },
  {
    city: 'Sokode',
    latitude: 8.9833,
    longitude: 1.1333,
    districts: ['Kpangalam', 'Komah', 'Tchawanda', 'Administratif', 'Koloware'],
  },
  {
    city: 'Kpalime',
    latitude: 6.9,
    longitude: 0.6333,
    districts: ['Agome', 'Domi', 'Adeta', 'Nyiveme', 'Tomegbe'],
  },
  {
    city: 'Atakpame',
    latitude: 7.5333,
    longitude: 1.1333,
    districts: ['Djama', 'Gbogbo', 'Gnagna', 'Kpessi', 'Campement'],
  },
  {
    city: 'Dapaong',
    latitude: 10.8623,
    longitude: 0.2054,
    districts: ['Nassable', 'Nano', 'Zongo', 'Koni', 'Kombonloaga'],
  },
  {
    city: 'Tsevie',
    latitude: 6.4261,
    longitude: 1.2133,
    districts: ['Daviemondji', 'Kpota', 'Mission Tove', 'Wli', 'Zongo'],
  },
  {
    city: 'Aneho',
    latitude: 6.2333,
    longitude: 1.6,
    districts: ['Zebe', 'Deguenon', 'Glidji', 'Djeta', 'Hahotoe'],
  },
  {
    city: 'Notse',
    latitude: 6.95,
    longitude: 1.1667,
    districts: ['Kpata', 'Gbodjome', 'Atchikpoe', 'Hleve', 'Zongo'],
  },
  {
    city: 'Bassar',
    latitude: 9.25,
    longitude: 0.7833,
    districts: ['Kabou', 'Nangbani', 'Dimori', 'Mante', 'Kpekpalime'],
  },
];

const venueProfiles = [
  {
    brand: 'Palais Harmonie',
    venueType: 'salle',
    baseCapacity: 550,
    basePrice: 420000,
    opensAt: '08:00',
    closesAt: '23:30',
    eventTypes: ['Mariage', 'Conference', 'Gala', 'Anniversaire'],
    amenities: [
      'Climatisation',
      'Parking',
      'Sono',
      'Wifi',
      'Cuisine',
      'Securite',
    ],
    summary:
      'Grande salle premium pour receptions, conferences et evenements haut de gamme.',
  },
  {
    brand: 'Hotel Azur Events',
    venueType: 'hotel',
    baseCapacity: 280,
    basePrice: 310000,
    opensAt: '07:00',
    closesAt: '22:00',
    eventTypes: ['Seminaire', 'Cocktail', 'Conference', 'Mariage'],
    amenities: [
      'Parking',
      'Climatisation',
      'Hebergement',
      'Restaurant',
      'Wifi',
    ],
    summary:
      'Hotel evenementiel avec salles modulables, hebergement et service restauration.',
  },
  {
    brand: 'Domaine Signature',
    venueType: 'espace',
    baseCapacity: 420,
    basePrice: 360000,
    opensAt: '09:00',
    closesAt: '23:00',
    eventTypes: ['Garden Party', 'Mariage', 'Concert', 'Cocktail'],
    amenities: [
      'Jardin',
      'Parking',
      'Scene',
      'Groupe electrogene',
      'Toilettes VIP',
    ],
    summary:
      'Espace evenementiel ouvert avec jardin, scene et circulation fluide pour grands formats.',
  },
  {
    brand: 'Villa Prestige',
    venueType: 'villa',
    baseCapacity: 180,
    basePrice: 240000,
    opensAt: '10:00',
    closesAt: '23:59',
    eventTypes: ['Anniversaire', 'Cocktail', 'Garden Party', 'Mariage'],
    amenities: [
      'Piscine',
      'Jardin',
      'Cuisine',
      'Parking',
      'Decor lumineux',
    ],
    summary:
      'Villa privee avec exterieurs soignes pour anniversaires, cocktails et petits mariages.',
  },
  {
    brand: 'Terrasse Baobab',
    venueType: 'restaurant',
    baseCapacity: 220,
    basePrice: 190000,
    opensAt: '11:00',
    closesAt: '22:30',
    eventTypes: ['Cocktail', 'Anniversaire', 'Seminaire', 'Diner prive'],
    amenities: [
      'Restauration',
      'Parking',
      'Terrasse',
      'Sono legere',
      'Wifi',
    ],
    summary:
      'Restaurant privatisable avec terrasse, restauration et formule evenement tout inclus.',
  },
];

function addDays(date, count) {
  const nextDate = new Date(date);
  nextDate.setDate(nextDate.getDate() + count);
  return nextDate;
}

function addMonths(date, count) {
  const nextDate = new Date(date);
  nextDate.setMonth(nextDate.getMonth() + count);
  return nextDate;
}

function toDateString(date) {
  return date.toISOString().slice(0, 10);
}

function buildPhotoUrls(slug) {
  return [
    `https://picsum.photos/seed/${slug}-cover/1400/900`,
    `https://picsum.photos/seed/${slug}-gallery-1/1400/900`,
    `https://picsum.photos/seed/${slug}-gallery-2/1400/900`,
    `https://picsum.photos/seed/${slug}-gallery-3/1400/900`,
  ];
}

function buildGoogleMapsUrl(name, district, city) {
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
    `${name}, ${district}, ${city}, Togo`,
  )}`;
}

function buildDemoVenues(partnerId) {
  const today = new Date();
  let index = 0;

  return cityConfigs.flatMap((cityConfig) =>
    cityConfig.districts.map((district, districtIndex) => {
      const profile = venueProfiles[districtIndex % venueProfiles.length];
      const canonicalCity = normalizeCityLabel(cityConfig.city);
      const name = `${profile.brand} ${district}`;
      const slug = slugify(`${name}-${canonicalCity}`, {
        lower: true,
        strict: true,
      });
      const photos = buildPhotoUrls(slug);
      const latitude = Number(
        (cityConfig.latitude + districtIndex * 0.006 - 0.01).toFixed(6),
      );
      const longitude = Number(
        (cityConfig.longitude + districtIndex * 0.007 - 0.012).toFixed(6),
      );
      const blockedDate = toDateString(addDays(today, 18 + (index % 9)));
      const manualDate = toDateString(addDays(today, 10 + (index % 7)));

      const venue = {
        name,
        venueType: profile.venueType,
        slug,
        shortDescription: `${profile.summary} Situe a ${district}, ${canonicalCity}.`,
        description:
          `${name} se situe a ${district}, ${canonicalCity}, et propose un cadre pense pour les evenements reels sur Meevo. ` +
          `Le lieu convient aux formats ${profile.eventTypes.join(', ')} avec une capacite confortable, une logistique claire et des medias de presentation en ligne.`,
        city: canonicalCity,
        district,
        address: `${district}, ${canonicalCity}, Togo`,
        googleMapsUrl: buildGoogleMapsUrl(name, district, canonicalCity),
        country: 'Togo',
        coordinates: {
          latitude,
          longitude,
        },
        capacity: profile.baseCapacity + index * 6,
        startingPrice: profile.basePrice + index * 9000,
        currency: 'FCFA',
        eventTypes: profile.eventTypes,
        amenities: profile.amenities,
        photos,
        videoUrl: sampleVideos[index % sampleVideos.length],
        coverPhoto: photos.first,
        businessHours: {
          opensAt: profile.opensAt,
          closesAt: profile.closesAt,
        },
        rating: Number((4.1 + (index % 8) * 0.1).toFixed(1)),
        reviewCount: 18 + index * 5,
        isPopular: index < 18 || index % 4 === 0,
        isFeatured: index < 12,
        status: 'published',
        partner: partnerId,
        blockedDates: index % 9 === 0 ? [blockedDate] : [],
        manualBlocks:
          index % 5 === 0
            ? [
                {
                  date: manualDate,
                  startTime: '14:00',
                  endTime: '18:00',
                  reason: 'Blocage manuel demo',
                },
              ]
            : [],
      };

      index += 1;
      return venue;
    }),
  );
}

async function ensureDemoPartner() {
  const passwordHash = await hashPassword(demoPartner.password);

  return User.findOneAndUpdate(
    { email: demoPartner.email },
    {
      $set: {
        fullName: demoPartner.fullName,
        phone: demoPartner.phone,
        city: demoPartner.city,
        role: 'partner',
        passwordHash,
        partnerProfile: {
          ...demoPartner.partnerProfile,
          submittedAt: new Date(),
        },
        subscription: {
          status: 'active',
          cycle: 'annual',
          months: 12,
          monthlyPrice: 50000,
          grossAmount: 600000,
          discountAmount: 60000,
          totalAmount: 540000,
          paygateNetwork: 'MOOV',
          paymentMethod: 'Flooz',
          currentPaymentIdentifier: 'demo-seed-subscription',
          startedAt: new Date(),
          endsAt: addMonths(new Date(), 12),
          lastPaymentAt: new Date(),
        },
      },
      $setOnInsert: {
        email: demoPartner.email,
      },
    },
    {
      upsert: true,
      new: true,
      setDefaultsOnInsert: true,
    },
  );
}

async function seedDemoVenues() {
  await connectDatabase(env.MONGODB_URI);

  const partner = await ensureDemoPartner();
  const venues = buildDemoVenues(partner._id);
  const slugs = venues.map((venue) => venue.slug);

  await Venue.deleteMany({
    partner: partner._id,
    slug: { $nin: slugs },
  });

  for (const venue of venues) {
    await Venue.findOneAndUpdate(
      { slug: venue.slug },
      {
        $set: venue,
      },
      {
        upsert: true,
        new: true,
        setDefaultsOnInsert: true,
      },
    );
  }

  const totalForPartner = await Venue.countDocuments({ partner: partner._id });

  console.log(`50 lieux de demonstration sont prets pour Meevo.`);
  console.log(`Compte partenaire demo: ${demoPartner.email}`);
  console.log(`Mot de passe demo: ${demoPartner.password}`);
  console.log(`Lieux attaches a ce partenaire: ${totalForPartner}`);
}

seedDemoVenues()
  .then(async () => {
    await mongoose.disconnect();
    process.exit(0);
  })
  .catch(async (error) => {
    console.error('Seed impossible:', error);
    await mongoose.disconnect();
    process.exit(1);
  });
