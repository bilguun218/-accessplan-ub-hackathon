import { Router } from 'express';
import * as ctrl from '../controllers/maps.controller';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

router.get('/autocomplete', asyncHandler(ctrl.autocomplete));
router.get('/place-details', asyncHandler(ctrl.placeDetails));

export default router;
