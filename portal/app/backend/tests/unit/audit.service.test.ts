import { AuditService } from '@services/audit.service';
import { AppDataSource } from '@config/database';
import { NotFoundError, ValidationError } from '@utils/errors';
import { Audit, AuditStatus, AuditType } from '@models/audit.entity';
import { User, UserRole } from '@models/user.entity';
import { Repository as RepositoryEntity, ComplianceLevel } from '@models/repository.entity';
import { Team } from '@models/team.entity';

describe('AuditService', () => {
  let auditService: AuditService;
  let testUser: User;
  let testTeam: Team;
  let testRepository: RepositoryEntity;

  beforeAll(async () => {
    auditService = new AuditService();

    const userRepository = AppDataSource.getRepository(User);
    const teamRepository = AppDataSource.getRepository(Team);
    const repositoryRepository = AppDataSource.getRepository(RepositoryEntity);

    testTeam = teamRepository.create({
      name: 'Test Team',
    });
    await teamRepository.save(testTeam);

    testUser = userRepository.create({
      email: 'test@example.com',
      name: 'Test User',
      passwordHash: 'hashed',
      role: UserRole.AUDITOR,
    });
    await userRepository.save(testUser);

    testRepository = repositoryRepository.create({
      name: 'test-repo',
      url: 'https://github.com/test/repo',
      teamId: testTeam.id,
      complianceLevel: ComplianceLevel.LEVEL1,
    });
    await repositoryRepository.save(testRepository);
  });

  describe('createAudit', () => {
    it('should create an audit with valid data', async () => {
      const audit = await auditService.createAudit({
        repositoryId: testRepository.id,
        createdById: testUser.id,
        type: AuditType.SECURITY,
        metadata: { version: '1.0' },
      });

      expect(audit).toBeDefined();
      expect(audit.id).toBeDefined();
      expect(audit.status).toBe(AuditStatus.PENDING);
      expect(audit.type).toBe(AuditType.SECURITY);
    });

    it('should throw NotFoundError for non-existent repository', async () => {
      await expect(
        auditService.createAudit({
          repositoryId: '00000000-0000-0000-0000-000000000000',
          createdById: testUser.id,
          type: AuditType.SECURITY,
        }),
      ).rejects.toThrow(NotFoundError);
    });

    it('should throw NotFoundError for non-existent user', async () => {
      await expect(
        auditService.createAudit({
          repositoryId: testRepository.id,
          createdById: '00000000-0000-0000-0000-000000000000',
          type: AuditType.COMPLIANCE,
        }),
      ).rejects.toThrow(NotFoundError);
    });
  });

  describe('getAudit', () => {
    let createdAudit: Audit;

    beforeEach(async () => {
      createdAudit = await auditService.createAudit({
        repositoryId: testRepository.id,
        createdById: testUser.id,
        type: AuditType.SECURITY,
      });
    });

    it('should retrieve an audit by ID', async () => {
      const audit = await auditService.getAudit(createdAudit.id);

      expect(audit).toBeDefined();
      expect(audit.id).toBe(createdAudit.id);
      expect(audit.type).toBe(AuditType.SECURITY);
    });

    it('should throw NotFoundError for non-existent audit', async () => {
      await expect(
        auditService.getAudit('00000000-0000-0000-0000-000000000000'),
      ).rejects.toThrow(NotFoundError);
    });
  });

  describe('listAudits', () => {
    beforeEach(async () => {
      for (let i = 0; i < 3; i++) {
        await auditService.createAudit({
          repositoryId: testRepository.id,
          createdById: testUser.id,
          type: i % 2 === 0 ? AuditType.SECURITY : AuditType.COMPLIANCE,
        });
      }
    });

    it('should list audits with pagination', async () => {
      const result = await auditService.listAudits({
        limit: 10,
        offset: 0,
      });

      expect(result.items).toBeDefined();
      expect(Array.isArray(result.items)).toBe(true);
      expect(result.pagination).toBeDefined();
      expect(result.pagination.total).toBeGreaterThan(0);
    });

    it('should filter audits by type', async () => {
      const result = await auditService.listAudits({
        type: AuditType.SECURITY,
      });

      expect(result.items.every((a) => a.type === AuditType.SECURITY)).toBe(true);
    });

    it('should respect limit and offset', async () => {
      const result1 = await auditService.listAudits({
        limit: 2,
        offset: 0,
      });

      expect(result1.items.length).toBeLessThanOrEqual(2);
      expect(result1.pagination.limit).toBe(2);
    });
  });

  describe('updateAuditStatus', () => {
    let createdAudit: Audit;

    beforeEach(async () => {
      createdAudit = await auditService.createAudit({
        repositoryId: testRepository.id,
        createdById: testUser.id,
        type: AuditType.SECURITY,
      });
    });

    it('should update audit status', async () => {
      const updated = await auditService.updateAuditStatus(
        createdAudit.id,
        AuditStatus.IN_PROGRESS,
      );

      expect(updated.status).toBe(AuditStatus.IN_PROGRESS);
    });

    it('should set completedAt when marking complete', async () => {
      await auditService.updateAuditStatus(createdAudit.id, AuditStatus.IN_PROGRESS);

      const updated = await auditService.updateAuditStatus(
        createdAudit.id,
        AuditStatus.COMPLETED,
      );

      expect(updated.status).toBe(AuditStatus.COMPLETED);
      expect(updated.completedAt).toBeDefined();
    });
  });

  describe('deleteAudit', () => {
    let createdAudit: Audit;

    beforeEach(async () => {
      createdAudit = await auditService.createAudit({
        repositoryId: testRepository.id,
        createdById: testUser.id,
        type: AuditType.SECURITY,
      });
    });

    it('should delete an audit', async () => {
      const result = await auditService.deleteAudit(createdAudit.id);

      expect(result.deleted).toBe(true);
      expect(result.id).toBe(createdAudit.id);
    });

    it('should throw NotFoundError when deleting non-existent audit', async () => {
      await expect(
        auditService.deleteAudit('00000000-0000-0000-0000-000000000000'),
      ).rejects.toThrow(NotFoundError);
    });
  });
});
