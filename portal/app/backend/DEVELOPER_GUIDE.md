# Backend Development Guide

## Getting Started (5 Minutes)

### 1. Prerequisites

Ensure you have the following installed:

```bash
node --version                    # Should be v18+
npm --version                     # Should be v8+
psql --version                    # PostgreSQL client
```

### 2. Clone & Install

```bash
# Already in backend directory
npm install
```

### 3. Database Setup

#### Option A: Using Docker Compose (Recommended)

```bash
# Start PostgreSQL and Redis containers
docker-compose up -d postgres redis

# Wait for containers to be healthy (about 10 seconds)
docker-compose ps
```

#### Option B: Local PostgreSQL

```bash
# Ensure PostgreSQL is running
psql -U postgres -h localhost

# Create database
createdb -U postgres basecoat_db
```

### 4. Configure Environment

```bash
# Copy template
cp .env.example .env

# Edit .env with your settings (or use defaults for development)
cat .env
```

### 5. Run Development Server

```bash
npm run dev
```

Expected output:
```
info: Server started
  port: 3000
  env: development
  apiPrefix: /api/v1
```

### 6. Verify Installation

In a new terminal:

```bash
curl http://localhost:3000/health
```

Response:
```json
{
  "status": "OK",
  "timestamp": "2024-01-15T10:30:00Z",
  "requestId": "550e8400-e29b-41d4-a716-446655440000"
}
```

## Common Development Tasks

### Running Tests

```bash
# All tests
npm test

# Specific file
npm test -- tests/integration/audit.test.ts

# Watch mode (reruns on file changes)
npm run test:watch

# With coverage report
npm run test:coverage
```

### Code Quality

```bash
# Lint code
npm run lint

# Fix linting issues
npm run lint:fix

# Format code (prettier)
npm run format
```

### Database Operations

```bash
# Run migrations
npm run db:migrate

# Rollback last migration
npm run db:rollback

# Create new migration (after schema changes)
npm run db:generate

# Seed test data
npm run seed
```

### Building for Production

```bash
# Build TypeScript to JavaScript
npm run build

# Output goes to dist/
ls -la dist/

# Run compiled version
npm start
```

## Architecture & Patterns

### Layered Architecture

```
Request → Route → Controller → Service → Repository → Database
   ↓                                                        ↓
Middleware (auth, validation)                          TypeORM
Error Handler ←──────────────────────────────────────────↓
```

### Folder Structure Explained

```
src/
├── main.ts                    # Application entry point
│                               # Exports App class
├── config/
│   ├── app.ts                 # Express setup & middleware
│   ├── database.ts            # TypeORM configuration
│   └── logger.ts              # Winston logger setup
├── controllers/
│   └── audit.controller.ts    # HTTP request handlers
│                               # Validates input, calls service
├── services/
│   └── audit.service.ts       # Business logic
│                               # Complex operations, validation
├── models/
│   ├── *.entity.ts            # Database entities
│                               # TypeORM decorators
├── middleware/
│   ├── auth.middleware.ts     # JWT verification
│   ├── error.middleware.ts    # Error formatting
│   └── request.middleware.ts  # Request tracking, logging
├── routes/
│   └── audit.routes.ts        # Express Router setup
│                               # Maps HTTP methods to controllers
└── utils/
    └── errors.ts              # Custom error classes
```

### Key Patterns

#### Controller Pattern

```typescript
// controllers/audit.controller.ts
export class AuditController {
  private auditService = new AuditService();

  async createAudit(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      // 1. Validate input
      const schema = Joi.object({...});
      const { error, value } = schema.validate(req.body);
      if (error) throw new ValidationError(error.message);

      // 2. Call service
      const audit = await this.auditService.createAudit({
        repositoryId: value.repositoryId,
        createdById: req.userId,
        type: value.type,
      });

      // 3. Send response
      res.status(201).json({ success: true, data: audit });
    } catch (error) {
      // 4. Pass error to error handler
      next(error);
    }
  }
}
```

