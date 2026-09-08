import { Router, Request, Response } from 'express';
import passport from '../config/passport';
import { isGitHubOAuthConfigured } from '../config/passport';
import jwt from 'jsonwebtoken';

const router = Router();

router.get('/auth/github/availability', (_req: Request, res: Response) => {
  res.json({ data: { configured: isGitHubOAuthConfigured() } });
});

router.get(
  '/auth/github',
  (_req: Request, res: Response, next) => {
    if (!isGitHubOAuthConfigured()) {
      res.status(503).json({
        error: {
          code: 'GITHUB_OAUTH_NOT_CONFIGURED',
          message:
            'GitHub OAuth is not configured. Set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET.',
        },
      });
      return;
    }
    next();
  },
  passport.authenticate('github', { scope: ['user:email'] })
);

router.get(
  '/auth/github/callback',
  passport.authenticate('github', {
    session: false,
    failureRedirect: '/login?error=auth_failed',
  }),
  (req: Request, res: Response) => {
    const user = (req as Request & { user: { id: string; username: string; role: string } }).user;
    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role },
      process.env.JWT_SECRET || 'dev-secret',
      { expiresIn: '7d' }
    );
    const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:5173';
    const callbackUrl = new URL('/auth/callback', frontendUrl);
    callbackUrl.searchParams.set('token', token);
    res.redirect(callbackUrl.toString());
  }
);

router.post('/auth/logout', (_req: Request, res: Response) => {
  res.json({ data: { message: 'Logged out successfully' } });
});

export default router;
