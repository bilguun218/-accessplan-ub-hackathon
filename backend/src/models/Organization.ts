import { Schema, model, Document, Types } from 'mongoose';

export type OrganizationStatus = 'active' | 'pending' | 'rejected' | 'suspended';

export interface IOrganization extends Document {
  _id: Types.ObjectId;
  ownerUserId: Types.ObjectId;
  businessName: string;
  branchName?: string;
  serviceType: string;
  description?: string;
  address: string;
  location: {
    type: 'Point';
    coordinates: [number, number];
  };
  phone?: string;
  email?: string;
  website?: string;
  workingHours?: unknown;
  parkingAvailable: boolean;
  accessibilityAvailable: boolean;
  digitalServicesAvailable: boolean;
  isVerified: boolean;
  status: OrganizationStatus;
  createdAt: Date;
  updatedAt: Date;
}

const OrganizationSchema = new Schema<IOrganization>(
  {
    ownerUserId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    businessName: { type: String, required: true, trim: true },
    branchName: { type: String, trim: true },
    serviceType: { type: String, required: true, trim: true, index: true },
    description: { type: String, trim: true },
    address: { type: String, required: true, trim: true },
    location: {
      type: {
        type: String,
        enum: ['Point'],
        required: true,
        default: 'Point',
      },
      coordinates: {
        type: [Number],
        required: true,
        validate: {
          validator(value: number[]) {
            return (
              value.length === 2 &&
              value[0] >= -180 &&
              value[0] <= 180 &&
              value[1] >= -90 &&
              value[1] <= 90
            );
          },
          message: 'Invalid coordinates.',
        },
      },
    },
    phone: { type: String, trim: true },
    email: { type: String, lowercase: true, trim: true },
    website: { type: String, trim: true },
    workingHours: { type: Schema.Types.Mixed },
    parkingAvailable: { type: Boolean, default: false },
    accessibilityAvailable: { type: Boolean, default: false },
    digitalServicesAvailable: { type: Boolean, default: false },
    isVerified: { type: Boolean, default: false },
    status: {
      type: String,
      enum: ['active', 'pending', 'rejected', 'suspended'],
      default: 'active',
      index: true,
    },
  },
  { timestamps: true }
);

OrganizationSchema.index({ location: '2dsphere' });

export const Organization = model<IOrganization>(
  'Organization',
  OrganizationSchema
);
