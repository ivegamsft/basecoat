import request from 'supertest';
import jwt from 'jsonwebtoken';

// Mock the passport config before the app is imported so no real
// GitHub OAuth or database calls happen during unit tests.
jest.mock('../src/config/passport', () => {
  const isGitHubOAuthConfigured = jest.fn(() => true);
  const mockPassport = {
    initialize: jest.fn(
      () => (_req: unknown, _res: unknown, next: () => void) => next()
    ),
    authenticate: jest.fn(
      (strategy: string, options?: { session?: boolean }) => {
        if (strategy === 'github' && options?.session === false) {
          // Simulate a successful OAuth callback — sets req.user then continues.
          return (
            req: Record<string, unknown>,
            _res: unknown,
            next: () => void
          ) => {
            req.user = { id: 'user-123', username: 'testuser', role: 'viewer' };
            next();
          };
        }
        // Simulate the GitHub authorization redirect.
        return (_req: unknown, res: { redirect: (url: string) => void }) => {
          res.redirect(
            'https://github.com/login/oauth/authorize?client_id=test-client-id&scope=user%3Aemail'
          );
        };
      }
    ),
  };
  return { __esModule: true, default: mockPassport, isGitHubOAuthConfigured };
});

import { createApp } from '../src/app';
import { isGitHubOAuthConfigured } from '../src/config/passport';

const app = createApp();
const JWT_SECRET = 'dev-secret';
const mockGitHubOAuthConfigured = isGitHubOAuthConfigured as jest.MockedFunction<
  typeof isGitHubOAuthConfigured
>;

describe('GitHub OAuth routes', () => {
  afterEach(() => {
    mockGitHubOAuthConfigured.mockReturnValue(true);
  });

  it('GET /auth/github/availability reports missing OAuth credentials', async () => {
    mockGitHubOAuthConfigured.mockReturnValue(false);
    const res = await request(app).get('/auth/github/availability');
    expect(res.status).toBe(200);
    expect(res.body.data.configured).toBe(false);
  });

  it('GET /auth/github returns configuration error when OAuth credentials are absent', async () => {
    mockGitHubOAuthConfigured.mockReturnValue(false);
    const res = await request(app).get('/auth/github');
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('GITHUB_OAUTH_NOT_CONFIGURED');
  });

  it('GET /auth/github redirects to GitHub (302)', async () => {
    const res = await request(app).get('/auth/github');
    expect(res.status).toBe(302);
    expect(res.headers.location).toMatch(/github\.com/);
  });

  it('GET /auth/github/callback redirects to the frontend with a token', async () => {
    const res = await request(app).get('/auth/github/callback');
    expect(res.status).toBe(302);
    const callbackUrl = new URL(res.headers.location);
    expect(callbackUrl.origin).toBe('http://localhost:5173');
    expect(callbackUrl.pathname).toBe('/auth/callback');
    const token = callbackUrl.searchParams.get('token');
    expect(token).toBeTruthy();
    const decoded = jwt.verify(token!, JWT_SECRET) as Record<
      string,
      unknown
    >;
    expect(decoded.username).toBe('testuser');
  });

  it('POST /auth/logout returns 200 with message', async () => {
    const res = await request(app).post('/auth/logout');
    expect(res.status).toBe(200);
    expect(res.body.data.message).toBe('Logged out successfully');
  });
});

describe('GET /api/v1/me', () => {
  it('returns 401 without Authorization header', async () => {
    const res = await request(app).get('/api/v1/me');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('returns 401 when Authorization header is missing Bearer prefix', async () => {
    const res = await request(app)
      .get('/api/v1/me')
      .set('Authorization', 'Basic dXNlcjpwYXNz');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('returns 401 with an invalid token', async () => {
    const res = await request(app)
      .get('/api/v1/me')
      .set('Authorization', 'Bearer invalid.token.here');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_TOKEN');
  });

  it('returns 200 with decoded user payload for a valid JWT', async () => {
    const token = jwt.sign(
      { id: 'test-id', username: 'testuser', role: 'viewer' },
      JWT_SECRET
    );
    const res = await request(app)
      .get('/api/v1/me')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      id: 'test-id',
      username: 'testuser',
      role: 'viewer',
    });
  });
});
