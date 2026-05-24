import request from 'supertest';
import jwt from 'jsonwebtoken';
import { createApp } from '../src/app';
import { Repository, Scan } from '../src/models';

jest.mock('../src/models', () => ({
  Repository: {
    findAll: jest.fn(),
    findByPk: jest.fn(),
    create: jest.fn(),
  },
  Scan: {
    findAll: jest.fn(),
    findByPk: jest.fn(),
    create: jest.fn(),
  },
  ScanResult: {},
  sequelize: {},
}));

const app = createApp();

const validToken = jwt.sign({ id: 'user-1', username: 'testuser', role: 'viewer' }, 'dev-secret');
const authHeader = `Bearer ${validToken}`;

const mockRepo = {
  id: 'repo-uuid-1',
  githubId: 42,
  owner: 'acme',
  name: 'widget',
  fullName: 'acme/widget',
  isPrivate: false,
};

const mockScan = {
  id: 'scan-uuid-1',
  repositoryId: 'repo-uuid-1',
  status: 'running',
  triggeredBy: null,
  startedAt: null,
  completedAt: null,
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
};

beforeEach(() => {
  jest.clearAllMocks();
});

describe('POST /api/v1/repositories/:id/scans', () => {
  it('creates a scan with status running and returns 201', async () => {
    (Repository.findByPk as jest.Mock).mockResolvedValue(mockRepo);
    (Scan.create as jest.Mock).mockResolvedValue(mockScan);

    const res = await request(app)
      .post('/api/v1/repositories/repo-uuid-1/scans')
      .set('Authorization', authHeader);

    expect(res.status).toBe(201);
    expect(res.body.data.status).toBe('running');
    expect(res.body.data.repositoryId).toBe('repo-uuid-1');
    expect(Scan.create).toHaveBeenCalledWith(
      expect.objectContaining({ repositoryId: 'repo-uuid-1', status: 'running' })
    );
  });

  it('returns 404 when repository not found', async () => {
    (Repository.findByPk as jest.Mock).mockResolvedValue(null);

    const res = await request(app)
      .post('/api/v1/repositories/nonexistent/scans')
      .set('Authorization', authHeader);

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
    expect(Scan.create).not.toHaveBeenCalled();
  });

  it('returns 500 on database error', async () => {
    (Repository.findByPk as jest.Mock).mockRejectedValue(new Error('DB error'));

    const res = await request(app)
      .post('/api/v1/repositories/repo-uuid-1/scans')
      .set('Authorization', authHeader);

    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('INTERNAL_ERROR');
  });
});

describe('GET /api/v1/repositories/:id/scans', () => {
  it('returns list of scans for a repository', async () => {
    (Scan.findAll as jest.Mock).mockResolvedValue([mockScan]);

    const res = await request(app)
      .get('/api/v1/repositories/repo-uuid-1/scans')
      .set('Authorization', authHeader);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].repositoryId).toBe('repo-uuid-1');
    expect(Scan.findAll).toHaveBeenCalledWith(
      expect.objectContaining({ where: { repositoryId: 'repo-uuid-1' } })
    );
  });

  it('returns empty array when no scans', async () => {
    (Scan.findAll as jest.Mock).mockResolvedValue([]);

    const res = await request(app)
      .get('/api/v1/repositories/repo-uuid-1/scans')
      .set('Authorization', authHeader);

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });

  it('returns 500 on database error', async () => {
    (Scan.findAll as jest.Mock).mockRejectedValue(new Error('DB error'));

    const res = await request(app)
      .get('/api/v1/repositories/repo-uuid-1/scans')
      .set('Authorization', authHeader);

    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('INTERNAL_ERROR');
  });
});

describe('GET /api/v1/scans/:id', () => {
  it('returns scan with results', async () => {
    const scanWithResults = { ...mockScan, results: [] };
    (Scan.findByPk as jest.Mock).mockResolvedValue(scanWithResults);

    const res = await request(app).get('/api/v1/scans/scan-uuid-1').set('Authorization', authHeader);

    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe('scan-uuid-1');
    expect(res.body.data.results).toEqual([]);
  });

  it('returns 404 when scan not found', async () => {
    (Scan.findByPk as jest.Mock).mockResolvedValue(null);

    const res = await request(app).get('/api/v1/scans/nonexistent').set('Authorization', authHeader);

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('returns 500 on database error', async () => {
    (Scan.findByPk as jest.Mock).mockRejectedValue(new Error('DB error'));

    const res = await request(app).get('/api/v1/scans/scan-uuid-1').set('Authorization', authHeader);

    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('INTERNAL_ERROR');
  });
});
