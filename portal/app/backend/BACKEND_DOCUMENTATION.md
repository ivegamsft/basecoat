# Basecoat Portal API - Backend Implementation Guide

## Table of Contents

1. [Quick Start](#quick-start)
2. [Project Structure](#project-structure)
3. [Configuration & Environment](#configuration--environment)
4. [Server Setup](#server-setup)
5. [Database Configuration](#database-configuration)
6. [Authentication & Authorization](#authentication--authorization)
7. [Error Handling](#error-handling)
8. [Logging](#logging)
9. [API Endpoints](#api-endpoints)
10. [Testing](#testing)
11. [Development Patterns](#development-patterns)
12. [Debugging](#debugging)

## Quick Start

### Prerequisites

- Node.js 18+
- PostgreSQL 12+
- npm 8+

### Installation

```bash
cd backend
npm install
```

### Environment Setup

```bash
cp .env.example .env
# Edit .env with your configuration
```

### Database Setup

```bash
npm run db:migrate
npm run seed
```

### Start Development Server

```bash
npm run dev
```

Server will be available at `http://localhost:3000`

### Verify Health

```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "OK",
  "timestamp": "2024-01-15T10:30:00Z",
  "requestId": "550e8400-e29b-41d4-a716-446655440000"
}
```

## Project Structure

```
backend/
├── src/
│   ├── main.ts                    # Entry point
│   ├── config/
│   │   ├── app.ts                 # Express app initialization
│   │   ├── database.ts            # TypeORM configuration
│   │   └── logger.ts              # Winston logger setup
│   ├── controllers/
│   │   └── audit.controller.ts    # Request handlers
│   ├── services/
│   │   └── audit.service.ts       # Business logic
│   ├── models/
│   │   ├── user.entity.ts         # User database entity
│   │   ├── audit.entity.ts        # Audit database entity
│   │   ├── finding.entity.ts      # Finding database entity
│   │   ├── repository.entity.ts   # Repository database entity
│   │   └── team.entity.ts         # Team database entity
│   ├── middleware/
│   │   ├── auth.middleware.ts     # JWT verification
│   │   ├── error.middleware.ts    # Error handling
│   │   └── request.middleware.ts  # Request ID, logging
│   ├── routes/
│   │   └── audit.routes.ts        # API route definitions
│   ├── types/                      # TypeScript interfaces
│   └── utils/
│       └── errors.ts              # Custom error classes
├── tests/
│   ├── setup.ts                    # Jest setup & database
│   ├── unit/                       # Unit tests
│   └── integration/
│       └── audit.test.ts           # API integration tests
├── package.json
├── tsconfig.json
├── jest.config.js
├── .env.example                    # Environment template
└── README.md
```

## Configuration & Environment

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 3000 | Server port |
| `NODE_ENV` | development | Environment (development, staging, production) |
| `APP_NAME` | basecoat-portal-api | Application name |
| `DB_HOST` | localhost | PostgreSQL host |
| `DB_PORT` | 5432 | PostgreSQL port |
| `DB_NAME` | basecoat_db | Database name |
| `DB_USER` | postgres | Database user |
| `DB_PASSWORD` | postgres_password | Database password |
| `JWT_SECRET` | your_secret | JWT signing key (CHANGE IN PRODUCTION) |
| `JWT_EXPIRY` | 15m | Access token expiration |
| `JWT_REFRESH_SECRET` | your_refresh_secret | Refresh token signing key |
| `JWT_REFRESH_EXPIRY` | 7d | Refresh token expiration |
| `LOG_LEVEL` | debug | Winston log level |
| `CORS_ORIGINS` | http://localhost:3000 | Comma-separated CORS origins |

### Development Configuration

For local development:

```bash
cp .env.example .env
# .env now contains default development settings
npm install
npm run dev
```

## Server Setup

### Express Middleware Stack

The application uses the following middleware:

1. **Request ID** - Assigns unique ID to each request for tracing
2. **Request Logging** - Logs all HTTP requests with duration
3. **CORS** - Handles cross-origin requests with configurable origins
4. **Body Parser** - Parses JSON and URL-encoded request bodies (10MB limit)
5. **Security Headers** - Adds security headers (X-Content-Type-Options, X-Frame-Options, etc.)
6. **Error Handler** - Catches and formats all errors
7. **404 Handler** - Handles unmapped routes

### Health Check Endpoint

```bash
GET /health
```

Response (200 OK):
```json
{
  "status": "OK",
  "timestamp": "2024-01-15T10:30:00Z",
  "requestId": "uuid-here"
}
```

### Version Endpoint

```bash
GET /api/v1/version
```

Response (200 OK):
```json
{
  "version": "v1",
  "app": "basecoat-portal-api",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Graceful Shutdown

The server handles SIGTERM and SIGINT signals:

1. Closes HTTP server
2. Gracefully closes database connections
3. Logs all shutdown events

## Database Configuration

### Connection Pool

- **Min connections**: 2
- **Max connections**: 50
- **Query timeout**: 30 seconds

### TypeORM Setup

Database configuration is managed by TypeORM with the following features:

- **Auto-synchronization** in development mode
- **Migrations** for production schema changes
- **Query logging** in development
- **Connection retry** logic

### Entities

The database schema includes:

- **Users** - System users with roles (admin, auditor, developer, viewer)
- **Teams** - Team groupings for repository management
- **Repositories** - GitHub repositories being audited
- **Audits** - Security/compliance audit records
- **Findings** - Vulnerabilities/issues found during audits

### Running Migrations

```bash
# Forward
npm run db:migrate

# Rollback
npm run db:rollback

# Generate new migration
npm run db:generate
```

## Authentication & Authorization

### JWT Implementation

1. **Access Token** (15 minutes)
   - Used for API requests
   - Included in Authorization header: `Bearer <token>`

2. **Refresh Token** (7 days)
   - Used to obtain new access tokens
   - Stored securely server-side

### Authentication Middleware

```typescript
// Protect endpoint with authentication
import { authMiddleware } from '@middleware/auth.middleware';

router.get('/protected', authMiddleware, handler);
```

### Role-Based Access Control (RBAC)

```typescript
import { requireRole } from '@middleware/auth.middleware';

// Only admin and auditor can create audits
router.post('/audits', 
  authMiddleware,
  requireRole('admin', 'auditor'),
  handler
);
```

### User Roles

- **admin** - Full system access
- **auditor** - Create and manage audits
- **developer** - View audit results
- **viewer** - Read-only access

### Obtaining Tokens

Authentication is typically handled by:

1. GitHub OAuth integration (returns temporary code)
2. Backend exchanges code for access token
3. Backend issues internal JWT tokens

## Error Handling

### Error Response Format

All errors follow a consistent format:

```json
{
  "code": "ERROR_CODE",
  "message": "Human-readable error message",
  "details": {
    "field": "Additional context"
  },
  "timestamp": "2024-01-15T10:30:00Z",
  "requestId": "uuid-here"
}
```

### HTTP Status Codes

| Status | Meaning | Example |
|--------|---------|---------|
| 400 | Validation error | Missing required field |
| 401 | Authentication required | No/invalid JWT token |
| 403 | Insufficient permissions | User role too low |
| 404 | Resource not found | Audit ID doesn't exist |
| 409 | Conflict | Duplicate resource |
| 500 | Server error | Database connection failed |

### Error Classes

```typescript
// Validation error
throw new ValidationError('Invalid input', { field: 'email' });

// Not found
throw new NotFoundError('Audit', id);

// Unauthorized
throw new UnauthorizedError('Invalid token');

// Forbidden (RBAC)
throw new ForbiddenError('Insufficient permissions');

// Database error
throw new DatabaseError('Query failed');

// External service error
throw new ExternalServiceError('GitHub API', 'rate limited');
```

## Logging

### Log Levels

- **error** - Error events (exceptions, failed operations)
- **warn** - Warning events (non-critical issues)
- **info** - Informational events (server start, audit created)
- **debug** - Debug details (token verified, query executed)

### Log Output

#### Development
- Console output (colorized)
- File: `logs/app.log`

#### Production
- File: `logs/app.log` (JSON format)
- File: `logs/error.log` (errors only)

### Accessing Logs

```bash
# Real-time log tailing
tail -f logs/app.log

# Last 100 lines
tail -n 100 logs/app.log

# Search for audit creation
grep "Audit created" logs/app.log
```

### Structured Logging Example

```typescript
logger.info('Audit created', {
  requestId: req.requestId,
  auditId: audit.id,
  repositoryId: audit.repositoryId,
  type: audit.type,
  userId: req.userId,
});
```

## API Endpoints

### Audit Management

#### Create Audit

```
POST /api/v1/audits
Authorization: Bearer <token>
Content-Type: application/json

{
  "repositoryId": "uuid",
  "type": "security|compliance|code-quality|dependency",
  "metadata": {
    "tool": "SAST",
    "version": "1.0"
  }
}
```

Response (201):
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "repositoryId": "uuid",
    "type": "security",
    "status": "pending",
    "createdAt": "2024-01-15T10:30:00Z"
  }
}
```

#### List Audits

```
GET /api/v1/audits?limit=20&offset=0&type=security&status=completed
Authorization: Bearer <token>
```

Query Parameters:
- `limit` (1-100, default: 20) - Results per page
- `offset` (default: 0) - Results to skip
- `type` (optional) - Filter by audit type
- `status` (optional) - Filter by status
- `repositoryId` (optional) - Filter by repository

Response (200):
```json
{
  "success": true,
  "items": [
    {
      "id": "uuid",
      "repositoryId": "uuid",
      "type": "security",
      "status": "completed",
      "createdAt": "2024-01-15T10:30:00Z"
    }
  ],
  "pagination": {
    "total": 42,
    "limit": 20,
    "offset": 0,
    "hasMore": true
  }
}
```

#### Get Audit

```
GET /api/v1/audits/:id
Authorization: Bearer <token>
```

Response (200):
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "repositoryId": "uuid",
    "type": "security",
    "status": "completed",
    "findings": [
      {
        "id": "uuid",
        "severity": "high",
        "category": "SQL Injection",
        "status": "open"
      }
    ],
    "createdAt": "2024-01-15T10:30:00Z",
    "completedAt": "2024-01-15T11:45:00Z"
  }
}
```

#### Update Audit Status

```
PATCH /api/v1/audits/:id/status
Authorization: Bearer <token>
Content-Type: application/json

{
  "status": "in_progress|completed|failed"
}
```

Response (200):
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "status": "completed",
    "completedAt": "2024-01-15T11:45:00Z"
  }
}
```

#### Add Finding

```
POST /api/v1/audits/:id/findings
Authorization: Bearer <token>
Content-Type: application/json

{
  "severity": "critical|high|medium|low|info",
  "category": "SQL Injection",
  "description": "Vulnerability found in user login endpoint",
  "remediation": "Use parameterized queries",
  "reference": "CWE-89"
}
```

Response (201):
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "auditId": "uuid",
    "severity": "high",
    "category": "SQL Injection",
    "status": "open",
    "createdAt": "2024-01-15T10:30:00Z"
  }
}
```

#### Delete Audit

```
DELETE /api/v1/audits/:id
Authorization: Bearer <token>
```

Response (200):
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "deleted": true
  }
}
```

## Testing

### Running Tests

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Generate coverage report
npm run test:coverage
```

### Test Coverage Requirements

- **Branches**: 70%
- **Functions**: 70%
- **Lines**: 70%
- **Statements**: 70%

### Writing Integration Tests

```typescript
describe('Audit API', () => {
  let authToken: string;
  let testRepository: Repository;

  beforeAll(async () => {
    // Setup test data
    authToken = generateTestToken();
    testRepository = await createTestRepository();
  });

  it('should create an audit', async () => {
    const response = await request(app.getExpressApp())
      .post('/api/v1/audits')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        repositoryId: testRepository.id,
        type: 'security',
      });

    expect(response.status).toBe(201);
    expect(response.body.data.type).toBe('security');
  });
});
```

### Mocking Strategies

```typescript
// Mock external service
jest.mock('@services/github.service', () => ({
  fetchRepository: jest.fn().mockResolvedValue({
    id: '123',
    name: 'test-repo',
  }),
}));

// Mock database repository
const mockAuditRepository = {
  create: jest.fn(),
  save: jest.fn(),
  findOne: jest.fn(),
};
```

## Development Patterns

### Controller Pattern

```typescript
// controllers/example.controller.ts
export class ExampleController {
  private exampleService = new ExampleService();

  async getExample(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const example = await this.exampleService.getExample(req.params.id);
      res.json({ success: true, data: example });
    } catch (error) {
      next(error);
    }
  }
}
```

### Service Pattern

```typescript
// services/example.service.ts
export class ExampleService {
  private repository = AppDataSource.getRepository(Example);

  async getExample(id: string) {
    const example = await this.repository.findOne({ where: { id } });
    
    if (!example) {
      throw new NotFoundError('Example', id);
    }

    return example;
  }

  async createExample(data: CreateExampleDto) {
    const example = this.repository.create(data);
    return await this.repository.save(example);
  }
}
```

### Route Registration

```typescript
// routes/example.routes.ts
const router = Router();
const controller = new ExampleController();

router.get('/:id', authMiddleware, (req, res, next) =>
  controller.getExample(req, res, next)
);

router.post('/', authMiddleware, requireRole('admin'), (req, res, next) =>
  controller.createExample(req, res, next)
);

export default router;
```

### Input Validation

```typescript
import Joi from 'joi';

const schema = Joi.object({
  email: Joi.string().email().required(),
  name: Joi.string().min(3).max(100).required(),
  role: Joi.string().valid('admin', 'user').required(),
});

const { error, value } = schema.validate(req.body);

if (error) {
  throw new ValidationError(error.message);
}
```

## Debugging

### Enable Verbose Logging

```bash
# Console output only
LOG_LEVEL=debug npm run dev

# Include SQL queries
DEBUG=true npm run dev
```

### Debug TypeORM Queries

```typescript
// In database.ts
logging: process.env.NODE_ENV === 'development' && process.env.DEBUG === 'true'
```

### Use Chrome DevTools

```bash
node --inspect-brk dist/src/main.js
```

Then open: `chrome://inspect`

### Common Issues

#### Database Connection Failed

```bash
# Check PostgreSQL is running
psql -U postgres -h localhost

# Verify environment variables
echo $DB_HOST $DB_PORT $DB_USER $DB_NAME

# Check logs
tail -f logs/error.log
```

#### JWT Token Invalid

```bash
# Verify token format
echo "eyJ..." | jq

# Check token expiration
jwt.decode(token, { complete: true })

# Verify JWT secret matches
grep JWT_SECRET .env
```

#### Port Already in Use

```bash
# Find process using port 3000
lsof -i :3000

# Kill process
kill -9 <PID>
```

### Performance Profiling

```bash
# Node.js built-in profiling
node --prof dist/src/main.js

# Process profile
node --prof-process isolate-*.log > profile.txt
```

## Deployment Checklist

- [ ] Update all environment variables for production
- [ ] Regenerate JWT secrets
- [ ] Configure database backups
- [ ] Set up monitoring and alerting
- [ ] Configure CORS origins for frontend domains
- [ ] Enable HTTPS/TLS
- [ ] Set up error tracking (e.g., Sentry)
- [ ] Configure log rotation and archival
- [ ] Run database migrations
- [ ] Run test suite with coverage
- [ ] Performance test with production load
- [ ] Document API endpoints (OpenAPI/Swagger)

## Support & Resources

- API Specification: `PORTAL_API_v1.0.yml`
- Implementation Guide: `PORTAL_IMPLEMENTATION_GUIDE_v1.md`
- TypeORM Docs: https://typeorm.io/
- Express.js Docs: https://expressjs.com/
- JWT Best Practices: https://tools.ietf.org/html/rfc7519
