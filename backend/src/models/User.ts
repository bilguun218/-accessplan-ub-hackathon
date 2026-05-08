import { Schema, model, Document, Types } from 'mongoose';

export type UserType =
  | 'general'
  | 'elderly'
  | 'wheelchair'
  | 'parent_with_stroller'
  | 'visually_impaired'
  | 'organization';

export type UserRole = 'user' | 'admin' | 'organization';
export type Language = 'mn' | 'en';

export interface IUser extends Document {
  _id: Types.ObjectId;
  fullName: string;
  email: string;
  phone?: string;
  passwordHash: string;
  role: UserRole;
  userType: UserType;
  district?: string;
  preferredLanguage: Language;
  isEmailVerified: boolean;
  refreshTokenHashes: string[];
  passwordResetTokenHash?: string | null;
  passwordResetExpiresAt?: Date | null;
  lastLoginAt?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

const UserSchema = new Schema<IUser>(
  {
    fullName: { type: String, required: true, trim: true },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    phone: { type: String, trim: true },
    passwordHash: { type: String, required: true, select: false },
    role: {
      type: String,
      enum: ['user', 'admin', 'organization'],
      default: 'user',
    },
    userType: {
      type: String,
      enum: [
        'general',
        'elderly',
        'wheelchair',
        'parent_with_stroller',
        'visually_impaired',
        'organization',
      ],
      required: true,
    },
    district: { type: String, trim: true },
    preferredLanguage: {
      type: String,
      enum: ['mn', 'en'],
      default: 'mn',
    },
    isEmailVerified: { type: Boolean, default: false },
    refreshTokenHashes: { type: [String], default: [], select: false },
    passwordResetTokenHash: { type: String, default: null, select: false },
    passwordResetExpiresAt: { type: Date, default: null, select: false },
    lastLoginAt: { type: Date, default: null },
  },
  {
    timestamps: true,
    toJSON: {
      transform: (_doc, ret) => {
        delete ret.passwordHash;
        delete ret.refreshTokenHashes;
        delete ret.passwordResetTokenHash;
        delete ret.passwordResetExpiresAt;
        return ret;
      },
    },
  }
);

export const User = model<IUser>('User', UserSchema);
