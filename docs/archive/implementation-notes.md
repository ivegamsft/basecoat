# Basecoat Portal API — Implementation Notes

**Version:** 1.0.0
**Target:** Backend Development Team
**Deadline:** May 5, 2024

---

## Quick Start

This document guides backend developers through implementing the Basecoat Portal API. Refer to `PORTAL_API_v1.0.yml` for the complete OpenAPI 3.0 specification.

**Key Implementation Priorities:**
1. Authentication & Authorization (JWT + OAuth 2.0)
2. Team and Repository management CRUD
3. Audit execution and finding collection
4. Compliance policy tracking
5. Pagination and bulk operations
6. Rate limiting and error handling
7. Audit logging and monitoring

---

## Architecture Overview

```
┌─────────────┐
│   Clients   │
│ (Web, CLI)  │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────────────┐
│  API Gateway            │
│  (Rate Limiting, Logs)  │
└──────────┬──────────────┘
           │
    ┌──────┴──────┐
    ▼             ▼
┌─────────────────────────┐
│ Auth Service            │ ◄─── JWT Validation
│                         │
│ Endpoints:              │
│ • POST /auth/login      │
│ • POST /auth/refresh    │
│ • POST /auth/logout     │
└─────────────────────────┘
           │
    ┌──────┴────────────────────────┐
    ▼                               ▼
┌─────────────────┐      ┌─────────────────────┐
│ Business Logic  │      │  Data Layer         │
│ Services        │      │                     │
│                 │      │ • Teams DB          │
│ • TeamService   │      │ • Repositories DB   │
│ • AuditService  │      │ • Audits DB         │
│ • ReportService │      │ • Findings DB       │
└─────────────────┘      │ • Compliance DB     │
           │             │ • Events Log        │
           │             └─────────────────────┘
           │                     ▲
           └─────────────────────┘
                   │
      ┌────────────┴──────────────┐
      ▼                           ▼
┌──────────────────┐    ┌──────────────────┐
│ External Systems │    │ Message Queue    │
│                  │    │ (Audit Jobs)     │
│ • GitHub API     │    │                  │
│ • OAuth Provider │    │ • Scan Requests  │
│ • Analytics      │    │ • Report Gen     │
└──────────────────┘    └──────────────────┘
```

---

## Authentication Implementation

### JWT Token Structure

All tokens must follow this structure:

```json
{
  "sub": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "name": "John Doe",
  "role": "admin",
  "org": "org-123",
  "iat": 1672531200,
  "exp": 1672534800,
  "iss": "https://api.basecoat.dev",
  "aud": "basecoat-portal"
}
```

### Required Libraries

**Node.js:**
```bash
npm install jsonwebtoken bcryptjs dotenv
```

**Python:**
```bash
pip install PyJWT bcrypt python-dotenv
```

### Implementation Pattern (Node.js)

```javascript
// auth.service.js
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

class AuthService {
  async login(email, password) {
    // 1. Find user by email
    const user = await User.findByEmail(email);
    if (!user) throw new Error('AUTH_INVALID_CREDENTIALS');

    // 2. Verify password
    const isValid = await bcrypt.compare(password, user.passwordHash);
    if (!isValid) throw new Error('AUTH_INVALID_CREDENTIALS');

    // 3. Generate JWT
    const token = jwt.sign(
      {
        sub: user.id,
        email: user.email,
        role: user.role,
        org: user.organizationId
      },
      process.env.JWT_SECRET,
      { expiresIn: '1h', issuer: 'basecoat-api' }
    );

    return { token, user, expiresIn: 3600 };
  }

  async validateToken(token) {
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET, {
        issuer: 'basecoat-api'
      });
      return decoded;
    } catch (err) {
      throw new Error('AUTH_UNAUTHORIZED');
    }
  }

  async refreshToken(oldToken) {
    const decoded = jwt.decode(oldToken); // Don't verify, just decode
    if (!decoded) throw new Error('AUTH_UNAUTHORIZED');

    // Verify we can still access the user
    const user = await User.findById(decoded.sub);
    if (!user) throw new Error('AUTH_UNAUTHORIZED');

    // Issue new token
    const newToken = jwt.sign(
      {
        sub: user.id,
        email: user.email,
        role: user.role,
        org: user.organizationId
      },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );

    return { token: newToken, expiresIn: 3600 };
  }
}

module.exports = AuthService;
```

### Middleware Pattern

