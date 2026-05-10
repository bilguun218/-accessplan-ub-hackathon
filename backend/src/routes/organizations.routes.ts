import { Router } from 'express';
import * as ctrl from '../controllers/organization.controller';
import { requireAuth } from '../middleware/auth.middleware';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.post('/requests', asyncHandler(ctrl.submitOrganizationRequest));
router.post('/', requireAuth, asyncHandler(ctrl.createOrganization));
router.get('/me', requireAuth, asyncHandler(ctrl.getMyOrganization));
router.get('/', asyncHandler(ctrl.listOrganizations));
router.get('/nearby', asyncHandler(ctrl.listNearbyOrganizations));
router.post(
  '/:organizationId/posts',
  requireAuth,
  asyncHandler(ctrl.createOrganizationPost)
);
router.get(
  '/:organizationId/posts',
  requireAuth,
  asyncHandler(ctrl.listOrganizationPosts)
);
router.get('/:id', asyncHandler(ctrl.getOrganizationById));
router.put('/:id', requireAuth, asyncHandler(ctrl.updateOrganization));

export default router;
