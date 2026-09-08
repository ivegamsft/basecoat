import { Sequelize } from 'sequelize';
import { User, initUser } from '../src/models/User';
import { isGitHubOAuthConfigured, verifyGitHubProfile } from '../src/config/passport';
import type { Profile } from 'passport-github2';
import type { VerifyCallback } from 'passport-oauth2';

let testSequelize: Sequelize;

beforeAll(async () => {
  testSequelize = new Sequelize({
    dialect: 'sqlite',
    storage: ':memory:',
    logging: false,
  });
  initUser(testSequelize);
  await testSequelize.sync({ force: true });
});

afterAll(async () => {
  await testSequelize.close();
});

function makeProfile(overrides: Partial<Profile> = {}): Profile {
  return {
    id: 'gh-test-001',
    username: 'octocat',
    displayName: 'Octocat',
    profileUrl: 'https://github.com/octocat',
    emails: [{ value: 'octocat@github.com' }],
    photos: [{ value: 'https://avatars.githubusercontent.com/octocat' }],
    provider: 'github',
    ...overrides,
  } as Profile;
}

describe('verifyGitHubProfile', () => {
  it('creates a new user when none exists and calls done with user', async () => {
    const profile = makeProfile();
    await new Promise<void>((resolve, reject) => {
      const done: VerifyCallback = (err, user) => {
        if (err) return reject(err);
        expect(user).toBeDefined();
        const u = user as unknown as { username: string; role: string; githubId: string };
        expect(u.username).toBe('octocat');
        expect(u.role).toBe('viewer');
        expect(u.githubId).toBe('gh-test-001');
        resolve();
      };
      verifyGitHubProfile('token', 'refresh', profile, done);
    });

  });

  it('returns existing user on second login with same githubId', async () => {
    const profile = makeProfile({ id: 'gh-test-001' });
    let callCount = 0;
    await new Promise<void>((resolve, reject) => {
      const done: VerifyCallback = (err, user) => {
        if (err) return reject(err);
        callCount++;
        expect(user).toBeDefined();
        resolve();
      };
      verifyGitHubProfile('token', 'refresh', profile, done);
    });
    expect(callCount).toBe(1);
    const total = await User.count({ where: { githubId: 'gh-test-001' } });
    expect(total).toBe(1);
  });

  it('uses empty string for username when profile.username is missing', async () => {
    const profile = makeProfile({ id: 'gh-no-username', username: undefined });
    await new Promise<void>((resolve, reject) => {
      const done: VerifyCallback = (err, user) => {
        if (err) return reject(err);
        const u = user as unknown as { username: string };
        expect(u.username).toBe('');
        resolve();
      };
      verifyGitHubProfile('token', 'refresh', profile, done);
    });
  });

  describe('isGitHubOAuthConfigured', () => {
    const originalClientId = process.env.GITHUB_CLIENT_ID;
    const originalClientSecret = process.env.GITHUB_CLIENT_SECRET;

    afterEach(() => {
      if (originalClientId === undefined) {
        delete process.env.GITHUB_CLIENT_ID;
      } else {
        process.env.GITHUB_CLIENT_ID = originalClientId;
      }
      if (originalClientSecret === undefined) {
        delete process.env.GITHUB_CLIENT_SECRET;
      } else {
        process.env.GITHUB_CLIENT_SECRET = originalClientSecret;
      }
    });

    it('rejects missing and placeholder OAuth credentials', () => {
      delete process.env.GITHUB_CLIENT_ID;
      process.env.GITHUB_CLIENT_SECRET = 'client-secret';
      expect(isGitHubOAuthConfigured()).toBe(false);

      process.env.GITHUB_CLIENT_ID = '<your-github-client-id>';
      expect(isGitHubOAuthConfigured()).toBe(false);

      process.env.GITHUB_CLIENT_ID = 'test-client-id';
      expect(isGitHubOAuthConfigured()).toBe(false);
    });

    it('accepts configured OAuth credentials', () => {
      process.env.GITHUB_CLIENT_ID = 'Iv1.a1b2c3d4e5f6g7h8';
      process.env.GITHUB_CLIENT_SECRET = 'client-secret';
      expect(isGitHubOAuthConfigured()).toBe(true);
    });
  });

  it('uses null for email and avatarUrl when not present in profile', async () => {
    const profile = makeProfile({
      id: 'gh-no-email',
      emails: undefined,
      photos: undefined,
    });
    await new Promise<void>((resolve, reject) => {
      const done: VerifyCallback = (err, user) => {
        if (err) return reject(err);
        const u = user as unknown as { email: string | null; avatarUrl: string | null };
        expect(u.email).toBeNull();
        expect(u.avatarUrl).toBeNull();
        resolve();
      };
      verifyGitHubProfile('token', 'refresh', profile, done);
    });
  });

  it('calls done with error when User.findOrCreate throws', async () => {
    const originalFindOrCreate = User.findOrCreate;
    const fakeError = new Error('DB connection failed');
    User.findOrCreate = jest.fn().mockRejectedValue(fakeError);

    await new Promise<void>((resolve) => {
      const done: VerifyCallback = (err) => {
        expect(err).toBe(fakeError);
        resolve();
      };
      verifyGitHubProfile('token', 'refresh', makeProfile({ id: 'gh-err' }), done);
    });

    User.findOrCreate = originalFindOrCreate;
  });
});