```javascript
// auth.middleware.js
async function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      code: 'AUTH_UNAUTHORIZED',
      message: 'Missing or invalid authorization header',
      timestamp: new Date().toISOString()
    });
  }

  const token = authHeader.substring(7);
  try {
    const decoded = await authService.validateToken(token);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({
      code: 'AUTH_UNAUTHORIZED',
      message: 'Invalid or expired token',
      timestamp: new Date().toISOString()
    });
  }
}

module.exports = authMiddleware;
```

---

## Authorization Implementation

### RBAC Decorator Pattern

```javascript
// rbac.decorator.js
function requireRole(...roles) {
  return function (target, propertyKey, descriptor) {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args) {
      const req = args[0];
      if (!req.user) {
        throw new Error('AUTH_UNAUTHORIZED');
      }

      if (!roles.includes(req.user.role)) {
        throw new Error('INSUFFICIENT_PERMISSIONS');
      }

      return originalMethod.apply(this, args);
    };

    return descriptor;
  };
}

// Usage:
// @requireRole('admin', 'auditor')
// async createAudit(req, res) { ... }
```

### Per-Endpoint Permission Check

```javascript
// teams.controller.js
async function addTeamMember(req, res) {
  const { teamId } = req.params;
  const { userId, role } = req.body;

  // Permission check: user must be team owner or admin
  const team = await Team.findById(teamId);
  if (!team) return res.status(404).json({ code: 'RESOURCE_NOT_FOUND' });

  const isOwner = team.members.some(m => m.userId === req.user.sub && m.role === 'owner');
  const isAdmin = req.user.role === 'admin';

  if (!isOwner && !isAdmin) {
    return res.status(403).json({
      code: 'INSUFFICIENT_PERMISSIONS',
      message: 'Only team owners and admins can add members'
    });
  }

  // Proceed with add logic...
}
```

---

## Pagination Implementation

### Strategy: Offset-Based with Cursor Support

Use offset/limit for simple pagination; cursors for stable high-throughput access.

### Implementation Pattern

```javascript
async function listRepositories(req, res) {
  const limit = Math.min(parseInt(req.query.limit) || 20, 100);
  const offset = parseInt(req.query.offset) || 0;
  const cursor = req.query.cursor; // Optional: cursor-based pagination

  let query = Repository.query();

  // Apply filters
  if (req.query.team) {
    query = query.where('team', req.query.team);
  }

  // Pagination
  let items, total;

  if (cursor) {
    // Cursor-based: more stable for real-time data
    items = await query
      .where('id', '>', cursor)
      .limit(limit + 1)
      .select();

    const hasMore = items.length > limit;
    items = items.slice(0, limit);

    return res.json({
      items,
      pagination: {
        hasMore,
        nextCursor: items[items.length - 1]?.id || null
      }
    });
  } else {
    // Offset-based: simple pagination
    total = await query.count();
    items = await query
      .offset(offset)
      .limit(limit)
      .select();

    return res.json({
      items,
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + items.length < total
      }
    });
  }
}
```

### Response Format

```json
{
  "items": [...],
  "pagination": {
    "total": 150,
    "limit": 20,
    "offset": 0,
    "hasMore": true
  }
}
```

---

## Bulk Operations

### Batch Audit Creation

**Endpoint:** `POST /audits/batch`

**Implementation:**
```javascript
async function createAuditBatch(req, res) {
  const { audits } = req.body;

  // Validate batch size
  if (!audits || audits.length < 1 || audits.length > 100) {
    return res.status(400).json({
      code: 'VALIDATION_ERROR',
      message: 'Batch size must be between 1 and 100',
      details: { maxBatchSize: 100 }
    });
  }

  const created = [];
  const failed = [];

  // Process in parallel (with concurrency limit)
  const results = await Promise.allSettled(
    audits.map(audit => this.createAudit(audit, req.user))
  );

  results.forEach((result, index) => {
    if (result.status === 'fulfilled') {
      created.push(result.value);
    } else {
      failed.push({
        index,
        repositoryId: audits[index].repositoryId,
        error: result.reason.message
      });
    }
  });

  // Enqueue created audits for processing
  created.forEach(audit => {
    this.auditQueue.enqueue({
      auditId: audit.id,
      type: audit.type
    });
  });

  res.status(201).json({ created, failed });
}
```

---

## Error Handling

### Standardized Error Response

All errors must return this structure:

```javascript
{
  code: string,           // Machine-readable code (e.g., AUTH_UNAUTHORIZED)
  message: string,        // Human-readable message
  details?: object,       // Optional: additional context
  timestamp: ISO8601,     // When error occurred
  requestId: string       // For debugging
}
```

### Error Handler Middleware

```javascript
// errorHandler.middleware.js
function errorHandler(err, req, res, next) {
  const requestId = req.id || 'unknown';
  const timestamp = new Date().toISOString();

  // Map error codes to HTTP status
  const statusMap = {
    AUTH_UNAUTHORIZED: 401,
    AUTH_INVALID_CREDENTIALS: 401,
    INSUFFICIENT_PERMISSIONS: 403,
    RESOURCE_NOT_FOUND: 404,
    CONFLICT_DUPLICATE: 409,
    VALIDATION_ERROR: 400,
    RATE_LIMIT_EXCEEDED: 429,
    INTERNAL_ERROR: 500
  };

  const status = statusMap[err.code] || 500;
  const code = err.code || 'INTERNAL_ERROR';

  // Log error for debugging
  console.error(`[${requestId}] ${code}:`, err);

  res.status(status).json({
    code,
    message: err.message || 'An error occurred',
    details: err.details || {},
    timestamp,
    requestId
  });
}

module.exports = errorHandler;
```

### Throwing Custom Errors

```javascript
class AppError extends Error {
  constructor(code, message, statusCode, details) {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
  }
}

// Usage:
if (!user) {
  throw new AppError(
    'RESOURCE_NOT_FOUND',
    'User not found',
    404
  );
}

if (!hasPermission) {
  throw new AppError(
    'INSUFFICIENT_PERMISSIONS',
    'You do not have permission to perform this action',
    403,
    { requiredRole: 'admin' }
  );
}
```

---

## Rate Limiting

### Implementation with Redis

```bash
npm install redis rate-limiter-flexible
```

```javascript
// rateLimiter.middleware.js
const { RateLimiterRedis } = require('rate-limiter-flexible');
const redis = require('redis');

const redisClient = redis.createClient({ host: 'localhost', port: 6379 });

const rateLimiter = new RateLimiterRedis({
  storeClient: redisClient,
  keyPrefix: 'rl:',
  points: 500,                    // Number of points
  duration: 60,                   // Per 60 seconds
  blockDurationSeconds: 60        // Block for 60 seconds
});

async function rateLimitMiddleware(req, res, next) {
  try {
    // Rate limit by user ID or IP
    const key = req.user?.sub || req.ip;
    const rateLimiterRes = await rateLimiter.consume(key, 1);

    res.set('X-Rate-Limit-Limit', rateLimiter.points);
    res.set('X-Rate-Limit-Remaining', rateLimiterRes.remainingPoints);
    res.set('X-Rate-Limit-Reset', 
      new Date(Date.now() + rateLimiterRes.msBeforeNext).toISOString());

    next();
  } catch (rateLimiterRes) {
    res.status(429).set('Retry-After', 
      Math.round(rateLimiterRes.msBeforeNext / 1000));
    res.json({
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'You have exceeded your request quota',
      retryAfter: Math.round(rateLimiterRes.msBeforeNext / 1000),
      timestamp: new Date().toISOString()
    });
  }
}

module.exports = rateLimitMiddleware;
```

---

## Audit Execution

### Audit Job Processing

```javascript
// audit.queue.js
const Queue = require('bull');
const { AuditService } = require('./audit.service');

const auditQueue = new Queue('audits', {
  redis: { host: 'localhost', port: 6379 }
});

auditQueue.process(10, async (job) => {
  const { auditId, type } = job.data;

  try {
    // Update status to in_progress
    await Audit.updateStatus(auditId, 'in_progress');

    // Execute scan based on type
    const findings = await executeAuditScan(type, job);

    // Save findings
    await Finding.insertMany(findings.map(f => ({
      auditId,
      ...f
    })));

    // Update status to completed
    await Audit.updateStatus(auditId, 'completed', {
      completedAt: new Date()
    });

    return { auditId, findingsCount: findings.length };
  } catch (err) {
    console.error(`Audit ${auditId} failed:`, err);
    await Audit.updateStatus(auditId, 'failed', {
      error: err.message,
      completedAt: new Date()
    });
    throw err;
  }
});

auditQueue.on('completed', (job) => {
  console.log(`Audit ${job.data.auditId} completed`);
  // Emit webhook or send notification
});

module.exports = auditQueue;
```

