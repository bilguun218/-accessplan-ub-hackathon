import { Request, Response } from 'express';
import { Types } from 'mongoose';
import { UserProgress, IUserProgress } from '../models/UserProgress';
import { ApiError } from '../utils/ApiError';

const maxStoredTasks = 100;

function requireUserId(req: Request): Types.ObjectId {
  const id = req.user?.id;
  if (!id || !Types.ObjectId.isValid(id)) {
    throw ApiError.unauthorized('Unauthorized', 'NO_USER');
  }
  return new Types.ObjectId(id);
}

async function getOrCreateProgress(userId: Types.ObjectId) {
  const existing = await UserProgress.findOne({ userId });
  if (existing) return existing;
  return UserProgress.create({ userId });
}

function normalizeTask(raw: unknown): Record<string, unknown> {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw ApiError.badRequest('Task payload is required.', 'TASK_REQUIRED');
  }

  const task = raw as Record<string, unknown>;
  const id = task.id?.toString().trim();
  if (!id) {
    throw ApiError.badRequest('Task id is required.', 'TASK_ID_REQUIRED');
  }

  return { ...task, id };
}

function taskIdOf(task: Record<string, unknown>) {
  const id = task.id;
  return id == null ? '' : String(id);
}

function dateFromBody(value: unknown, fallback = new Date()) {
  if (typeof value !== 'string') return fallback;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? fallback : parsed;
}

function trimSnapshots(progress: IUserProgress) {
  progress.savedTasks = progress.savedTasks.slice(0, maxStoredTasks);
  progress.completedTasks = progress.completedTasks.slice(0, maxStoredTasks);
}

function serializeProgress(progress: IUserProgress) {
  return {
    savedTasks: progress.savedTasks.map((item) => ({
      task: item.task,
      savedAt: item.savedAt,
    })),
    completedTasks: progress.completedTasks.map((item) => ({
      task: item.task,
      completedAt: item.completedAt,
    })),
    claimedRewardIds: progress.claimedRewardIds,
  };
}

export async function getProgress(req: Request, res: Response) {
  const userId = requireUserId(req);
  const progress = await getOrCreateProgress(userId);
  res.json({ progress: serializeProgress(progress) });
}

export async function saveTask(req: Request, res: Response) {
  const userId = requireUserId(req);
  const task = normalizeTask(req.body?.task);
  const savedAt = dateFromBody(req.body?.savedAt);
  const taskId = taskIdOf(task);
  const progress = await getOrCreateProgress(userId);

  progress.savedTasks = progress.savedTasks.filter(
    (item) => taskIdOf(item.task) !== taskId
  );
  progress.savedTasks.unshift({ task, savedAt });
  trimSnapshots(progress);
  await progress.save();

  res.json({ progress: serializeProgress(progress) });
}

export async function removeSavedTask(req: Request, res: Response) {
  const userId = requireUserId(req);
  const taskId = req.params.taskId?.trim();
  const progress = await getOrCreateProgress(userId);

  progress.savedTasks = progress.savedTasks.filter(
    (item) => taskIdOf(item.task) !== taskId
  );
  await progress.save();

  res.json({ progress: serializeProgress(progress) });
}

export async function completeTask(req: Request, res: Response) {
  const userId = requireUserId(req);
  const task = normalizeTask(req.body?.task);
  const completedAt = dateFromBody(req.body?.completedAt);
  const taskId = taskIdOf(task);
  const progress = await getOrCreateProgress(userId);

  progress.completedTasks = progress.completedTasks.filter(
    (item) => taskIdOf(item.task) !== taskId
  );
  progress.completedTasks.unshift({ task, completedAt });
  trimSnapshots(progress);
  await progress.save();

  res.json({ progress: serializeProgress(progress) });
}

export async function uncompleteTask(req: Request, res: Response) {
  const userId = requireUserId(req);
  const taskId = req.params.taskId?.trim();
  const progress = await getOrCreateProgress(userId);

  progress.completedTasks = progress.completedTasks.filter(
    (item) => taskIdOf(item.task) !== taskId
  );
  await progress.save();

  res.json({ progress: serializeProgress(progress) });
}

export async function claimReward(req: Request, res: Response) {
  const userId = requireUserId(req);
  const rewardId = req.params.rewardId?.trim();
  if (!rewardId) {
    throw ApiError.badRequest('Reward id is required.', 'REWARD_ID_REQUIRED');
  }

  const progress = await getOrCreateProgress(userId);
  if (!progress.claimedRewardIds.includes(rewardId)) {
    progress.claimedRewardIds.push(rewardId);
    await progress.save();
  }

  res.json({ progress: serializeProgress(progress) });
}
