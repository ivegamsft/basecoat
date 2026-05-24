import { Response, NextFunction } from 'express';
import { AppError } from '@utils/errors';
import logger from '@config/logger';
import { AuthRequest } from './request.middleware';

export interface ErrorResponse {
  code: string;
  message: string;
  details?: Record<string, unknown>;
  timestamp: string;
  requestId: string;
}

export const errorHandler = (
  error: Error | AppError,
  req: AuthRequest,
  res: Response,
  next: NextFunction,
) => {
  const timestamp = new Date().toISOString();
  const requestId = req.requestId ?? 'unknown';

  if (error instanceof AppError) {
    logger.warn('Application error', {
      requestId,
      code: error.code,
      statusCode: error.statusCode,
      message: error.message,
      details: error.details,
    });

    const response: ErrorResponse = {
      code: error.code,
      message: error.message,
      timestamp,
      requestId,
    };

    if (error.details) {
      response.details = error.details;
    }

    return res.status(error.statusCode).json(response);
  }

  // Unexpected errors
  logger.error('Unexpected error', {
    requestId,
    name: error.name,
    message: error.message,
    stack: error.stack,
  });

  const response: ErrorResponse = {
    code: 'INTERNAL_SERVER_ERROR',
    message: 'An unexpected error occurred',
    timestamp,
    requestId,
  };

  if (process.env.NODE_ENV === 'development') {
    response.details = {
      name: error.name,
      message: error.message,
      stack: error.stack,
    };
  }

  res.status(500).json(response);
};

export const notFoundHandler = (req: AuthRequest, res: Response) => {
  const response: ErrorResponse = {
    code: 'NOT_FOUND',
    message: `Route ${req.method} ${req.path} not found`,
    timestamp: new Date().toISOString(),
    requestId: req.requestId ?? 'unknown',
  };

  res.status(404).json(response);
};
