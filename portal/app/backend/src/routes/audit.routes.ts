import { Router, Response } from 'express';
import { AuditController } from '@controllers/audit.controller';
import { authMiddleware, requireRole } from '@middleware/auth.middleware';
import { AuthRequest } from '@middleware/request.middleware';

const router = Router();
const auditController = new AuditController();

// POST /api/v1/audits - Create new audit
router.post(
  '/',
  authMiddleware,
  requireRole('admin', 'auditor'),
  (req: AuthRequest, res: Response, next) => auditController.createAudit(req, res, next),
);

// GET /api/v1/audits - List audits with pagination
router.get('/', authMiddleware, (req: AuthRequest, res: Response, next) =>
  auditController.listAudits(req, res, next),
);

// GET /api/v1/audits/:id - Get audit details
router.get('/:id', authMiddleware, (req: AuthRequest, res: Response, next) =>
  auditController.getAudit(req, res, next),
);

// PATCH /api/v1/audits/:id/status - Update audit status
router.patch(
  '/:id/status',
  authMiddleware,
  requireRole('admin', 'auditor'),
  (req: AuthRequest, res: Response, next) => auditController.updateAuditStatus(req, res, next),
);

// POST /api/v1/audits/:id/findings - Add finding to audit
router.post(
  '/:id/findings',
  authMiddleware,
  requireRole('admin', 'auditor'),
  (req: AuthRequest, res: Response, next) => auditController.addFinding(req, res, next),
);

// DELETE /api/v1/audits/:id - Delete audit
router.delete(
  '/:id',
  authMiddleware,
  requireRole('admin'),
  (req: AuthRequest, res: Response, next) => auditController.deleteAudit(req, res, next),
);

export default router;
