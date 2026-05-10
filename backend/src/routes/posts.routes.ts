import { Router } from 'express';
import * as ctrl from '../controllers/organization.controller';
import { requireAuth } from '../middleware/auth.middleware';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.get('/:id', asyncHandler(ctrl.getPostById));
router.put('/:id', requireAuth, asyncHandler(ctrl.updatePost));

export default router;
