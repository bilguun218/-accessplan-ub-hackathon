import { Router } from 'express';
import * as ctrl from '../controllers/progress.controller';
import { requireAuth } from '../middleware/auth.middleware';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.use(requireAuth);

router.get('/', asyncHandler(ctrl.getProgress));
router.post('/saved-tasks', asyncHandler(ctrl.saveTask));
router.delete('/saved-tasks/:taskId', asyncHandler(ctrl.removeSavedTask));
router.post('/completed-tasks', asyncHandler(ctrl.completeTask));
router.delete('/completed-tasks/:taskId', asyncHandler(ctrl.uncompleteTask));
router.post('/rewards/:rewardId/claim', asyncHandler(ctrl.claimReward));

export default router;
