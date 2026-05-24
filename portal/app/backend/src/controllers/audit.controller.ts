import { Response, NextFunction } from 'express';
import Joi from 'joi';
import { AuditService } from '@services/audit.service';
import { AuthRequest } from '@middleware/request.middleware';
import { AuditStatus, AuditType } from '@models/audit.entity';
import { Severity } from '@models/finding.entity';
import { ValidationError } from '@utils/errors';

export class AuditController {
  private auditService = new AuditService();

  async createAudit(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const schema = Joi.object({
        repositoryId: Joi.string().uuid().required(),
        type: Joi.string()
          .valid('security', 'compliance', 'code-quality', 'dependency')
          .required(),
        metadata: Joi.object().optional(),
      });

      const { error, value } = schema.validate(req.body);

      if (error) {
        return next(new ValidationError(error.message, { details: error.details }));
      }

      const audit = await this.auditService.createAudit({
        repositoryId: value.repositoryId,
        createdById: req.userId!,
        type: value.type as AuditType,
        metadata: value.metadata,
      });

      res.status(201).json({
        success: true,
        data: audit,
      });
    } catch (error) {
      next(error);
    }
  }

  async getAudit(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;

      const audit = await this.auditService.getAudit(id);

      res.json({
        success: true,
        data: audit,
      });
    } catch (error) {
      next(error);
    }
  }

  async listAudits(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const schema = Joi.object({
        repositoryId: Joi.string().uuid().optional(),
        status: Joi.string()
          .valid('pending', 'in_progress', 'completed', 'failed')
          .optional(),
        type: Joi.string()
          .valid('security', 'compliance', 'code-quality', 'dependency')
          .optional(),
        limit: Joi.number().min(1).max(100).optional(),
        offset: Joi.number().min(0).optional(),
      });

      const { error, value } = schema.validate(req.query);

      if (error) {
        return next(new ValidationError(error.message, { details: error.details }));
      }

      const result = await this.auditService.listAudits({
        repositoryId: value.repositoryId,
        status: value.status,
        type: value.type,
        limit: value.limit,
        offset: value.offset,
      });

      res.json({
        success: true,
        ...result,
      });
    } catch (error) {
      next(error);
    }
  }

  async updateAuditStatus(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const schema = Joi.object({
        status: Joi.string()
          .valid('pending', 'in_progress', 'completed', 'failed')
          .required(),
      });

      const { error, value } = schema.validate(req.body);

      if (error) {
        return next(new ValidationError(error.message, { details: error.details }));
      }

      const audit = await this.auditService.updateAuditStatus(id, value.status as AuditStatus);

      res.json({
        success: true,
        data: audit,
      });
    } catch (error) {
      next(error);
    }
  }

  async addFinding(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const schema = Joi.object({
        severity: Joi.string()
          .valid('critical', 'high', 'medium', 'low', 'info')
          .required(),
        category: Joi.string().required(),
        description: Joi.string().required(),
        remediation: Joi.string().optional(),
        reference: Joi.string().optional(),
      });

      const { error, value } = schema.validate(req.body);

      if (error) {
        return next(new ValidationError(error.message, { details: error.details }));
      }

      const finding = await this.auditService.addFinding(id, {
        ...value,
        severity: value.severity as Severity,
      });

      res.status(201).json({
        success: true,
        data: finding,
      });
    } catch (error) {
      next(error);
    }
  }

  async deleteAudit(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;

      const result = await this.auditService.deleteAudit(id);

      res.json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }
}
