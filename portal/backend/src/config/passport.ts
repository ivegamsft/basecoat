import passport from 'passport';
import { Strategy as GitHubStrategy, Profile } from 'passport-github2';
import { VerifyCallback } from 'passport-oauth2';
import { User } from '../models';

function hasConfiguredValue(value: string | undefined): boolean {
  return Boolean(
    value?.trim() &&
      !value.startsWith('<') &&
      value !== 'test-client-id' &&
      value !== 'test-client-secret'
  );
}

export function isGitHubOAuthConfigured(): boolean {
  return (
    hasConfiguredValue(process.env.GITHUB_CLIENT_ID) &&
    hasConfiguredValue(process.env.GITHUB_CLIENT_SECRET)
  );
}

export async function verifyGitHubProfile(
  _accessToken: string,
  _refreshToken: string,
  profile: Profile,
  done: VerifyCallback
): Promise<void> {
  try {
    const [user] = await User.findOrCreate({
      where: { githubId: profile.id },
      defaults: {
        githubId: profile.id,
        username: profile.username || '',
        email: profile.emails?.[0]?.value ?? null,
        avatarUrl: profile.photos?.[0]?.value ?? null,
        role: 'viewer',
      },
    });
    return done(null, user as unknown as Express.User);
  } catch (err) {
    return done(err as Error);
  }
}

passport.use(
  new GitHubStrategy(
    {
      clientID: process.env.GITHUB_CLIENT_ID || 'test-client-id',
      clientSecret: process.env.GITHUB_CLIENT_SECRET || 'test-client-secret',
      callbackURL:
        process.env.GITHUB_CALLBACK_URL ||
        'http://localhost:3000/auth/github/callback',
    },
    verifyGitHubProfile
  )
);

export default passport;
