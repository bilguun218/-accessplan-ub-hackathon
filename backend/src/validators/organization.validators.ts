import { z } from 'zod';

const phoneSchema = z
  .string()
  .trim()
  .regex(/^(\+?976)?[6-9]\d{7}$/, 'Утасны дугаар буруу байна.');

export const organizationRequestSchema = z.object({
  organizationName: z.string().trim().min(2, 'Байгууллагын нэр шаардлагатай.'),
  activityType: z.string().trim().min(2, 'Үйл ажиллагааны чиглэл шаардлагатай.'),
  registrationNumber: z
    .string()
    .trim()
    .min(4, 'Улсын бүртгэлийн дугаар шаардлагатай.'),
  location: z.string().trim().min(2, 'Байршил шаардлагатай.'),
  contactPerson: z.string().trim().min(2, 'Холбоо барих хүний нэр шаардлагатай.'),
  phone: phoneSchema,
  email: z.string().trim().email('Имэйл формат буруу байна.'),
  description: z.string().trim().max(800).optional().or(z.literal('')),
  verificationMethod: z.enum(['emongolia', 'document']).default('emongolia'),
});

export type OrganizationRequestDto = z.infer<typeof organizationRequestSchema>;

const coordinatesSchema = z.object({
  latitude: z.coerce
    .number()
    .min(-90, 'latitude must be >= -90')
    .max(90, 'latitude must be <= 90'),
  longitude: z.coerce
    .number()
    .min(-180, 'longitude must be >= -180')
    .max(180, 'longitude must be <= 180'),
});

export const organizationSchema = z
  .object({
    businessName: z.string().trim().min(2),
    branchName: z.string().trim().optional().or(z.literal('')),
    serviceType: z.string().trim().min(2),
    description: z.string().trim().optional().or(z.literal('')),
    address: z.string().trim().min(2),
    phone: z.string().trim().optional().or(z.literal('')),
    email: z.string().trim().email().optional().or(z.literal('')),
    website: z.string().trim().optional().or(z.literal('')),
    workingHours: z.unknown().optional(),
    parkingAvailable: z.boolean().default(false),
    accessibilityAvailable: z.boolean().default(false),
    digitalServicesAvailable: z.boolean().default(false),
    status: z
      .enum(['active', 'pending', 'rejected', 'suspended'])
      .default('active'),
  })
  .merge(coordinatesSchema);

export const updateOrganizationSchema = organizationSchema.partial();

export const nearbyOrganizationsSchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().positive().max(50).optional().default(5),
  serviceType: z.string().trim().optional(),
});

export const businessPostSchema = z.object({
  title: z.string().trim().min(2),
  description: z.string().trim().min(2),
  type: z
    .enum([
      'promotion',
      'announcement',
      'event',
      'discount',
      'service_update',
      'general',
    ])
    .default('promotion'),
  imageUrl: z.string().trim().optional().nullable(),
  startsAt: z.coerce.date().optional().nullable(),
  endsAt: z.coerce.date().optional().nullable(),
  isActive: z.boolean().default(true),
  showOnMap: z.boolean().default(true),
  isSponsored: z.boolean().default(false),
});

export const updateBusinessPostSchema = businessPostSchema.partial();

export type OrganizationDto = z.infer<typeof organizationSchema>;
export type UpdateOrganizationDto = z.infer<typeof updateOrganizationSchema>;
export type BusinessPostDto = z.infer<typeof businessPostSchema>;
