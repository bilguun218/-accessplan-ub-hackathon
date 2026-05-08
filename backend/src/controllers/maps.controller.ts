import { Request, Response } from 'express';
import axios from 'axios';
import { ApiError } from '../utils/ApiError';

// Google Maps Legacy APIs
const FIND_PLACE_URL =
  'https://maps.googleapis.com/maps/api/place/findplacefromtext/json';
const PLACE_DETAILS_URL =
  'https://maps.googleapis.com/maps/api/place/details/json';

const UB_LAT = 47.918873;
const UB_LNG = 106.917701;
const UB_RADIUS_METERS = 50000;

function getApiKey(): string {
  const key = process.env.GOOGLE_MAPS_API_KEY;
  if (!key) {
    throw new ApiError(500, 'Google Maps API түлхүүр тохируулагдаагүй байна.');
  }
  return key;
}

function handleGoogleStatus(status: string, errorMessage?: string) {
  if (status === 'OK' || status === 'ZERO_RESULTS') return;
  if (status === 'INVALID_REQUEST') {
    throw new ApiError(400, 'Хүсэлт буруу байна.');
  }
  if (status === 'OVER_QUERY_LIMIT' || status === 'RESOURCE_EXHAUSTED') {
    throw new ApiError(
      429,
      'Хайлтын хязгаар хэтэрлээ. Дараа дахин оролдоно уу.',
    );
  }
  if (status === 'REQUEST_DENIED') {
    throw new ApiError(
      500,
      errorMessage || 'Google API түлхүүр зөвшөөрөлгүй байна.',
    );
  }
  throw new ApiError(
    502,
    errorMessage || 'Google Maps үйлчилгээнээс алдаа ирлээ.',
  );
}

/**
 * Find Place From Text — текстээр газар хайх.
 * Returns up to ~10 candidates with full info (no extra call needed).
 * Цэнхэр UI-н "suggestion list" болгон ашиглана.
 */
export async function autocomplete(req: Request, res: Response) {
  const inputRaw = req.query.input;
  const input = typeof inputRaw === 'string' ? inputRaw.trim() : '';

  if (!input) {
    res.json([]);
    return;
  }

  const apiKey = getApiKey();

  try {
    const response = await axios.get(FIND_PLACE_URL, {
      params: {
        input,
        inputtype: 'textquery',
        language: 'mn',
        fields: 'place_id,name,formatted_address,geometry',
        locationbias: `circle:${UB_RADIUS_METERS}@${UB_LAT},${UB_LNG}`,
        key: apiKey,
      },
      timeout: 10000,
    });

    const data = response.data || {};
    handleGoogleStatus(data.status, data.error_message);

    if (data.status === 'ZERO_RESULTS') {
      res.json([]);
      return;
    }

    const candidates = Array.isArray(data.candidates) ? data.candidates : [];

    const result = candidates.map((c: any) => {
      const name = c.name ?? '';
      const address = c.formatted_address ?? '';
      return {
        placeId: c.place_id ?? '',
        description: address ? `${name}, ${address}` : name,
        mainText: name,
        secondaryText: address,
      };
    });

    res.json(result);
  } catch (err) {
    if (err instanceof ApiError) throw err;
    if (axios.isAxiosError(err)) {
      throw new ApiError(502, 'Байршил хайхад алдаа гарлаа.');
    }
    throw new ApiError(500, 'Дотоод алдаа гарлаа.');
  }
}

/**
 * Place Details — placeId-аар координат + дэлгэрэнгүй авах.
 */
export async function placeDetails(req: Request, res: Response) {
  const placeIdRaw = req.query.placeId;
  const placeId = typeof placeIdRaw === 'string' ? placeIdRaw.trim() : '';

  if (!placeId) {
    throw new ApiError(400, 'placeId шаардлагатай.');
  }

  const apiKey = getApiKey();

  try {
    const response = await axios.get(PLACE_DETAILS_URL, {
      params: {
        place_id: placeId,
        fields: 'place_id,name,formatted_address,geometry',
        language: 'mn',
        key: apiKey,
      },
      timeout: 10000,
    });

    const data = response.data || {};
    handleGoogleStatus(data.status, data.error_message);

    if (data.status === 'ZERO_RESULTS' || !data.result) {
      throw new ApiError(404, 'Байршил олдсонгүй.');
    }

    const r = data.result;
    const lat = r.geometry?.location?.lat;
    const lng = r.geometry?.location?.lng;

    if (typeof lat !== 'number' || typeof lng !== 'number') {
      throw new ApiError(502, 'Байршлын координат олдсонгүй.');
    }

    res.json({
      placeId: r.place_id ?? placeId,
      name: r.name ?? '',
      address: r.formatted_address ?? '',
      latitude: lat,
      longitude: lng,
    });
  } catch (err) {
    if (err instanceof ApiError) throw err;
    if (axios.isAxiosError(err)) {
      throw new ApiError(502, 'Байршлын мэдээлэл татахад алдаа гарлаа.');
    }
    throw new ApiError(500, 'Дотоод алдаа гарлаа.');
  }
}
