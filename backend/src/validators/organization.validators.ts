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
