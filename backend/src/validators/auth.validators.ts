import { z } from 'zod';

const passwordSchema = z
  .string()
  .min(8, 'Нууц үг доод тал нь 8 тэмдэгт байна.')
  .regex(/[A-Za-z]/, 'Нууц үг доод тал нь нэг үсэг агуулсан байх ёстой.')
  .regex(/[0-9]/, 'Нууц үг доод тал нь нэг тоо агуулсан байх ёстой.');

const phoneSchema = z
  .string()
  .trim()
  .regex(/^(\+?976)?[6-9]\d{7}$/, 'Утасны дугаар буруу байна.')
  .optional()
  .or(z.literal('').transform(() => undefined));

export const registerSchema = z.object({
  fullName: z.string().trim().min(2, 'Овог нэр шаардлагатай.'),
  email: z.string().trim().email('Имэйл формат буруу байна.'),
  phone: phoneSchema,
  password: passwordSchema,
  userType: z.enum([
    'general',
    'elderly',
    'wheelchair',
    'parent_with_stroller',
    'visually_impaired',
    'organization',
  ]),
  district: z.string().trim().optional(),
  preferredLanguage: z.enum(['mn', 'en']).optional(),
});

export const loginSchema = z.object({
  email: z.string().trim().email('Имэйл формат буруу байна.'),
  password: z.string().min(1, 'Нууц үг шаардлагатай.'),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

export const logoutSchema = z.object({
  refreshToken: z.string().min(1),
});

export const forgotPasswordSchema = z.object({
  email: z.string().trim().email('Имэйл формат буруу байна.'),
});

export const resetPasswordSchema = z.object({
  token: z.string().min(1),
  newPassword: passwordSchema,
});

export type RegisterDto = z.infer<typeof registerSchema>;
export type LoginDto = z.infer<typeof loginSchema>;
