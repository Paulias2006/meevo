import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler.js';
import { inferNearestKnownCity, normalizeCityLabel } from '../utils/cities.js';

const router = Router();

const reverseQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
});

async function fetchNominatimReverse(lat, lng, zoom) {
  const result = await fetch(
    `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}&zoom=${zoom}&addressdetails=1`,
    {
      headers: {
        'User-Agent': 'Meevo/1.0 (contact: demo.partner@meevo.tg)',
        Accept: 'application/json',
      },
    },
  );

  if (!result.ok) {
    throw new Error('Impossible de detecter la localisation pour le moment.');
  }

  return result.json();
}

router.get(
  '/reverse',
  asyncHandler(async (request, response) => {
    const query = reverseQuerySchema.parse(request.query);

    let payload;
    let areaPayload;

    try {
      [payload, areaPayload] = await Promise.all([
        fetchNominatimReverse(query.lat, query.lng, 18),
        fetchNominatimReverse(query.lat, query.lng, 14),
      ]);
    } catch (_error) {
      return response.status(502).json({
        message: 'Impossible de detecter la localisation pour le moment.',
      });
    }

    const address = payload?.address ?? {};
    const areaAddress = areaPayload?.address ?? {};
    const detectedCity = normalizeCityLabel(
      address.city ||
          address.town ||
          address.village ||
          address.municipality ||
          address.county ||
          areaAddress.city ||
          areaAddress.town ||
          areaAddress.village ||
          areaAddress.municipality ||
          areaAddress.county ||
          inferNearestKnownCity(query.lat, query.lng) ||
          '',
    );
    const district =
      address.suburb ||
      address.neighbourhood ||
      address.quarter ||
      address.city_district ||
      areaAddress.suburb ||
      areaAddress.neighbourhood ||
      areaAddress.quarter ||
      areaAddress.city_district ||
      areaAddress.hamlet ||
      areaAddress.road ||
      address.hamlet ||
      '';
    const displayAddress = payload?.display_name?.toString() ?? '';
    const googleMapsUrl =
      `https://www.google.com/maps/search/?api=1&query=${query.lat},${query.lng}`;

    response.json({
      item: {
        latitude: query.lat,
        longitude: query.lng,
        city: detectedCity,
        district,
        address: displayAddress,
        googleMapsUrl,
      },
    });
  }),
);

export const locationRouter = router;
