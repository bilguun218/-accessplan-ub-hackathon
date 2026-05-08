import { IUser } from '../models/User';

export function sanitizeUser(user: IUser) {
  return {
    id: user._id.toString(),
    fullName: user.fullName,
    email: user.email,
    phone: user.phone,
    role: user.role,
    userType: user.userType,
    district: user.district,
    preferredLanguage: user.preferredLanguage,
    isEmailVerified: user.isEmailVerified,
    lastLoginAt: user.lastLoginAt,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}
