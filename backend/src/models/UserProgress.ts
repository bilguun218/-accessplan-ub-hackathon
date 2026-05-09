import { Schema, model, Document, Types } from 'mongoose';

export interface IUserTaskSnapshot {
  task: Record<string, unknown>;
  savedAt?: Date;
  completedAt?: Date;
}

export interface IUserProgress extends Document {
  userId: Types.ObjectId;
  savedTasks: IUserTaskSnapshot[];
  completedTasks: IUserTaskSnapshot[];
  claimedRewardIds: string[];
  createdAt: Date;
  updatedAt: Date;
}

const UserTaskSnapshotSchema = new Schema<IUserTaskSnapshot>(
  {
    task: { type: Schema.Types.Mixed, required: true },
    savedAt: { type: Date },
    completedAt: { type: Date },
  },
  { _id: false }
);

const UserProgressSchema = new Schema<IUserProgress>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },
    savedTasks: { type: [UserTaskSnapshotSchema], default: [] },
    completedTasks: { type: [UserTaskSnapshotSchema], default: [] },
    claimedRewardIds: { type: [String], default: [] },
  },
  { timestamps: true }
);

export const UserProgress = model<IUserProgress>(
  'UserProgress',
  UserProgressSchema
);
