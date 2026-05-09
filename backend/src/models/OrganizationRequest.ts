import { Schema, model, Document } from 'mongoose';

export type OrganizationVerificationMethod = 'emongolia' | 'document';
export type OrganizationRequestStatus = 'pending' | 'approved' | 'rejected';

export interface IOrganizationRequest extends Document {
  organizationName: string;
  activityType: string;
  registrationNumber: string;
  location: string;
  contactPerson: string;
  phone: string;
  email: string;
  description?: string;
  verificationMethod: OrganizationVerificationMethod;
  status: OrganizationRequestStatus;
  reviewedAt?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

const OrganizationRequestSchema = new Schema<IOrganizationRequest>(
  {
    organizationName: { type: String, required: true, trim: true },
    activityType: { type: String, required: true, trim: true },
    registrationNumber: { type: String, required: true, trim: true, index: true },
    location: { type: String, required: true, trim: true },
    contactPerson: { type: String, required: true, trim: true },
    phone: { type: String, required: true, trim: true },
    email: { type: String, required: true, lowercase: true, trim: true },
    description: { type: String, trim: true },
    verificationMethod: {
      type: String,
      enum: ['emongolia', 'document'],
      default: 'emongolia',
    },
    status: {
      type: String,
      enum: ['pending', 'approved', 'rejected'],
      default: 'pending',
      index: true,
    },
    reviewedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

export const OrganizationRequest = model<IOrganizationRequest>(
  'OrganizationRequest',
  OrganizationRequestSchema
);
