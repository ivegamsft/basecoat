# Basecoat Portal API - Backend

Production-ready Node.js + TypeScript backend for the Basecoat Portal API with comprehensive security audit and compliance tracking capabilities.

## Quick Start

### Prerequisites

- Node.js 18+ ([Download](https://nodejs.org/))
- PostgreSQL 12+ ([Download](https://www.postgresql.org/download/))
- npm 8+

### Setup in 5 Minutes

1. **Install dependencies**
   ```bash
   npm install
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your local PostgreSQL credentials
   ```

3. **Create database** (optional - TypeORM auto-creates in dev)
   ```sql
   CREATE DATABASE basecoat_db;
   ```

4. **Start server**
   ```bash
   npm run dev
   ```

5. **Verify**
   ```bash
   curl http://localhost:3000/health
   ```

Expected response:
```json
{
  "status": "OK",
  "timestamp": "2024-01-15T10:30:00Z",
  "requestId": "uuid"
}
```

## Features

- **JWT Authentication** - Secure token-based auth with refresh tokens
- **Role-Based Access Control** - admin, auditor, developer, viewer roles
- **Comprehensive Logging** - Winston logger with file rotation
- **Error Handling** - Consistent error responses with request tracing
- **Database Abstraction** - TypeORM with PostgreSQL
- **Type Safety** - Full TypeScript support
- **Integration Tests** - Jest + Supertest with >80% coverage
- **Security Headers** - CORS, X-Frame-Options, HSTS configured

## Project Structure

```
src/
  ├── main.ts                    # Entry point
  ├── config/
  │   ├── app.ts                 # Express setup
  │   ├── database.ts            # TypeORM config
  │   └── logger.ts              # Winston setup
  ├── controllers/               # Request handlers
  ├── services/                  # Business logic
  ├── models/                    # Database entities
  ├── middleware/                # Auth, logging, errors
  ├── routes/                    # API routes
  └── utils/                     # Helpers & errors
tests/
  ├── integration/               # API tests
  └── unit/                      # Service tests
```

## Available Scripts

```bash
npm run dev                       # Start dev server with hot reload
npm run build                     # Build TypeScript to JavaScript
npm start                         # Run compiled app (production)
npm test                          # Run all tests
npm run test:watch               # Run tests in watch mode
npm run test:coverage            # Generate coverage report
npm run lint                      # Run ESLint
npm run lint:fix                  # Fix linting issues
npm run format                    # Format code with Prettier
npm run db:migrate               # Run database migrations
npm run db:rollback              # Revert last migration
npm run health-check             # Test /health endpoint
```

## API Endpoints

### Authentication
- `POST /api/v1/auth/login` - Login
- `POST /api/v1/auth/refresh` - Refresh token
- `POST /api/v1/auth/logout` - Logout

### Audits (Sample CRUD)
- `POST /api/v1/audits` - Create audit
- `GET /api/v1/audits` - List audits (paginated)
- `GET /api/v1/audits/:id` - Get audit details
- `PATCH /api/v1/audits/:id/status` - Update status
- `POST /api/v1/audits/:id/findings` - Add finding
- `DELETE /api/v1/audits/:id` - Delete audit

### System
- `GET /health` - Health check
- `GET /api/v1/version` - API version

## Authentication

### Using JWT

Include token in Authorization header:

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:3000/api/v1/audits
```

### Token Structure

```javascript
{
  "userId": "uuid",
  "email": "user@example.com",
  "role": "auditor",
  "iat": 1234567890,
  "exp": 1234568890
}
```

## Configuration

See `.env.example` for all environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `PORT` | 3000 | Server port |
| `DB_HOST` | localhost | Database host |
| `DB_USER` | postgres | Database user |
| `DB_PASSWORD` | postgres_password | Database password |
| `JWT_SECRET` | secret | JWT signing key |
| `LOG_LEVEL` | debug | Logging level |

## Development

### Hot Reload

```bash
npm run dev
```

Changes to `src/**/*.ts` automatically restart the server.

### Debugging

```bash
# Verbose logging
LOG_LEVEL=debug npm run dev

# Chrome DevTools debugging
node --inspect-brk dist/src/main.js
```

Then open `chrome://inspect` in Chrome.

## Testing

### Run Tests

```bash
npm test                          # Single run
npm run test:watch               # Watch mode
npm run test:coverage            # With coverage report
```

### Test Coverage

Target: >80% coverage across statements, branches, functions, and lines.

### Writing Tests

See `tests/integration/audit.test.ts` for examples using:
- Supertest for API testing
- Jest for assertions
- Database seeding for test data

## Database

### Migrations

```bash
npm run db:migrate               # Apply pending migrations
npm run db:rollback              # Revert last migration
npm run db:generate              # Create new migration
```

### Entities

- **User** - System users
- **Team** - Team groupings
- **Repository** - GitHub repositories
- **Audit** - Audit records
- **Finding** - Audit findings

## Logging

### Log Files

- `logs/app.log` - All logs
- `logs/error.log` - Error logs only

### Log Levels

```bash
LOG_LEVEL=error                  # Only errors
LOG_LEVEL=warn                   # Warnings & errors
LOG_LEVEL=info                   # General info (production default)
LOG_LEVEL=debug                  # Detailed debugging (development default)
```

### Viewing Logs

```bash
tail -f logs/app.log             # Real-time monitoring
grep "Audit created" logs/app.log # Search logs
```

## Error Handling

All errors return consistent JSON format:

```json
{
  "code": "VALIDATION_ERROR",
  "message": "Invalid audit type",
  "timestamp": "2024-01-15T10:30:00Z",
  "requestId": "uuid-for-tracing"
}
```

## Security

- JWT tokens expire after 15 minutes
- Refresh tokens expire after 7 days
- Passwords hashed with bcrypt (10 rounds)
- CORS restricted to configured origins
- Security headers (X-Frame-Options, X-Content-Type-Options, HSTS)
- Request validation with Joi
- SQL injection prevention via TypeORM query builder
- Rate limiting (recommended: nginx/Kong)

## Production Deployment

1. Update `.env` with production values
2. Run `npm run build`
3. Set `NODE_ENV=production`
4. Run `npm start`
5. Configure reverse proxy (nginx) for SSL/TLS
6. Setup monitoring and logging aggregation
7. Configure database backups
8. Setup health checks and auto-restart

See `BACKEND_DOCUMENTATION.md` for deployment checklist.

## Troubleshooting

### Database Connection Fails

```bash
# Verify PostgreSQL is running
psql -U postgres -h localhost

# Check .env settings
cat .env | grep DB_

# Check logs
tail logs/error.log
```

### Port Already in Use

```bash
lsof -i :3000
kill -9 <PID>
```

### JWT Token Invalid

```bash
# Regenerate in .env
JWT_SECRET=$(uuidgen)
```

## Documentation

- **API Reference** - `BACKEND_DOCUMENTATION.md`
- **OpenAPI Spec** - `../PORTAL_API_v1.0.yml`
- **Implementation Guide** - `../docs/PORTAL_IMPLEMENTATION_GUIDE_v1.md`

## Tech Stack

- **Framework** - Express.js
- **Language** - TypeScript
- **Database** - PostgreSQL with TypeORM
- **Authentication** - JWT with bcrypt
- **Logging** - Winston
- **Testing** - Jest + Supertest
- **Validation** - Joi
- **Linting** - ESLint + Prettier

## Contributing

1. Create feature branch: `git checkout -b feature/my-feature`
2. Make changes and add tests
3. Run tests: `npm test`
4. Lint & format: `npm run lint:fix && npm run format`
5. Commit: `git commit -am "feat: add my feature"`
6. Push: `git push origin feature/my-feature`
7. Create Pull Request

## License

MIT

## Support

For issues or questions:
1. Check `BACKEND_DOCUMENTATION.md`
2. Search existing issues
3. Create new GitHub issue with details
