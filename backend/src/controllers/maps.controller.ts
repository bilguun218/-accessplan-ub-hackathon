import { Request, Response } from 'express';
import axios from 'axios';
import { ApiError } from '../utils/ApiError';
import { BusinessPost } from '../models/BusinessPost';
import { Organization, IOrganization } from '../models/Organization';

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

export async function promotionsNearby(req: Request, res: Response) {
  const lat = numberQuery(req.query.lat);
  const lng = numberQuery(req.query.lng);
  const radius = numberQuery(req.query.radius) ?? 5;

  if (lat === null || lng === null) {
    throw ApiError.badRequest('lat and lng query parameters are required.');
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw ApiError.badRequest('Invalid coordinates.');
  }
  if (radius <= 0 || radius > 50) {
    throw ApiError.badRequest('radius must be between 0 and 50 km.');
  }

  const organizations = await Organization.find({
    status: 'active',
    location: {
      $near: {
        $geometry: {
          type: 'Point',
          coordinates: [lng, lat],
        },
        $maxDistance: radius * 1000,
      },
    },
  }).limit(100);

  if (organizations.length === 0) {
    res.json({ items: [] });
    return;
  }

  const now = new Date();
  const posts = await BusinessPost.find({
    organizationId: { $in: organizations.map((org) => org._id) },
    isActive: true,
    showOnMap: true,
    $and: [
      { $or: [{ startsAt: null }, { startsAt: { $lte: now } }] },
      { $or: [{ endsAt: null }, { endsAt: { $gte: now } }] },
    ],
  }).sort({ isSponsored: -1, updatedAt: -1 });

  const postByOrganization = new Map<string, (typeof posts)[number]>();
  for (const post of posts) {
    const key = post.organizationId.toString();
    if (!postByOrganization.has(key)) postByOrganization.set(key, post);
  }

  const items = organizations
    .map((organization) => {
      const post = postByOrganization.get(organization._id.toString());
      if (!post) return null;
      const [orgLng, orgLat] = organization.location.coordinates;
      const distanceKmValue = distanceKm(lat, lng, orgLat, orgLng);
      return {
        organization: serializeMapOrganization(organization),
        post: {
          id: post._id.toString(),
          organizationId: post.organizationId.toString(),
          title: post.title,
          description: post.description,
          type: post.type,
          imageUrl: post.imageUrl ?? null,
          startsAt: post.startsAt ?? null,
          endsAt: post.endsAt ?? null,
          isActive: post.isActive,
          showOnMap: post.showOnMap,
          isSponsored: post.isSponsored,
        },
        distanceKm: distanceKmValue,
      };
    })
    .filter((item): item is NonNullable<typeof item> => item !== null)
    .sort((a, b) => a.distanceKm - b.distanceKm)
    .slice(0, 15);

  res.json({ items });
}

function numberQuery(value: unknown): number | null {
  if (typeof value !== 'string') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function serializeMapOrganization(org: IOrganization) {
  const [longitude, latitude] = org.location.coordinates;
  return {
    id: org._id.toString(),
    businessName: org.businessName,
    branchName: org.branchName ?? null,
    serviceType: org.serviceType,
    address: org.address,
    latitude,
    longitude,
    phone: org.phone ?? null,
    parkingAvailable: org.parkingAvailable,
    accessibilityAvailable: org.accessibilityAvailable,
    digitalServicesAvailable: org.digitalServicesAvailable,
    isVerified: org.isVerified,
  };
}

function distanceKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
) {
  const earthRadiusKm = 6371;
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(earthRadiusKm * c * 100) / 100;
}

function toRadians(value: number) {
  return (value * Math.PI) / 180;
}
