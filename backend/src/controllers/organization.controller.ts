import { Request, Response } from 'express';
import { Types } from 'mongoose';
import { ApiError } from '../utils/ApiError';
import { BusinessPost, IBusinessPost } from '../models/BusinessPost';
import { Organization, IOrganization } from '../models/Organization';
import { OrganizationRequest } from '../models/OrganizationRequest';
import {
  businessPostSchema,
  nearbyOrganizationsSchema,
  organizationRequestSchema,
  organizationSchema,
  updateBusinessPostSchema,
  updateOrganizationSchema,
} from '../validators/organization.validators';

export async function submitOrganizationRequest(req: Request, res: Response) {
  const data = organizationRequestSchema.parse(req.body);

  const request = await OrganizationRequest.create({
    organizationName: data.organizationName,
    activityType: data.activityType,
    registrationNumber: data.registrationNumber,
    location: data.location,
    contactPerson: data.contactPerson,
    phone: data.phone,
    email: data.email.toLowerCase(),
    description: data.description || undefined,
    verificationMethod: data.verificationMethod,
  });

  res.status(201).json({
    request: {
      id: request._id,
      status: request.status,
      organizationName: request.organizationName,
      createdAt: request.createdAt,
    },
  });
}

function requireUser(req: Request) {
  if (!req.user) throw ApiError.unauthorized();
  return req.user;
}

function coordinates(org: IOrganization) {
  const [longitude, latitude] = org.location.coordinates;
  return { latitude, longitude };
}

function serializeOrganization(org: IOrganization, distanceKm?: number) {
  const coords = coordinates(org);
  return {
    id: org._id.toString(),
    businessName: org.businessName,
    branchName: org.branchName ?? null,
    serviceType: org.serviceType,
    description: org.description ?? '',
    address: org.address,
    latitude: coords.latitude,
    longitude: coords.longitude,
    phone: org.phone ?? null,
    email: org.email ?? null,
    website: org.website ?? null,
    workingHours: org.workingHours ?? null,
    parkingAvailable: org.parkingAvailable,
    accessibilityAvailable: org.accessibilityAvailable,
    digitalServicesAvailable: org.digitalServicesAvailable,
    isVerified: org.isVerified,
    status: org.status,
    createdAt: org.createdAt,
    updatedAt: org.updatedAt,
    ...(distanceKm === undefined ? {} : { distanceKm }),
  };
}

function serializePost(post: IBusinessPost) {
  return {
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
    createdAt: post.createdAt,
    updatedAt: post.updatedAt,
  };
}

async function requireOwnedOrganization(
  organizationId: string,
  userId: string,
  role?: string
) {
  if (!Types.ObjectId.isValid(organizationId)) {
    throw ApiError.notFound('Organization not found.', 'ORGANIZATION_NOT_FOUND');
  }
  const org = await Organization.findById(organizationId);
  if (!org) {
    throw ApiError.notFound('Organization not found.', 'ORGANIZATION_NOT_FOUND');
  }
  if (role !== 'admin' && org.ownerUserId.toString() !== userId) {
    throw ApiError.forbidden('Organization owner required.', 'OWNER_REQUIRED');
  }
  return org;
}

export async function createOrganization(req: Request, res: Response) {
  const user = requireUser(req);
  const data = organizationSchema.parse(req.body);

  const organization = await Organization.create({
    ownerUserId: new Types.ObjectId(user.id),
    businessName: data.businessName,
    branchName: data.branchName || undefined,
    serviceType: data.serviceType,
    description: data.description || undefined,
    address: data.address,
    location: {
      type: 'Point',
      coordinates: [data.longitude, data.latitude],
    },
    phone: data.phone || undefined,
    email: data.email || undefined,
    website: data.website || undefined,
    workingHours: data.workingHours,
    parkingAvailable: data.parkingAvailable,
    accessibilityAvailable: data.accessibilityAvailable,
    digitalServicesAvailable: data.digitalServicesAvailable,
    status: data.status,
  });

  res.status(201).json({ organization: serializeOrganization(organization) });
}

export async function getMyOrganization(req: Request, res: Response) {
  const user = requireUser(req);
  const organization = await Organization.findOne({
    ownerUserId: user.id,
  }).sort({ updatedAt: -1 });
  res.json({
    organization: organization ? serializeOrganization(organization) : null,
  });
}

export async function listOrganizations(req: Request, res: Response) {
  const serviceType =
    typeof req.query.serviceType === 'string' && req.query.serviceType.trim()
      ? req.query.serviceType.trim()
      : undefined;
  const filter: Record<string, unknown> = { status: 'active' };
  if (serviceType) filter.serviceType = serviceType;

  const organizations = await Organization.find(filter)
    .sort({ updatedAt: -1 })
    .limit(100);
  res.json({
    items: organizations.map((org) => serializeOrganization(org)),
  });
}

export async function listNearbyOrganizations(req: Request, res: Response) {
  const data = nearbyOrganizationsSchema.parse(req.query);
  const filter: Record<string, unknown> = {
    status: 'active',
    location: {
      $near: {
        $geometry: {
          type: 'Point',
          coordinates: [data.lng, data.lat],
        },
        $maxDistance: data.radius * 1000,
      },
    },
  };
  if (data.serviceType) filter.serviceType = data.serviceType;

  const organizations = await Organization.find(filter).limit(100);
  res.json({
    items: organizations.map((org) =>
      serializeOrganization(
        org,
        distanceKm(data.lat, data.lng, ...coordinatesTuple(org))
      )
    ),
  });
}

