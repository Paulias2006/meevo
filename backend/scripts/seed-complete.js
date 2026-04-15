import mongoose from 'mongoose';
import slugify from 'slugify';
import { connectDatabase } from '../src/config/database.js';
import { env } from '../src/config/env.js';
import { User } from '../src/models/User.js';
import { Venue } from '../src/models/Venue.js';
import { Provider } from '../src/models/Provider.js';
import { hashPassword } from '../src/utils/auth.js';
import { normalizeCityLabel } from '../src/utils/cities.js';

// ======================================
// DEMO PARTNERS
// ======================================
const demoPartners = [
  {
    fullName: 'Meevo Demo Partner - Venues',
    email: 'demo.venues@meevo.tg',
    phone: '+22890000001',
    password: 'MeevoVenues2026!',
    city: 'Lome',
    partnerProfile: {
      businessName: 'Meevo Venues Collection',
      partnerType: 'Lieu',
      whatsapp: '+22890000001',
      district: 'Adidogome',
      description: 'Collection de lieux evenementiels pour demonstrations.',
    },
  },
  {
    fullName: 'Meevo Demo Partner - Providers',
    email: 'demo.providers@meevo.tg',
    phone: '+22890000002',
    password: 'MeevoProviders2026!',
    city: 'Lome',
    partnerProfile: {
      businessName: 'Meevo Prestataires Collection',
      partnerType: 'Prestataire',
      whatsapp: '+22890000002',
      district: 'Agoe',
      description: 'Collection de prestataires pour demonstrations.',
    },
  },
];

// ======================================
// PHOTOS EN LIGNE & VIDEOS
// ======================================
const photoServices = {
  venues: [
    'https://images.unsplash.com/photo-1519167758993-651cd2b49eae?w=1400&h=900&fit=crop',
    'https://images.unsplash.com/photo-1501684691209-8eecb1b2deb9?w=1400&h=900&fit=crop',
    'https://images.unsplash.com/photo-1571181837260-d0db0de6e350?w=1400&h=900&fit=crop',
    'https://images.unsplash.com/photo-1606692619913-0dcda76e5f23?w=1400&h=900&fit=crop',
    'https://images.unsplash.com/photo-1464207687429-7505649dae38?w=1400&h=900&fit=crop',
    'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=1400&h=900&fit=crop',
    'https://images.unsplash.com/photo-1468824357306-a439d0b1b18d?w=1400&h=900&fit=crop',
    'https://images.unsplash.com/photo-1552664730-d307ca884978?w=1400&h=900&fit=crop',
  ],
  providers: [
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=1400&h=900&fit=crop',
    'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=1400&h=900&fit=crop',
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=1400&h=900&fit=crop',
    'https://images.unsplash.com/photo-1519904981063-b0cf448d479e?w=1400&h=900&fit=crop',
  ],
};

const videoUrls = [
  'https://commondatastorage.googleapis.com/gtv-videos-library/sample/BigBuckBunny.mp4',
  'https://commondatastorage.googleapis.com/gtv-videos-library/sample/ElephantsDream.mp4',
  'https://commondatastorage.googleapis.com/gtv-videos-library/sample/ForBiggerBlazes.mp4',
  'https://commondatastorage.googleapis.com/gtv-videos-library/sample/ForBiggerEscapes.mp4',
];

// ======================================
// CITIES & DISTRICTS
// ======================================
const cities = [
  { name: 'Lome', lat: 6.1319, lng: 1.2228, districts: ['Adidogome', 'Agoe', 'Tokoin', 'Baguida', 'Kodjoviakope'] },
  { name: 'Kara', lat: 9.5511, lng: 1.1861, districts: ['Tomde', 'Kpewa', 'Dongoyo'] },
  { name: 'Sokode', lat: 8.9833, lng: 1.1333, districts: ['Kpangalam', 'Komah', 'Tchawanda'] },
  { name: 'Kpalime', lat: 6.9, lng: 0.6333, districts: ['Agome', 'Domi', 'Adeta'] },
  { name: 'Atakpame', lat: 7.5333, lng: 1.1333, districts: ['Djama', 'Gbogbo'] },
];

