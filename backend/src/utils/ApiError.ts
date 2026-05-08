export class ApiError extends Error {
  status: number;
  code?: string;
  details?: unknown;

  constructor(status: number, message: string, code?: string, details?: unknown) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }

  static badRequest(msg: string, code?: string, details?: unknown) {
    return new ApiError(400, msg, code, details);
  }
  static unauthorized(msg = 'Unauthorized', code?: string) {
    return new ApiError(401, msg, code);
  }
  static forbidden(msg = 'Forbidden', code?: string) {
    return new ApiError(403, msg, code);
  }
  static notFound(msg = 'Not found', code?: string) {
    return new ApiError(404, msg, code);
  }
  static conflict(msg: string, code?: string) {
    return new ApiError(409, msg, code);
  }
}
