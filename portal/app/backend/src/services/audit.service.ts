import { AppDataSource } from '@config/database';
import { Audit, AuditStatus, AuditType } from '@models/audit.entity';
import { User } from '@models/user.entity';
import { Repository } from '@models/repository.entity';
import { Finding, FindingStatus, Severity } from '@models/finding.entity';
import { DatabaseError, NotFoundError, ValidationError } from '@utils/errors';
import logger from '@config/logger';

export class AuditService {
  private auditRepository = AppDataSource.getRepository(Audit);
  private userRepository = AppDataSource.getRepository(User);
  private repositoryRepository = AppDataSource.getRepository(Repository);
  private findingRepository = AppDataSource.getRepository(Finding);

  async createAudit(data: {
    repositoryId: string;
    createdById: string;
    type: AuditType;
    metadata?: Record<string, unknown>;
  }) {
    try {
      const repository = await this.repositoryRepository.findOne({
        where: { id: data.repositoryId },
      });

      if (!repository) {
        throw new NotFoundError('Repository', data.repositoryId);
      }

      const user = await this.userRepository.findOne({
        where: { id: data.createdById },
      });

      if (!user) {
        throw new NotFoundError('User', data.createdById);
      }

      const audit = this.auditRepository.create({
        repositoryId: data.repositoryId,
        createdById: data.createdById,
        type: data.type,
        status: AuditStatus.PENDING,
        metadata: data.metadata || {},
      });

      const saved = await this.auditRepository.save(audit);

      logger.info('Audit created', {
        auditId: saved.id,
        repositoryId: saved.repositoryId,
        type: saved.type,
      });

      return saved;
    } catch (error) {
      logger.error('Error creating audit', {
        error: error instanceof Error ? error.message : 'Unknown error',
        data,
      });

      if (error instanceof NotFoundError || error instanceof ValidationError) {
        throw error;
      }

      throw new DatabaseError('Failed to create audit');
    }
  }

  async getAudit(id: string) {
    const audit = await this.auditRepository.findOne({
      where: { id },
      relations: ['repository', 'createdBy', 'findings'],
    });

    if (!audit) {
      throw new NotFoundError('Audit', id);
    }

    return audit;
  }

  async listAudits(options: {
    repositoryId?: string;
    status?: string;
    type?: string;
    limit?: number;
    offset?: number;
  }) {
    try {
      const limit = Math.min(options.limit || 20, 100);
      const offset = options.offset || 0;

      const query = this.auditRepository
        .createQueryBuilder('audit')
        .leftJoinAndSelect('audit.repository', 'repository')
        .leftJoinAndSelect('audit.createdBy', 'createdBy')
        .leftJoinAndSelect('audit.findings', 'findings');

      if (options.repositoryId) {
        query.andWhere('audit.repositoryId = :repositoryId', {
          repositoryId: options.repositoryId,
        });
      }

      if (options.status) {
        query.andWhere('audit.status = :status', { status: options.status });
      }

      if (options.type) {
        query.andWhere('audit.type = :type', { type: options.type });
      }

      query.orderBy('audit.createdAt', 'DESC').skip(offset).take(limit);

      const [audits, total] = await query.getManyAndCount();

      return {
        items: audits,
        pagination: {
          total,
          limit,
          offset,
          hasMore: offset + limit < total,
        },
      };
    } catch (error) {
      logger.error('Error listing audits', {
        error: error instanceof Error ? error.message : 'Unknown error',
        options,
      });
      throw new DatabaseError('Failed to list audits');
    }
  }

  async updateAuditStatus(id: string, status: AuditStatus) {
    try {
      const audit = await this.getAudit(id);

      audit.status = status;
      if (status === AuditStatus.COMPLETED) {
        audit.completedAt = new Date();
      }

      const updated = await this.auditRepository.save(audit);

      logger.info('Audit status updated', { auditId: id, status });

      return updated;
    } catch (error) {
      logger.error('Error updating audit status', {
        error: error instanceof Error ? error.message : 'Unknown error',
        id,
        status,
      });

      if (error instanceof NotFoundError) {
        throw error;
      }

      throw new DatabaseError('Failed to update audit');
    }
  }

  async addFinding(auditId: string, data: {
    severity: Severity;
    category: string;
    description: string;
    remediation?: string;
    reference?: string;
  }) {
    try {
      const audit = await this.getAudit(auditId);

      const finding = this.findingRepository.create({
        auditId,
        severity: data.severity,
        category: data.category,
        description: data.description,
        remediation: data.remediation,
        reference: data.reference,
        status: FindingStatus.OPEN,
      });

      const saved = await this.findingRepository.save(finding);

      logger.info('Finding added to audit', {
        findingId: saved.id,
        auditId,
        severity: saved.severity,
      });

      return saved;
    } catch (error) {
      logger.error('Error adding finding', {
        error: error instanceof Error ? error.message : 'Unknown error',
        auditId,
      });

      if (error instanceof NotFoundError) {
        throw error;
      }

      throw new DatabaseError('Failed to add finding');
    }
  }

  async deleteAudit(id: string) {
    try {
      const audit = await this.getAudit(id);

      await this.auditRepository.remove(audit);

      logger.info('Audit deleted', { auditId: id });

      return { id, deleted: true };
    } catch (error) {
      logger.error('Error deleting audit', {
        error: error instanceof Error ? error.message : 'Unknown error',
        id,
      });

      if (error instanceof NotFoundError) {
        throw error;
      }

      throw new DatabaseError('Failed to delete audit');
    }
  }
}