// ======================================
// VENUE TYPES & DATA
// ======================================
const venueTypes = [
  {
    type: 'salle',
    names: ['Salle Premium', 'Salle Harmonie', 'Salle Prestige', 'Salle Elegance'],
    capacity: { min: 400, max: 800 },
    price: { min: 300000, max: 600000 },
    amenities: ['Climatisation', 'Parking', 'Sono', 'Wifi', 'Cuisine', 'Securite', 'Toilettes VIP'],
    eventTypes: ['Mariage', 'Conference', 'Gala', 'Anniversaire'],
  },
  {
    type: 'hotel',
    names: ['Hotel Events', 'Hotel Conference', 'Hotel Mariage', 'Resort Meetings'],
    capacity: { min: 200, max: 400 },
    price: { min: 250000, max: 500000 },
    amenities: ['Parking', 'Climatisation', 'Hebergement', 'Restaurant', 'Wifi', 'Piscine'],
    eventTypes: ['Seminaire', 'Cocktail', 'Conference', 'Mariage'],
  },
  {
    type: 'espace',
    names: ['Domaine Signature', 'Espace Moderne', 'Studio Events', 'Galerie Premium'],
    capacity: { min: 300, max: 600 },
    price: { min: 200000, max: 400000 },
    amenities: ['Jardin', 'Parking', 'Scene', 'Groupe electrogene', 'Toilettes', 'Arts'],
    eventTypes: ['Garden Party', 'Exposition', 'Concert', 'Cocktail'],
  },
  {
    type: 'villa',
    names: ['Villa Luxe', 'Villa Prestige', 'Villa Garden', 'Villa Private'],
    capacity: { min: 100, max: 250 },
    price: { min: 150000, max: 300000 },
    amenities: ['Piscine', 'Jardin', 'Cuisine', 'Parking', 'Decor', 'Terrasse'],
    eventTypes: ['Anniversaire', 'Cocktail', 'Garden Party', 'Mariage'],
  },
  {
    type: 'restaurant',
    names: ['Restaurant Privé', 'Terrasse Baobab', 'Restaurant Premium', 'Bistro Events'],
    capacity: { min: 80, max: 300 },
    price: { min: 100000, max: 250000 },
    amenities: ['Restauration', 'Parking', 'Terrasse', 'Sono', 'Wifi', 'Climatisation'],
    eventTypes: ['Cocktail', 'Anniversaire', 'Diner', 'Reunion'],
  },
];

// ======================================
// PROVIDER CATEGORIES
// ======================================
const providerCategories = [
  {
    category: 'Photographe',
    names: ['Studio Photo Prestige', 'Photographe Pro', 'Photo Events'],
    description: 'Service photo professionnel pour vos evenements',
  },
  {
    category: 'DJ & Musique',
    names: ['DJ Live Events', 'Orchestre Studio', 'Sound Premium'],
    description: 'Animations musicales et sonorisation pour evenements',
  },
  {
    category: 'Catering',
    names: ['Cuisine Events', 'Traiteur Premium', 'Service Gastronomique'],
    description: 'Service de restauration et catering professionnel',
  },
  {
    category: 'Decoration',
    names: ['Decor Studio', 'Design Events', 'Fleuriste Premium'],
    description: 'Decoration et amenagement d evenements',
  },
];

// ======================================
// FUNCTIONS
// ======================================
function addMonths(date, count) {
  const nextDate = new Date(date);
  nextDate.setMonth(nextDate.getMonth() + count);
  return nextDate;
}

function getRandomPhoto(type) {
  const photos = photoServices[type] || photoServices.venues;
  return photos[Math.floor(Math.random() * photos.length)];
}

function getRandomVideo() {
  return videoUrls[Math.floor(Math.random() * videoUrls.length)];
}

function buildPhotoGallery(type, count = 3) {
  const photos = [];
  for (let i = 0; i < count; i++) {
    photos.push(getRandomPhoto(type));
  }
  return photos;
}

async function ensureDemoPartner(partnerData) {
  const passwordHash = await hashPassword(partnerData.password);
  return User.findOneAndUpdate(
    { email: partnerData.email },
    {
      $set: {
        fullName: partnerData.fullName,
        phone: partnerData.phone,
        city: partnerData.city,
        role: 'partner',
        passwordHash,
        partnerProfile: {
          ...partnerData.partnerProfile,
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
          currentPaymentIdentifier: `demo-seed-${Date.now()}`,
          startedAt: new Date(),
          endsAt: addMonths(new Date(), 12),
          lastPaymentAt: new Date(),
        },
      },
      $setOnInsert: { email: partnerData.email },
    },
    { upsert: true, new: true }
  );
}

