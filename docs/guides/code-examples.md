# Code Examples for Identity & Access Control

Reference implementations for JWT validation, permission checking, and identity integration.

---

## 1. JWT Token Validation (Node.js)

### Setup & Dependencies

```bash
npm install jsonwebtoken axios
```

### Verify JWT Signature & Expiration

```javascript
const jwt = require('jsonwebtoken');
const fs = require('fs');

// Load public key (public key for RS256 verification)
const publicKey = fs.readFileSync('./keys/public.pem', 'utf8');

function verifyJWT(token) {
  try {
    const decoded = jwt.verify(token, publicKey, {
      algorithms: ['RS256'],
      issuer: 'https://portal.basecoat.dev',
      audience: 'basecoat-portal'
    });
    return decoded;
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw new Error('Token expired');
    }
    throw new Error('Invalid token signature');
  }
}

// Usage in middleware
app.use((req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing authorization header' });
  }

  const token = authHeader.substring(7);
  
  try {
    req.user = verifyJWT(token);
    next();
  } catch (error) {
    res.status(401).json({ error: error.message });
  }
});
```

---

## 2. Authorization Middleware

### Permission Checking

```javascript
function authorize(...requiredPermissions) {
  return (req, res, next) => {
    const userPermissions = req.user.permissions || [];
    
    // Check if user has at least one required permission
    const hasPermission = requiredPermissions.some(perm =>
      userPermissions.includes(perm)
    );

    if (!hasPermission) {
      // Log unauthorized attempt
      logAuditEvent({
        type: 'permission_denied',
        user_id: req.user.sub,
        required_permission: requiredPermissions,
        endpoint: req.path,
        ip_address: req.ip,
        timestamp: new Date()
      });

      return res.status(403).json({ 
        error: 'Insufficient permissions',
        required: requiredPermissions
      });
    }

    next();
  };
}

// Usage
app.get('/api/audits', authorize('read:audits'), async (req, res) => {
  // Fetch audits for user's organization
  const audits = await db.query(
    'SELECT * FROM audits WHERE org_id = $1',
    [req.user.org_id]
  );
  res.json(audits);
});
```

### Organization-Scoped Authorization

```javascript
function authorizeOrganization() {
  return (req, res, next) => {
    const requestedOrgId = req.params.org_id || req.body.org_id;
    
    // User can only access their own organization
    if (requestedOrgId !== req.user.org_id) {
      logAuditEvent({
        type: 'cross_org_access_attempted',
        user_id: req.user.sub,
        requested_org: requestedOrgId,
        user_org: req.user.org_id,
        ip_address: req.ip
      });

      return res.status(403).json({ error: 'Organization mismatch' });
    }

    next();
  };
}

// Usage
app.get('/api/org/:org_id/audits', 
  authorize('read:audits'),
  authorizeOrganization(),
  async (req, res) => {
    // Handler
  }
);
```

### Team-Scoped Authorization

```javascript
function authorizeTeam() {
  return async (req, res, next) => {
    const teamId = req.params.team_id;
    
    // Check if user is member of the team
    const teamMembership = await db.query(
      'SELECT * FROM team_members WHERE team_id = $1 AND user_id = $2',
      [teamId, req.user.sub]
    );

    if (!teamMembership.rows.length && !req.user.roles.includes('admin')) {
      return res.status(403).json({ error: 'Not a team member' });
    }

    req.teamId = teamId;
    next();
  };
}
```

---

## 3. GitHub OAuth Implementation

### OAuth Callback Handler

