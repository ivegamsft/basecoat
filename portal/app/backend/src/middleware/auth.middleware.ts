import { Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { AuthRequest } from './request.middleware';
import { UnauthorizedError, ForbiddenError } from '@utils/errors';
import logger from '@config/logger';

export const authMiddleware = (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const token = extractToken(req);

    if (!token) {
      throw new UnauthorizedError('No token provided');
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'secret') as {
      userId: string;
      email: string;
      role: string;
    };

    req.userId = decoded.userId;
    req.user = {
      id: decoded.userId,
      email: decoded.email,
      role: decoded.role,
    };

    logger.debug('Token verified', { requestId: req.requestId, userId: req.userId });
    next();
  } catch (error) {
    logger.warn('Authentication failed', {
      requestId: req.requestId,
      error: error instanceof Error ? error.message : 'Unknown error',
    });
    next(new UnauthorizedError('Invalid or expired token'));
  }
};

export const requireRole = (...roles: string[]) => {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return next(new UnauthorizedError('User not authenticated'));
    }

    if (!roles.includes(req.user.role)) {
      logger.warn('Insufficient permissions', {
        requestId: req.requestId,
        userId: req.userId,
        requiredRoles: roles,
        userRole: req.user.role,
      });
      return next(new ForbiddenError('Insufficient permissions'));
    }

    next();
  };
};

export const optionalAuth = (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const token = extractToken(req);

    if (token) {
      const decoded = jwt.verify(token, process.env.JWT_SECRET || 'secret') as {
        userId: string;
        email: string;
        role: string;
      };

      req.userId = decoded.userId;
      req.user = {
        id: decoded.userId,
        email: decoded.email,
        role: decoded.role,
      };
    }
  } catch {
    // Optional auth, so we don't throw, just continue
  }

  next();
};

function extractToken(req: AuthRequest): string | null {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return null;
  }

  const parts = authHeader.split(' ');

  if (parts.length !== 2 || parts[0].toLowerCase() !== 'bearer') {
    return null;
  }

  return parts[1];
}