export async function getOrganizationById(req: Request, res: Response) {
  const { id } = req.params;
  if (!Types.ObjectId.isValid(id)) {
    throw ApiError.notFound('Organization not found.', 'ORGANIZATION_NOT_FOUND');
  }
  const organization = await Organization.findById(id);
  if (!organization || organization.status !== 'active') {
    throw ApiError.notFound('Organization not found.', 'ORGANIZATION_NOT_FOUND');
  }
  res.json({ organization: serializeOrganization(organization) });
}

export async function updateOrganization(req: Request, res: Response) {
  const user = requireUser(req);
  const organization = await requireOwnedOrganization(
    req.params.id,
    user.id,
    user.role
  );
  const data = updateOrganizationSchema.parse(req.body);

  if (data.businessName !== undefined) organization.businessName = data.businessName;
  if (data.branchName !== undefined) organization.branchName = data.branchName || undefined;
  if (data.serviceType !== undefined) organization.serviceType = data.serviceType;
  if (data.description !== undefined) organization.description = data.description || undefined;
  if (data.address !== undefined) organization.address = data.address;
  if (data.phone !== undefined) organization.phone = data.phone || undefined;
  if (data.email !== undefined) organization.email = data.email || undefined;
  if (data.website !== undefined) organization.website = data.website || undefined;
  if (data.workingHours !== undefined) organization.workingHours = data.workingHours;
  if (data.parkingAvailable !== undefined) {
    organization.parkingAvailable = data.parkingAvailable;
  }
  if (data.accessibilityAvailable !== undefined) {
    organization.accessibilityAvailable = data.accessibilityAvailable;
  }
  if (data.digitalServicesAvailable !== undefined) {
    organization.digitalServicesAvailable = data.digitalServicesAvailable;
  }
  if (data.status !== undefined) organization.status = data.status;
  if (data.latitude !== undefined || data.longitude !== undefined) {
    const [oldLng, oldLat] = organization.location.coordinates;
    organization.location = {
      type: 'Point',
      coordinates: [data.longitude ?? oldLng, data.latitude ?? oldLat],
    };
  }

  await organization.save();
  res.json({ organization: serializeOrganization(organization) });
}

export async function createOrganizationPost(req: Request, res: Response) {
  const user = requireUser(req);
  const organization = await requireOwnedOrganization(
    req.params.organizationId,
    user.id,
    user.role
  );
  const data = businessPostSchema.parse(req.body);
  const post = await BusinessPost.create({
    organizationId: organization._id,
    title: data.title,
    description: data.description,
    type: data.type,
    imageUrl: data.imageUrl ?? null,
    startsAt: data.startsAt ?? null,
    endsAt: data.endsAt ?? null,
    isActive: data.isActive,
    showOnMap: data.showOnMap,
    isSponsored: data.isSponsored,
  });

  res.status(201).json({ post: serializePost(post) });
}

export async function listOrganizationPosts(req: Request, res: Response) {
  const user = requireUser(req);
  const organization = await requireOwnedOrganization(
    req.params.organizationId,
    user.id,
    user.role
  );
  const posts = await BusinessPost.find({ organizationId: organization._id })
    .sort({ updatedAt: -1 })
    .limit(100);
  res.json({ items: posts.map((post) => serializePost(post)) });
}

export async function getPostById(req: Request, res: Response) {
  const { id } = req.params;
  if (!Types.ObjectId.isValid(id)) {
    throw ApiError.notFound('Post not found.', 'POST_NOT_FOUND');
  }
  const post = await BusinessPost.findById(id);
  if (!post) throw ApiError.notFound('Post not found.', 'POST_NOT_FOUND');
  res.json({ post: serializePost(post) });
}

export async function updatePost(req: Request, res: Response) {
  const user = requireUser(req);
  const { id } = req.params;
  if (!Types.ObjectId.isValid(id)) {
    throw ApiError.notFound('Post not found.', 'POST_NOT_FOUND');
  }
  const post = await BusinessPost.findById(id);
  if (!post) throw ApiError.notFound('Post not found.', 'POST_NOT_FOUND');
  await requireOwnedOrganization(post.organizationId.toString(), user.id, user.role);

  const data = updateBusinessPostSchema.parse(req.body);
  if (data.title !== undefined) post.title = data.title;
  if (data.description !== undefined) post.description = data.description;
  if (data.type !== undefined) post.type = data.type;
  if (data.imageUrl !== undefined) post.imageUrl = data.imageUrl ?? null;
  if (data.startsAt !== undefined) post.startsAt = data.startsAt ?? null;
  if (data.endsAt !== undefined) post.endsAt = data.endsAt ?? null;
  if (data.isActive !== undefined) post.isActive = data.isActive;
  if (data.showOnMap !== undefined) post.showOnMap = data.showOnMap;
  if (data.isSponsored !== undefined) post.isSponsored = data.isSponsored;

  await post.save();
  res.json({ post: serializePost(post) });
}

function coordinatesTuple(org: IOrganization): [number, number] {
  const [lng, lat] = org.location.coordinates;
  return [lat, lng];
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