```javascript
const axios = require('axios');

app.get('/auth/callback', async (req, res) => {
  const { code, state } = req.query;
  
  // Validate CSRF state
  const storedState = await redis.get(`oauth_state_${state}`);
  if (!storedState) {
    return res.status(400).json({ error: 'Invalid state parameter' });
  }
  await redis.del(`oauth_state_${state}`);

  try {
    // Exchange code for access token
    const tokenResponse = await axios.post(
      'https://github.com/login/oauth/access_token',
      {
        client_id: process.env.GITHUB_CLIENT_ID,
        client_secret: process.env.GITHUB_CLIENT_SECRET,
        code: code,
        redirect_uri: 'https://portal.basecoat.dev/auth/callback'
      },
      { headers: { Accept: 'application/json' } }
    );

    const { access_token, error } = tokenResponse.data;
    if (error) {
      return res.status(400).json({ error: error });
    }

    // Fetch user profile
    const userResponse = await axios.get('https://api.github.com/user', {
      headers: { Authorization: `Bearer ${access_token}` }
    });

    const { login, id, email, name, avatar_url } = userResponse.data;

    // Fetch GitHub Teams for role mapping
    const orgsResponse = await axios.get('https://api.github.com/user/teams', {
      headers: { Authorization: `Bearer ${access_token}` }
    });

    // Map GitHub Teams to roles
    const roles = mapGitHubTeamsToRoles(orgsResponse.data);

    // Find or create portal user
    let user = await db.query(
      'SELECT * FROM users WHERE github_id = $1',
      [id]
    );

    if (!user.rows.length) {
      user = await db.query(
        `INSERT INTO users 
         (email, name, avatar_url, github_login, github_id, roles, org_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [email, name, avatar_url, login, id, roles.join(','), determineOrgId(login)]
      );
    } else {
      // Update roles and last login
      await db.query(
        'UPDATE users SET roles = $1, last_login = NOW() WHERE github_id = $2',
        [roles.join(','), id]
      );
    }

    // Create JWT token
    const jwtToken = jwt.sign(
      {
        sub: user.rows[0].user_id,
        email: user.rows[0].email,
        name: user.rows[0].name,
        github_login: login,
        org_id: user.rows[0].org_id,
        roles: roles,
        permissions: getPermissionsFromRoles(roles),
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + (15 * 60)
      },
      fs.readFileSync('./keys/private.pem', 'utf8'),
      { algorithm: 'RS256' }
    );

    // Create refresh token
    const refreshToken = crypto.randomBytes(32).toString('hex');
    await redis.setex(
      `refresh_${user.rows[0].user_id}`,
      30 * 24 * 60 * 60, // 30 days
      refreshToken
    );

    // Log successful login
    logAuditEvent({
      type: 'user_login',
      user_id: user.rows[0].user_id,
      auth_method: 'github_oauth',
      ip_address: req.ip,
      user_agent: req.headers['user-agent'],
      timestamp: new Date()
    });

    // Set secure cookie with refresh token
    res.setHeader('Set-Cookie', `refresh_token=${refreshToken}; 
      HttpOnly; 
      Secure; 
      SameSite=Strict; 
      Path=/auth; 
      Max-Age=${30 * 24 * 60 * 60}`
    );

    // Return JWT in response body and redirect
    res.json({
      access_token: jwtToken,
      token_type: 'Bearer',
      expires_in: 900
    });

  } catch (error) {
    console.error('OAuth error:', error);
    res.status(500).json({ error: 'Authentication failed' });
  }
});
```

---

## 4. Token Refresh Handler

```javascript
app.post('/auth/refresh', async (req, res) => {
  const refreshToken = req.cookies.refresh_token;

  if (!refreshToken) {
    return res.status(401).json({ error: 'Missing refresh token' });
  }

  try {
    // Verify refresh token exists in Redis
    const userId = await redis.get(`refresh_${refreshToken}`);
    
    if (!userId) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    // Fetch user from database
    const user = await db.query(
      'SELECT * FROM users WHERE user_id = $1',
      [userId]
    );

    if (!user.rows.length) {
      return res.status(401).json({ error: 'User not found' });
    }

    // Create new JWT token
    const newJWT = jwt.sign(
      {
        sub: user.rows[0].user_id,
        email: user.rows[0].email,
        org_id: user.rows[0].org_id,
        roles: user.rows[0].roles.split(','),
        permissions: getPermissionsFromRoles(user.rows[0].roles.split(',')),
        exp: Math.floor(Date.now() / 1000) + (15 * 60)
      },
      fs.readFileSync('./keys/private.pem', 'utf8'),
      { algorithm: 'RS256' }
    );

    logAuditEvent({
      type: 'token_refresh',
      user_id: userId,
      ip_address: req.ip,
      timestamp: new Date()
    });

    res.json({
      access_token: newJWT,
      token_type: 'Bearer',
      expires_in: 900
    });

  } catch (error) {
    res.status(500).json({ error: 'Token refresh failed' });
  }
});
```

---

## 5. Service Account / API Key Validation

```javascript
async function validateApiKey(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing API key' });
  }

  const apiKey = authHeader.substring(7);
  const keyId = req.headers['x-api-key-id'];

  try {
    // Fetch API key from database (hashed)
    const result = await db.query(
      'SELECT * FROM api_keys WHERE key_id = $1 AND revoked_at IS NULL',
      [keyId]
    );

    if (!result.rows.length) {
      logAuditEvent({
        type: 'invalid_api_key',
        key_id: keyId,
        ip_address: req.ip,
        timestamp: new Date()
      });
      return res.status(401).json({ error: 'Invalid API key' });
    }

    const storedKey = result.rows[0];

    // Verify key hash
    const crypto = require('crypto');
    const keyHash = crypto.createHash('sha256').update(apiKey).digest('hex');

    if (keyHash !== storedKey.key_hash) {
      return res.status(401).json({ error: 'Invalid API key' });
    }

    // Check expiration
    if (storedKey.expires_at < new Date()) {
      return res.status(401).json({ error: 'API key expired' });
    }

    // Attach key info to request
    req.apiKey = {
      key_id: keyId,
      org_id: storedKey.org_id,
      scopes: storedKey.scopes.split(','),
      user_id: storedKey.user_id
    };

    // Log API access
    logAuditEvent({
      type: 'api_access',
      key_id: keyId,
      org_id: storedKey.org_id,
      endpoint: req.path,
      ip_address: req.ip,
      timestamp: new Date()
    });

    next();

  } catch (error) {
    res.status(500).json({ error: 'API key validation failed' });
  }
}

// Usage: Require specific API key scope
app.get('/api/audits', (req, res, next) => {
  if (req.apiKey && !req.apiKey.scopes.includes('read:audits')) {
    return res.status(403).json({ error: 'API key lacks read:audits scope' });
  }
  next();
}, validateApiKey, async (req, res) => {
  // Handler
});
```

---

## 6. Audit Logging

```javascript
async function logAuditEvent(event) {
  const { type, user_id, actor_id, subject_id, ...details } = event;

  try {
    await db.query(
      `INSERT INTO audit_events
       (event_id, org_id, event_type, actor_id, subject_id, action_detail, ip_address, timestamp)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        crypto.randomUUID(),
        event.org_id,
        type,
        event.actor_id,
        event.subject_id,
        JSON.stringify(details),
        event.ip_address,
        new Date()
      ]
    );
  } catch (error) {
    console.error('Failed to log audit event:', error);
    // Don't fail the request; audit failure should not block application
  }
}
```

---

**Version**: 1.0  
**Last Updated**: 2025  
