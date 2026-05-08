import bcrypt from 'bcrypt';
import { User, IUser } from '../models/User';
import { ApiError } from '../utils/ApiError';
import { sanitizeUser } from '../utils/sanitizeUser';
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
  hashToken,
  generateResetToken,
} from './token.service';
import { sendPasswordResetEmail } from './email.service';

const SALT_ROUNDS = 12;
const MAX_REFRESH_TOKENS = 5;

export interface RegisterInput {
  fullName: string;
  email: string;
  phone?: string;
  password: string;
  userType: IUser['userType'];
  district?: string;
  preferredLanguage?: IUser['preferredLanguage'];
}

async function issueTokens(user: IUser) {
  const accessToken = signAccessToken(user._id.toString(), user.role);
  const { token: refreshToken } = signRefreshToken(user._id.toString());
  const refreshHash = hashToken(refreshToken);

  const hashes = (user.refreshTokenHashes ?? []).concat(refreshHash);
  const trimmed = hashes.slice(-MAX_REFRESH_TOKENS);
  await User.updateOne(
    { _id: user._id },
    { $set: { refreshTokenHashes: trimmed, lastLoginAt: new Date() } }
  );

  return { accessToken, refreshToken };
}

export async function registerUser(input: RegisterInput) {
  const existing = await User.findOne({ email: input.email.toLowerCase() });
  if (existing) {
    throw ApiError.conflict('Энэ имэйлээр бүртгэл үүссэн байна.', 'EMAIL_EXISTS');
  }

  const passwordHash = await bcrypt.hash(input.password, SALT_ROUNDS);
  const user = await User.create({
    fullName: input.fullName.trim(),
    email: input.email.toLowerCase().trim(),
    phone: input.phone?.trim(),
    passwordHash,
    userType: input.userType,
    role: input.userType === 'organization' ? 'organization' : 'user',
    district: input.district,
    preferredLanguage: input.preferredLanguage ?? 'mn',
  });

  const tokens = await issueTokens(user);
  return { user: sanitizeUser(user), ...tokens };
}

export async function loginUser(email: string, password: string) {
  const user = await User.findOne({ email: email.toLowerCase() }).select(
    '+passwordHash +refreshTokenHashes'
  );
  if (!user) {
    throw ApiError.unauthorized('Имэйл эсвэл нууц үг буруу байна.', 'INVALID_CREDENTIALS');
  }
  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) {
    throw ApiError.unauthorized('Имэйл эсвэл нууц үг буруу байна.', 'INVALID_CREDENTIALS');
  }
  const tokens = await issueTokens(user);
  return { user: sanitizeUser(user), ...tokens };
}

export async function refreshAccessToken(refreshToken: string) {
  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch {
    throw ApiError.unauthorized('Refresh token хүчингүй.', 'INVALID_REFRESH');
  }
  const user = await User.findById(payload.sub).select('+refreshTokenHashes');
  if (!user) throw ApiError.unauthorized('Хэрэглэгч олдсонгүй.', 'INVALID_REFRESH');

  const hash = hashToken(refreshToken);
  if (!user.refreshTokenHashes?.includes(hash)) {
    throw ApiError.unauthorized('Refresh token хүчингүй.', 'INVALID_REFRESH');
  }
  const accessToken = signAccessToken(user._id.toString(), user.role);
  return { accessToken };
}

export async function logoutUser(refreshToken: string): Promise<void> {
  try {
    const payload = verifyRefreshToken(refreshToken);
    const hash = hashToken(refreshToken);
    await User.updateOne(
      { _id: payload.sub },
      { $pull: { refreshTokenHashes: hash } }
    );
  } catch {
    // ignore — logout is idempotent
  }
}

export async function forgotPassword(email: string): Promise<void> {
  const user = await User.findOne({ email: email.toLowerCase() });
  if (!user) return; // generic response — do not reveal

  const { token, hash, expiresAt } = generateResetToken();
  await User.updateOne(
    { _id: user._id },
    { $set: { passwordResetTokenHash: hash, passwordResetExpiresAt: expiresAt } }
  );
  await sendPasswordResetEmail(user.email, token);
}

export async function resetPassword(token: string, newPassword: string): Promise<void> {
  const hash = hashToken(token);
  const user = await User.findOne({ passwordResetTokenHash: hash }).select(
    '+passwordResetTokenHash +passwordResetExpiresAt +refreshTokenHashes'
  );
  if (!user || !user.passwordResetExpiresAt || user.passwordResetExpiresAt < new Date()) {
    throw ApiError.badRequest(
      'Сэргээх холбоосын хугацаа дууссан байна.',
      'RESET_TOKEN_EXPIRED'
    );
  }

  const passwordHash = await bcrypt.hash(newPassword, SALT_ROUNDS);
  await User.updateOne(
    { _id: user._id },
    {
      $set: {
        passwordHash,
        passwordResetTokenHash: null,
        passwordResetExpiresAt: null,
        refreshTokenHashes: [],
      },
    }
  );
}

export async function getMe(userId: string) {
  const user = await User.findById(userId);
  if (!user) throw ApiError.notFound('Хэрэглэгч олдсонгүй.', 'USER_NOT_FOUND');
  return sanitizeUser(user);
}
