import { Router } from 'express';
import * as ctrl from '../controllers/organization.controller';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.post('/requests', asyncHandler(ctrl.submitOrganizationRequest));

export default router;
