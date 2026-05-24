/**
 * Integration tests for the Portal backend API.
 *
 * Exercises the full HTTP request/response cycle using supertest against the
 * real Express app. Sequelize model methods are mocked — no real DB connection.
 *
 * A real JWT signed with 'dev-secret' is used to test auth middleware end-to-end.
 */

import request from 'supertest';
import jwt from 'jsonwebtoken';

// Mock passport before app import to avoid GitHub OAuth registration side-effects.
jest.mock('../src/config/passport', () => {
  const mockPassport = {
    initialize: jest.fn(() => (_req: unknown, _res: unknown, next: () => void) => next()),
    authenticate: jest.fn(
      () => (_req: unknown, res: { redirect: (url: string) => void }) => {
        res.redirect('https://github.com/login/oauth/authorize');
      }
    ),
  };
  return { __esModule: true, default: mockPassport };
});

// Mock all Sequelize model static methods — no real database calls.
jest.mock('../src/models', () => ({
  Repository: {
    findAll: jest.fn(),
    create: jest.fn(),
    findByPk: jest.fn(),
  },
  Scan: {
    create: jest.fn(),
    findAll: jest.fn(),
    findByPk: jest.fn(),
  },
  ScanResult: {
    findAll: jest.fn(),
  },
  AuditLog: {},
  User: {
    findOrCreate: jest.fn(),
  },
  sequelize: {},
}));

import { createApp } from '../src/app';
import { Repository, Scan } from '../src/models';

const JWT_SECRET = 'dev-secret';
const validToken = jwt.sign({ id: 'user-1', username: 'testuser', role: 'viewer' }, JWT_SECRET);
const authHeader = `Bearer ${validToken}`;

const app = createApp();

const mockRepo = {
  id: 'repo-uuid-1',
  githubId: 42,
  owner: 'acme',
  name: 'widget',
  fullName: 'acme/widget',
  isPrivate: false,
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
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

// 1. Health check
describe('GET /health', () => {
  it('returns 200 with { status: "ok" }', async () => {
    const res = await request(app).get('/health');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

// 2 & 3. Auth middleware on repositories list
describe('GET /api/v1/repositories — auth middleware', () => {
  it('returns 401 without Authorization header', async () => {
    const res = await request(app).get('/api/v1/repositories');

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('returns 200 with { data: [] } when authenticated with valid JWT', async () => {
    (Repository.findAll as jest.Mock).mockResolvedValue([]);

    const res = await request(app).get('/api/v1/repositories').set('Authorization', authHeader);

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
  });
});

// 4. Create repository
describe('POST /api/v1/repositories', () => {
  it('returns 201 with repo object when authenticated', async () => {
    (Repository.create as jest.Mock).mockResolvedValue(mockRepo);

    const res = await request(app)
      .post('/api/v1/repositories')
      .set('Authorization', authHeader)
      .send({ owner: 'acme', name: 'widget', githubId: 42 });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ owner: 'acme', name: 'widget', fullName: 'acme/widget' });
  });
});

// 5. Get repository by id
describe('GET /api/v1/repositories/:id', () => {
  it('returns 200 with the matching repository', async () => {
    (Repository.findByPk as jest.Mock).mockResolvedValue(mockRepo);

    const res = await request(app)
      .get('/api/v1/repositories/repo-uuid-1')
      .set('Authorization', authHeader);

    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe('repo-uuid-1');
  });

  it('returns 404 for an unknown repository id', async () => {
    (Repository.findByPk as jest.Mock).mockResolvedValue(null);

    const res = await request(app)
      .get('/api/v1/repositories/nonexistent')
      .set('Authorization', authHeader);

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });
});

// 6. Create scan
describe('POST /api/v1/repositories/:id/scans', () => {
  it('returns 201 scan object when authenticated', async () => {
    (Repository.findByPk as jest.Mock).mockResolvedValue(mockRepo);
    (Scan.create as jest.Mock).mockResolvedValue(mockScan);

    const res = await request(app)
      .post('/api/v1/repositories/repo-uuid-1/scans')
      .set('Authorization', authHeader);

    expect(res.status).toBe(201);
    expect(res.body.data.status).toBe('running');
    expect(res.body.data.repositoryId).toBe('repo-uuid-1');
  });
});

// 7. Get scan by id
describe('GET /api/v1/scans/:id', () => {
  it('returns 200 with the scan when found', async () => {
    (Scan.findByPk as jest.Mock).mockResolvedValue({ ...mockScan, results: [] });

    const res = await request(app)
      .get('/api/v1/scans/scan-uuid-1')
      .set('Authorization', authHeader);

    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe('scan-uuid-1');
  });

  it('returns 404 for an unknown scan id', async () => {
    (Scan.findByPk as jest.Mock).mockResolvedValue(null);

    const res = await request(app)
      .get('/api/v1/scans/nonexistent')
      .set('Authorization', authHeader);

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });
});

// 8 & 9. Auth middleware on /me
describe('GET /api/v1/me — auth middleware', () => {
  it('returns 401 without Authorization header', async () => {
    const res = await request(app).get('/api/v1/me');

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('returns 200 with decoded JWT payload when authenticated', async () => {
    const res = await request(app).get('/api/v1/me').set('Authorization', authHeader);

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      id: 'user-1',
      username: 'testuser',
      role: 'viewer',
    });
  });
});

// 10. Logout
describe('POST /auth/logout', () => {
  it('returns 200', async () => {
    const res = await request(app).post('/auth/logout');

    expect(res.status).toBe(200);
    expect(res.body.data.message).toBe('Logged out successfully');
  });
});
