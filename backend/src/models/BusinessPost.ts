import { Schema, model, Document, Types } from 'mongoose';

export type BusinessPostType =
  | 'promotion'
  | 'announcement'
  | 'event'
  | 'discount'
  | 'service_update'
  | 'general';

export interface IBusinessPost extends Document {
  _id: Types.ObjectId;
  organizationId: Types.ObjectId;
  title: string;
  description: string;
  type: BusinessPostType;
  imageUrl?: string | null;
  startsAt?: Date | null;
  endsAt?: Date | null;
  isActive: boolean;
  showOnMap: boolean;
  isSponsored: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const BusinessPostSchema = new Schema<IBusinessPost>(
  {
    organizationId: {
      type: Schema.Types.ObjectId,
      ref: 'Organization',
      required: true,
      index: true,
    },
    title: { type: String, required: true, trim: true },
    description: { type: String, required: true, trim: true },
    type: {
      type: String,
      enum: [
        'promotion',
        'announcement',
        'event',
        'discount',
        'service_update',
        'general',
      ],
      default: 'promotion',
    },
    imageUrl: { type: String, trim: true, default: null },
    startsAt: { type: Date, default: null, index: true },
    endsAt: { type: Date, default: null, index: true },
    isActive: { type: Boolean, default: true, index: true },
    showOnMap: { type: Boolean, default: true, index: true },
    isSponsored: { type: Boolean, default: false },
  },
  { timestamps: true }
);

BusinessPostSchema.index({
  organizationId: 1,
  isActive: 1,
  showOnMap: 1,
  startsAt: 1,
  endsAt: 1,
});

export const BusinessPost = model<IBusinessPost>(
  'BusinessPost',
  BusinessPostSchema
);