#### Service Pattern

```typescript
// services/audit.service.ts
export class AuditService {
  private auditRepository = AppDataSource.getRepository(Audit);
  private userRepository = AppDataSource.getRepository(User);

  async createAudit(data: {...}) {
    try {
      // 1. Fetch related entities
      const user = await this.userRepository.findOne({
        where: { id: data.createdById }
      });
      if (!user) throw new NotFoundError('User', data.createdById);

      // 2. Create entity
      const audit = this.auditRepository.create({
        ...data,
        status: 'pending'
      });

      // 3. Save to database
      const saved = await this.auditRepository.save(audit);

      // 4. Log operation
      logger.info('Audit created', { auditId: saved.id });

      return saved;
    } catch (error) {
      logger.error('Error creating audit', { error });
      if (error instanceof NotFoundError) throw error;
      throw new DatabaseError('Failed to create audit');
    }
  }
}
```

#### Middleware Pattern

```typescript
// middleware/auth.middleware.ts
export const authMiddleware = (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    // 1. Extract token from header
    const token = extractToken(req);
    if (!token) throw new UnauthorizedError('No token');

    // 2. Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // 3. Attach to request
    req.userId = decoded.userId;
    req.user = decoded;

    next();
  } catch (error) {
    next(new UnauthorizedError('Invalid token'));
  }
};

export const requireRole = (...roles: string[]) => {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return next(new ForbiddenError('Insufficient permissions'));
    }
    next();
  };
};
```

#### Route Registration Pattern

```typescript
// routes/audit.routes.ts
const router = Router();
const controller = new AuditController();

// Public endpoint (optional auth)
router.get('/:id', optionalAuth, (req, res, next) =>
  controller.getAudit(req, res, next)
);

// Protected endpoint (auth required)
router.post('/', authMiddleware, (req, res, next) =>
  controller.createAudit(req, res, next)
);

// Role-based protected endpoint
router.delete('/:id', authMiddleware, requireRole('admin'), (req, res, next) =>
  controller.deleteAudit(req, res, next)
);
```

## Error Handling

### Using Custom Errors

```typescript
// Bad: throw generic Error
throw new Error('Something went wrong');

// Good: throw specific error
throw new NotFoundError('Audit', id);
throw new ValidationError('Invalid email format');
throw new ForbiddenError('Only admin can delete');
```

### Error Response Format

All endpoints return consistent error format:

```json
{
  "code": "ERROR_CODE",
  "message": "Human readable message",
  "details": { "field": "value" },
  "timestamp": "2024-01-15T10:30:00Z",
  "requestId": "uuid-for-tracing"
}
```

### HTTP Status Codes

| Status | When | Example |
|--------|------|---------|
| 400 | Validation error | `ValidationError('Invalid email')` |
| 401 | Not authenticated | `UnauthorizedError('No token')` |
| 403 | Insufficient permissions | `ForbiddenError('Admin only')` |
| 404 | Resource not found | `NotFoundError('Audit', id)` |
| 409 | Conflict (duplicate) | `ConflictError('Email exists')` |
| 500 | Server error | `DatabaseError('Query failed')` |

## Logging

### Log Levels

```typescript
logger.error('Critical error', { error, stack });    // 0 (always logged)
logger.warn('Warning message', { details });         // 1 (production default)
logger.info('Info message', { userId, action });     // 2 (development default)
logger.debug('Debug details', { query, result });    // 3 (verbose)
```

### Logging Best Practices

```typescript
// Always include context
logger.info('Audit created', {
  auditId: audit.id,           // What
  repositoryId: repository.id,  // Where
  userId: req.userId,           // Who
  requestId: req.requestId,     // For tracing
  duration: endTime - startTime, // How long
});

// Log errors with details
logger.error('Database error', {
  code: error.code,
  message: error.message,
  details: error.detail,
  query: error.query,
  stack: error.stack,
});
```

### Viewing Logs

