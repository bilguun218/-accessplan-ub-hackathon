import { Request, Response } from 'express';
import {
  registerSchema,
  loginWithTypeSchema,
  refreshSchema,
  logoutSchema,
  forgotPasswordSchema,
  resetPasswordSchema,
} from '../validators/auth.validators';
import * as authService from '../services/auth.service';
import { ApiError } from '../utils/ApiError';

export async function register(req: Request, res: Response) {
  const data = registerSchema.parse(req.body);
  const result = await authService.registerUser(data);
  res.status(201).json(result);
}

export async function login(req: Request, res: Response) {
  const data = loginWithTypeSchema.parse(req.body);
  const result = await authService.loginUser(
    data.email,
    data.password,
    data.userType
  );
  res.json(result);
}

export async function refresh(req: Request, res: Response) {
  const data = refreshSchema.parse(req.body);
  const result = await authService.refreshAccessToken(data.refreshToken);
  res.json(result);
}

export async function logout(req: Request, res: Response) {
  const data = logoutSchema.parse(req.body);
  await authService.logoutUser(data.refreshToken);
  res.json({ message: 'Logged out successfully' });
}

export async function forgotPassword(req: Request, res: Response) {
  const data = forgotPasswordSchema.parse(req.body);
  await authService.forgotPassword(data.email);
  res.json({
    message: 'If this email exists, reset instructions have been sent.',
  });
}

export async function resetPassword(req: Request, res: Response) {
  const data = resetPasswordSchema.parse(req.body);
  await authService.resetPassword(data.token, data.newPassword);
  res.json({ message: 'Password reset successfully' });
}

export async function me(req: Request, res: Response) {
  if (!req.user) throw ApiError.unauthorized();
  const user = await authService.getMe(req.user.id);
  res.json({ user });
}
