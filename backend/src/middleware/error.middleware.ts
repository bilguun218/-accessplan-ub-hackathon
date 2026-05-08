import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { ApiError } from '../utils/ApiError';

export function notFoundHandler(req: Request, res: Response) {
  res.status(404).json({ error: { message: 'Route not found', code: 'NOT_FOUND' } });
}

export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
) {
  if (err instanceof ZodError) {
    return res.status(400).json({
      error: {
        message: 'Validation error',
        code: 'VALIDATION_ERROR',
        details: err.flatten(),
      },
    });
  }
  if (err instanceof ApiError) {
    return res.status(err.status).json({
      error: { message: err.message, code: err.code, details: err.details },
    });
  }
  console.error('[error]', err);
  return res.status(500).json({
    error: { message: 'Сервертэй холбогдоход алдаа гарлаа.', code: 'INTERNAL' },
  });
}
