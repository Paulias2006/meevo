const knownCities = new Map([
  ['lome', 'Lome'],
  ['kara', 'Kara'],
  ['sokode', 'Sokode'],
  ['kpalime', 'Kpalime'],
  ['atakpame', 'Atakpame'],
  ['dapaong', 'Dapaong'],
  ['tsevie', 'Tsevie'],
  ['aneho', 'Aneho'],
  ['notse', 'Notse'],
  ['bassar', 'Bassar'],
]);

const cityCenters = [
  { label: 'Lome', latitude: 6.1319, longitude: 1.2228 },
  { label: 'Kara', latitude: 9.5511, longitude: 1.1861 },
  { label: 'Sokode', latitude: 8.9833, longitude: 1.1333 },
  { label: 'Kpalime', latitude: 6.9, longitude: 0.6333 },
  { label: 'Atakpame', latitude: 7.5333, longitude: 1.1333 },
  { label: 'Dapaong', latitude: 10.8639, longitude: 0.2056 },
  { label: 'Tsevie', latitude: 6.4261, longitude: 1.2133 },
  { label: 'Aneho', latitude: 6.228, longitude: 1.592 },
  { label: 'Notse', latitude: 6.95, longitude: 1.1667 },
  { label: 'Bassar', latitude: 9.2502, longitude: 0.7821 },
];

function normalizeKey(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '');
}

export function normalizeCityLabel(value, fallback = '') {
  const rawValue = String(value || '').trim();
  if (!rawValue) {
    return fallback;
  }

  const key = normalizeKey(rawValue);
  if (knownCities.has(key)) {
    return knownCities.get(key);
  }

  return rawValue
    .split(/\s+/)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
    .join(' ');
}

function haversineDistanceKm(leftLat, leftLng, rightLat, rightLng) {
  const earthRadiusKm = 6371;
  const toRad = (value) => (value * Math.PI) / 180;
  const dLat = toRad(rightLat - leftLat);
  const dLng = toRad(rightLng - leftLng);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(leftLat)) *
      Math.cos(toRad(rightLat)) *
      Math.sin(dLng / 2) ** 2;

  return 2 * earthRadiusKm * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function inferNearestKnownCity(latitude, longitude) {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return '';
  }

  let closest = null;

  for (const city of cityCenters) {
    const distance = haversineDistanceKm(
      latitude,
      longitude,
      city.latitude,
      city.longitude,
    );

    if (!closest || distance < closest.distance) {
      closest = { label: city.label, distance };
    }
  }

  return closest?.label ?? '';
}
