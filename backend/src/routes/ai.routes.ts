import { Router } from 'express';
import * as ctrl from '../controllers/ai.controller';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.post('/parse-tasks', asyncHandler(ctrl.parseTasks));

export default router;