```bash
# Development: console + file
npm run dev  # Output shows in terminal

# File logging
tail -f logs/app.log                    # Real-time
grep "Audit created" logs/app.log       # Search
grep "ERROR" logs/error.log             # Errors only
tail -n 100 logs/app.log | less         # Last 100 lines
```

## Authentication & Authorization

### Obtaining Tokens

Tokens are typically obtained via GitHub OAuth (not implemented in template):

1. User clicks "Login with GitHub"
2. Frontend redirects to `/auth/github`
3. User authorizes on GitHub
4. Backend exchanges code for access token
5. Backend issues JWT tokens

For testing:

```bash
# Generate test token (valid for 1 hour)
curl -X POST http://localhost:3000/api/v1/auth/test-token \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-id",
    "email": "test@example.com",
    "role": "auditor"
  }'
```

### Using Tokens

```bash
# Include in Authorization header
curl -H "Authorization: Bearer eyJ..." http://localhost:3000/api/v1/audits
```

### Token Structure

```javascript
// JWT payload (decoded)
{
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "role": "auditor",  // admin, auditor, developer, viewer
  "iat": 1234567890,  // Issued at
  "exp": 1234568890   // Expires at (15 minutes)
}
```

## Testing Guide

### Running Tests

```bash
npm test                     # All tests, once
npm run test:watch          # Watch mode
npm run test:coverage       # Coverage report
npm test -- --verbose       # Verbose output
```

### Test Coverage

Current: Must maintain >80% coverage

```bash
# View report after npm run test:coverage
open coverage/lcov-report/index.html
```

### Writing Integration Tests

```typescript
describe('Audit API', () => {
  let app: App;
  let authToken: string;

  beforeAll(async () => {
    app = new App();
    // Setup test database & data
    authToken = createTestToken();
  });

  it('should create audit', async () => {
    const res = await request(app.getExpressApp())
      .post('/api/v1/audits')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ repositoryId: '...', type: 'security' });

    expect(res.status).toBe(201);
    expect(res.body.data.type).toBe('security');
  });
});
```

## Debugging

### Visual Studio Code

1. Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "Launch Server",
      "skipFiles": ["<node_internals>/**"],
      "program": "${workspaceFolder}/node_modules/tsx/dist/cli.mjs",
      "args": ["watch", "src/main.ts"]
    }
  ]
}
```

2. Press F5 to start debugging

### Chrome DevTools

```bash
node --inspect-brk dist/src/main.js
```

Then open `chrome://inspect` in Chrome

### Common Issues

#### "Cannot find module '@config/logger'"

Path alias not working. Try:

```bash
npm run build
npm start  # Use compiled version
```

#### Database connection timeout

```bash
# Check PostgreSQL
psql -U postgres -h localhost

# Check .env
cat .env | grep DB_

# View logs
tail logs/error.log
```

#### Port 3000 in use

```bash
# Find process
lsof -i :3000

# Kill it
kill -9 <PID>
```

#### Tests failing

```bash
# Ensure database is running
docker-compose ps

# Clear & rebuild
rm -rf dist node_modules
npm install
npm test
```

## Deployment Preparation

Before deploying to production:

1. **Environment variables** - Set all production values
2. **Database** - Run migrations on production DB
3. **Secrets** - Regenerate JWT secrets
4. **Tests** - All tests passing
5. **Build** - `npm run build` succeeds
6. **Linting** - `npm run lint` passes
7. **Coverage** - Meets >80% threshold

## Resources

- [Express.js Docs](https://expressjs.com/)
- [TypeORM Docs](https://typeorm.io/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [JWT Best Practices](https://tools.ietf.org/html/rfc7519)
- [REST API Design](https://restfulapi.net/)

## Getting Help

1. Check logs: `tail logs/error.log`
2. Check [BACKEND_DOCUMENTATION.md](./BACKEND_DOCUMENTATION.md)
3. Review existing tests for examples
4. Check API spec: `../PORTAL_API_v1.0.yml`
