import { Request, Response } from 'express';
import { OrganizationRequest } from '../models/OrganizationRequest';
import { organizationRequestSchema } from '../validators/organization.validators';

export async function submitOrganizationRequest(req: Request, res: Response) {
  const data = organizationRequestSchema.parse(req.body);

  const request = await OrganizationRequest.create({
    organizationName: data.organizationName,
    activityType: data.activityType,
    registrationNumber: data.registrationNumber,
    location: data.location,
    contactPerson: data.contactPerson,
    phone: data.phone,
    email: data.email.toLowerCase(),
    description: data.description || undefined,
    verificationMethod: data.verificationMethod,
  });

  res.status(201).json({
    request: {
      id: request._id,
      status: request.status,
      organizationName: request.organizationName,
      createdAt: request.createdAt,
    },
  });
}
