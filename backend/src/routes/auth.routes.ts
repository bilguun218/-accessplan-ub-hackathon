import { Router } from 'express';
import * as ctrl from '../controllers/auth.controller';
import { asyncHandler } from '../utils/asyncHandler';
import { requireAuth } from '../middleware/auth.middleware';
import { loginLimiter, forgotPasswordLimiter } from '../middleware/rateLimit.middleware';

const router = Router();

router.post('/register', asyncHandler(ctrl.register));
router.post('/login', loginLimiter, asyncHandler(ctrl.login));
router.post('/refresh', asyncHandler(ctrl.refresh));
router.post('/logout', asyncHandler(ctrl.logout));
router.post('/forgot-password', forgotPasswordLimiter, asyncHandler(ctrl.forgotPassword));
router.post('/reset-password', asyncHandler(ctrl.resetPassword));
router.get('/me', requireAuth, asyncHandler(ctrl.me));

export default router;