async function createVenues(partnerId) {
  const venues = [];
  let venueIndex = 0;

  while (venueIndex < 50) {
    const cityIndex = venueIndex % cities.length;
    const city = cities[cityIndex];
    const districtIndex = Math.floor(venueIndex / cities.length) % city.districts.length;
    const district = city.districts[districtIndex];

    const venueType = venueTypes[venueIndex % venueTypes.length];
    const venueProfile = venueType.names[(venueIndex % venueType.names.length)];
    const name = `${venueProfile} #${venueIndex + 1} ${district}`;
    const slug = slugify(`${name}-${city.name}`, { lower: true, strict: true });

    const venue = {
      name,
      venueType: venueType.type,
      slug,
      shortDescription: `${venueProfile} situe a ${district}, ${city.name}. Capacite ${venueType.capacity.min}-${venueType.capacity.max} personnes.`,
      description: `${name} propose des espaces optimises pour vos evenements. Amenagements modernes, services complets et equipe professionnelle.`,
      city: city.name,
      district,
      address: `${district}, ${city.name}, Togo`,
      googleMapsUrl: `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${name}, ${city.name}, Togo`)}`,
      country: 'Togo',
      coordinates: {
        latitude: Number((city.lat + Math.random() * 0.01).toFixed(6)),
        longitude: Number((city.lng + Math.random() * 0.01).toFixed(6)),
      },
      capacity: venueType.capacity.min + Math.floor(Math.random() * (venueType.capacity.max - venueType.capacity.min)),
      startingPrice: venueType.price.min + Math.floor(Math.random() * (venueType.price.max - venueType.price.min)),
      currency: 'FCFA',
      eventTypes: venueType.eventTypes,
      amenities: venueType.amenities,
      photos: buildPhotoGallery('venues', 3),
      videoUrl: getRandomVideo(),
      coverPhoto: getRandomPhoto('venues'),
      businessHours: {
        opensAt: '08:00',
        closesAt: '23:00',
      },
      rating: Number((4.0 + Math.random() * 0.9).toFixed(1)),
      reviewCount: 10 + Math.floor(Math.random() * 40),
      isPopular: venueIndex < 20,
      isFeatured: venueIndex < 10,
      status: 'published',
      partner: partnerId,
      blockedDates: [],
      manualBlocks: [],
    };

    venues.push(venue);
    venueIndex++;
  }

  return venues;
}

async function createProviders(partnerId) {
  const providers = [];

  for (let i = 0; i < 10; i++) {
    const categoryIndex = i % providerCategories.length;
    const category = providerCategories[categoryIndex];
    const nameIndex = i % category.names.length;
    const name = `${category.names[nameIndex]} ${i + 1}`;
    const slug = slugify(name, { lower: true, strict: true });

    const provider = {
      name,
      category: category.category,
      description: `${name} offre des services professionnels de qualite pour vos evenements. Experience, fiabilite et satisfaction garanties.`,
      city: cities[i % cities.length].name,
      startingPrice: 50000 + Math.floor(Math.random() * 200000),
      currency: 'FCFA',
      photoUrl: getRandomPhoto('providers'),
      rating: Number((4.0 + Math.random() * 0.9).toFixed(1)),
      reviewCount: 5 + Math.floor(Math.random() * 30),
      phone: `+228 ${Math.floor(Math.random() * 9000000000 + 1000000000).toString().slice(0, 8)}`,
      whatsapp: `+228 ${Math.floor(Math.random() * 9000000000 + 1000000000).toString().slice(0, 8)}`,
      email: `${slug}@meevo.tg`,
      isFeatured: i < 3,
      partner: partnerId,
    };

    providers.push(provider);
  }

  return providers;
}

// ======================================
// MAIN SEED FUNCTION
// ======================================
async function seedComplete() {
  try {
    await connectDatabase(env.MONGODB_URI);
    console.log('✅ Connected to MongoDB');

    // Create partners
    const venuesPartner = await ensureDemoPartner(demoPartners[0]);
    const providersPartner = await ensureDemoPartner(demoPartners[1]);
    console.log('✅ Demo partners created');

    // Clear existing data
    await Venue.deleteMany({ partner: venuesPartner._id });
    await Provider.deleteMany({ partner: providersPartner._id });
    console.log('✅ Cleared existing data');

    // Create venues
    const venues = await createVenues(venuesPartner._id);
    await Venue.insertMany(venues);
    console.log(`✅ Created ${venues.length} venues`);

    // Create providers
    const providers = await createProviders(providersPartner._id);
    await Provider.insertMany(providers);
    console.log(`✅ Created ${providers.length} providers`);

    console.log('\n🎉 Seeding complete!');
    console.log(`📊 Total: ${venues.length} venues + ${providers.length} providers`);
    console.log('\n🔗 Credentials:');
    console.log(`Venues Partner: ${demoPartners[0].email} / ${demoPartners[0].password}`);
    console.log(`Providers Partner: ${demoPartners[1].email} / ${demoPartners[1].password}`);

    process.exit(0);
  } catch (error) {
    console.error('❌ Seed error:', error);
    process.exit(1);
  }
}

seedComplete();
