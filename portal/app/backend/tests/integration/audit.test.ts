import request from 'supertest';
import { AppDataSource } from '@config/database';
import App from '@config/app';
import { User, UserRole } from '@models/user.entity';
import { Repository as RepositoryEntity } from '@models/repository.entity';
import { Team } from '@models/team.entity';
import jwt from 'jsonwebtoken';

describe('Audit API Integration Tests', () => {
  let app: App;
  let server: any;
  let testUser: User;
  let testTeam: Team;
  let testRepository: RepositoryEntity;
  let authToken: string;

  beforeAll(async () => {
    app = new App();
    server = app.getExpressApp();

    // Create test data
    const userRepository = AppDataSource.getRepository(User);
    const teamRepository = AppDataSource.getRepository(Team);
    const repositoryRepository = AppDataSource.getRepository(RepositoryEntity);

    testTeam = teamRepository.create({
      name: 'Test Team',
      description: 'Test team for audits',
    });
    await teamRepository.save(testTeam);

    testUser = userRepository.create({
      email: 'test@example.com',
      name: 'Test User',
      passwordHash: 'hashed_password',
      role: UserRole.AUDITOR,
    });
    await userRepository.save(testUser);

    testRepository = repositoryRepository.create({
      name: 'test-repo',
      url: 'https://github.com/test/test-repo',
      teamId: testTeam.id,
      isPrivate: false,
    });
    await repositoryRepository.save(testRepository);

    // Generate auth token
    authToken = jwt.sign(
      {
        userId: testUser.id,
        email: testUser.email,
        role: testUser.role,
      },
      process.env.JWT_SECRET || 'secret',
      { expiresIn: '1h' },
    );
  });

  describe('POST /api/v1/audits', () => {
    it('should create a new audit', async () => {
      const response = await request(server)
        .post('/api/v1/audits')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          repositoryId: testRepository.id,
          type: 'security',
          metadata: { tool: 'SAST', version: '1.0' },
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('id');
      expect(response.body.data.status).toBe('pending');
      expect(response.body.data.type).toBe('security');
    });

    it('should fail without authentication', async () => {
      const response = await request(server)
        .post('/api/v1/audits')
        .send({
          repositoryId: testRepository.id,
          type: 'security',
        });

      expect(response.status).toBe(401);
    });

    it('should validate required fields', async () => {
      const response = await request(server)
        .post('/api/v1/audits')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          repositoryId: testRepository.id,
          // missing type
        });

      expect(response.status).toBe(400);
      expect(response.body.code).toBe('VALIDATION_ERROR');
    });
  });

  describe('GET /api/v1/audits/:id', () => {
    let createdAuditId: string;

    beforeEach(async () => {
      const response = await request(server)
        .post('/api/v1/audits')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          repositoryId: testRepository.id,
          type: 'compliance',
        });

      createdAuditId = response.body.data.id;
    });

    it('should retrieve an audit by ID', async () => {
      const response = await request(server)
        .get(`/api/v1/audits/${createdAuditId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.id).toBe(createdAuditId);
      expect(response.body.data.type).toBe('compliance');
    });

    it('should return 404 for non-existent audit', async () => {
      const response = await request(server)
        .get(`/api/v1/audits/00000000-0000-0000-0000-000000000000`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(404);
      expect(response.body.code).toBe('NOT_FOUND');
    });
  });

  describe('GET /api/v1/audits', () => {
    beforeEach(async () => {
      for (let i = 0; i < 5; i++) {
        await request(server)
          .post('/api/v1/audits')
          .set('Authorization', `Bearer ${authToken}`)
          .send({
            repositoryId: testRepository.id,
            type: i % 2 === 0 ? 'security' : 'compliance',
          });
      }
    });

    it('should list audits with pagination', async () => {
      const response = await request(server)
        .get('/api/v1/audits?limit=10&offset=0')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(Array.isArray(response.body.items)).toBe(true);
      expect(response.body.pagination).toHaveProperty('total');
      expect(response.body.pagination).toHaveProperty('limit');
      expect(response.body.pagination).toHaveProperty('offset');
      expect(response.body.pagination).toHaveProperty('hasMore');
    });

    it('should filter audits by type', async () => {
      const response = await request(server)
        .get('/api/v1/audits?type=security')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.items.every((audit: any) => audit.type === 'security')).toBe(true);
    });
  });

  describe('PATCH /api/v1/audits/:id/status', () => {
    let createdAuditId: string;

    beforeEach(async () => {
      const response = await request(server)
        .post('/api/v1/audits')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          repositoryId: testRepository.id,
          type: 'security',
        });

      createdAuditId = response.body.data.id;
    });

    it('should update audit status', async () => {
      const response = await request(server)
        .patch(`/api/v1/audits/${createdAuditId}/status`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          status: 'in_progress',
        });

      expect(response.status).toBe(200);
      expect(response.body.data.status).toBe('in_progress');
    });

    it('should mark audit as completed with timestamp', async () => {
      await request(server)
        .patch(`/api/v1/audits/${createdAuditId}/status`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({ status: 'in_progress' });

      const response = await request(server)
        .patch(`/api/v1/audits/${createdAuditId}/status`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({ status: 'completed' });

      expect(response.status).toBe(200);
      expect(response.body.data.status).toBe('completed');
      expect(response.body.data.completedAt).toBeDefined();
    });
  });

  describe('POST /api/v1/audits/:id/findings', () => {
    let createdAuditId: string;

    beforeEach(async () => {
      const response = await request(server)
        .post('/api/v1/audits')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          repositoryId: testRepository.id,
          type: 'security',
        });

      createdAuditId = response.body.data.id;
    });

    it('should add a finding to an audit', async () => {
      const response = await request(server)
        .post(`/api/v1/audits/${createdAuditId}/findings`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          severity: 'high',
          category: 'SQL Injection',
          description: 'Potential SQL injection vulnerability found',
          remediation: 'Use parameterized queries',
        });

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.data.severity).toBe('high');
      expect(response.body.data.status).toBe('open');
    });
  });

  describe('DELETE /api/v1/audits/:id', () => {
    let createdAuditId: string;

    beforeEach(async () => {
      const response = await request(server)
        .post('/api/v1/audits')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          repositoryId: testRepository.id,
          type: 'security',
        });

      createdAuditId = response.body.data.id;
    });

    it('should delete an audit', async () => {
      const response = await request(server)
        .delete(`/api/v1/audits/${createdAuditId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.deleted).toBe(true);
    });

    it('should require admin role to delete', async () => {
      // Create a non-admin user
      const userRepository = AppDataSource.getRepository(User);
      const viewerUser = userRepository.create({
        email: 'viewer@example.com',
        name: 'Viewer User',
        passwordHash: 'hashed_password',
        role: UserRole.VIEWER,
      });
      await userRepository.save(viewerUser);

      const viewerToken = jwt.sign(
        {
          userId: viewerUser.id,
          email: viewerUser.email,
          role: viewerUser.role,
        },
        process.env.JWT_SECRET || 'secret',
        { expiresIn: '1h' },
      );

      const response = await request(server)
        .delete(`/api/v1/audits/${createdAuditId}`)
        .set('Authorization', `Bearer ${viewerToken}`);

      expect(response.status).toBe(403);
    });
  });

  describe('Health Check', () => {
    it('should return healthy status', async () => {
      const response = await request(server)
        .get('/health');

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('OK');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('requestId');
    });
  });

  describe('Version Endpoint', () => {
    it('should return API version', async () => {
      const response = await request(server)
        .get('/api/v1/version');

      expect(response.status).toBe(200);
      expect(response.body.version).toBe('v1');
      expect(response.body).toHaveProperty('app');
    });
  });
});