---

## Database Schema

### Teams Table
```sql
CREATE TABLE teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  organization_id UUID NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_org_id (organization_id)
);

CREATE TABLE team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES teams(id),
  user_id UUID NOT NULL,
  role VARCHAR(50) NOT NULL DEFAULT 'member',
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(team_id, user_id),
  INDEX idx_team_id (team_id)
);
```

### Repositories Table
```sql
CREATE TABLE repositories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  url VARCHAR(1000) NOT NULL UNIQUE,
  team_id UUID NOT NULL REFERENCES teams(id),
  is_private BOOLEAN DEFAULT true,
  language VARCHAR(100),
  compliance_level VARCHAR(50),
  last_audit_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_team_id (team_id),
  INDEX idx_compliance (compliance_level)
);
```

### Audits & Findings Tables
```sql
CREATE TABLE audits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  repository_id UUID NOT NULL REFERENCES repositories(id),
  type VARCHAR(50) NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP,
  INDEX idx_repo_id (repository_id),
  INDEX idx_status (status)
);

CREATE TABLE findings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id UUID NOT NULL REFERENCES audits(id),
  severity VARCHAR(50) NOT NULL,
  category VARCHAR(255),
  description TEXT NOT NULL,
  remediation TEXT,
  status VARCHAR(50) DEFAULT 'open',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_id (audit_id),
  INDEX idx_severity (severity)
);
```

---

## Testing Strategy

### Unit Tests (Jest)

```javascript
// __tests__/auth.service.test.js
describe('AuthService', () => {
  describe('login', () => {
    it('should return token on valid credentials', async () => {
      const user = await authService.login('user@example.com', 'pass123');
      expect(user.token).toBeDefined();
      expect(user.expiresIn).toBe(3600);
    });

    it('should throw AUTH_INVALID_CREDENTIALS on invalid password', async () => {
      await expect(() => 
        authService.login('user@example.com', 'wrongpass')
      ).rejects.toThrow('AUTH_INVALID_CREDENTIALS');
    });
  });
});
```

### Integration Tests

```javascript
// __tests__/auth.integration.test.js
describe('POST /auth/login', () => {
  it('should return 200 with valid credentials', async () => {
    const res = await request(app)
      .post('/v1/auth/login')
      .send({ email: 'user@example.com', password: 'pass123' });

    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
  });

  it('should return 401 with invalid credentials', async () => {
    const res = await request(app)
      .post('/v1/auth/login')
      .send({ email: 'user@example.com', password: 'wrongpass' });

    expect(res.status).toBe(401);
    expect(res.body.code).toBe('AUTH_INVALID_CREDENTIALS');
  });
});
```

---

## Deployment Checklist

- [ ] All endpoints implemented per OpenAPI spec
- [ ] JWT authentication validates on all protected endpoints
- [ ] Rate limiting enforced (500 req/min per user)
- [ ] Database migrations applied
- [ ] Redis deployed for caching and rate limiting
- [ ] Message queue (Bull/RabbitMQ) operational for audit jobs
- [ ] Error responses follow standard format
- [ ] Pagination implemented on all list endpoints
- [ ] Batch operations tested with 100+ items
- [ ] Unit test coverage > 80%
- [ ] Integration tests passing
- [ ] Load testing completed (1000+ concurrent requests)
- [ ] API documentation deployed
- [ ] SSL certificates configured
- [ ] Monitoring and alerting configured
- [ ] Health check endpoint implemented (`GET /health`)

---

## Configuration

### Environment Variables

```bash
# JWT
JWT_SECRET=your-secret-key-min-32-chars
JWT_EXPIRY=3600

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=basecoat_api
DB_USER=api_user
DB_PASSWORD=secure_password

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=redis_password

# GitHub OAuth
GITHUB_CLIENT_ID=your-client-id
GITHUB_CLIENT_SECRET=your-client-secret

# Rate Limiting
RATE_LIMIT_POINTS=500
RATE_LIMIT_DURATION=60

# Logging
LOG_LEVEL=info
LOG_FORMAT=json
```

---

## Support & References

- **OpenAPI Spec:** See `PORTAL_API_v1.0.yml`
- **API Documentation:** See `API_DOCUMENTATION.md`
- **GitHub Issues:** https://github.com/IBuySpy-Shared/basecoat/issues
- **Contact:** api-support@basecoat.dev
