# Basecoat Portal Backend

Express/TypeScript/Sequelize API server for the Basecoat Portal.

## Prerequisites

- Node.js 20+
- PostgreSQL 15+

## Setup

```bash
cp .env.example .env
# Edit .env with database credentials and GitHub OAuth credentials
npm install
npm run db:migrate
npm run dev
```

Create a GitHub OAuth App (or a GitHub App with a user authorization callback)
before starting the browser flow. Set its callback URL to
`http://localhost:3000/auth/github/callback`, then copy its client ID and client
secret into `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET`. The API redirects a
completed sign-in to `FRONTEND_URL/auth/callback`; use
`http://localhost:5173` for the Vite development server.

## Scripts

| Command | Description |
|---|---|
| `npm run build` | Compile TypeScript to `dist/` |
| `npm start` | Run compiled server |
| `npm run dev` | Run with ts-node (development) |
| `npm test` | Run Jest test suite |
| `npm run test:coverage` | Run tests with coverage report |
| `npm run db:migrate` | Run Sequelize migrations |
| `npm run db:seed` | Seed the database |
| `npm run lint` | Lint source files |

## Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Health check |

## Environment Variables

See `.env.example` for all required variables. `GITHUB_CLIENT_ID` and
`GITHUB_CLIENT_SECRET` are required to begin a sign-in; the API returns
`503 GITHUB_OAUTH_NOT_CONFIGURED` instead of redirecting to GitHub when either
value is absent.

## Architecture

- **Framework**: Express 4
- **Language**: TypeScript 5
- **ORM**: Sequelize 6 (PostgreSQL)
- **Logging**: Winston
- **Testing**: Jest + supertest

## Related Issues

- #485 — Backend scaffold
- #486 — Data models and migrations
