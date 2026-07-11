# API Security — Detail Reference

## OWASP API Security Top 10 (2023) Coverage

| # | Vulnerability | Key Tests |
|---|---|---|
| API1 | Broken Object Level Authorization (BOLA) | Direct object references, cross-user access attempts |
| API2 | Broken Authentication | JWT validation, expired tokens, weak credentials |
| API3 | Broken Object Property Level Authorization (Mass Assignment) | Extra fields accepted in requests |
| API4 | Unrestricted Resource Consumption | Rate limit bypass, large payload handling |
| API5 | Broken Function Level Authorization | Admin endpoint access from non-admin users |
| API6 | Unrestricted Access to Sensitive Business Flows | Automated abuse of business logic flows |
| API7 | Server Side Request Forgery (SSRF) | Internal resource access via request parameters |
| API8 | Security Misconfiguration | Default credentials, debug endpoints, CORS policy |
| API9 | Improper Inventory Management | Shadow APIs, undocumented endpoints, version exposure |
| API10 | Unsafe Consumption of APIs | Trusting third-party API responses without validation |

## Threat Modeling (STRIDE for APIs)

| Threat | API Surface |
|---|---|
| Spoofing | Authentication bypass, JWT manipulation, impersonation |
| Tampering | Request body manipulation, parameter pollution, replay attacks |
| Repudiation | Insufficient audit logging, missing request IDs |
| Information Disclosure | Verbose errors, stack traces, PII in responses |
| Denial of Service | Rate limit bypass, resource exhaustion, regex DoS |
| Elevation of Privilege | BOLA, BFLA, insecure direct object references |

## Authentication and Authorization Patterns

OAuth2/OIDC validation checklist:

- `iss` (issuer) matches expected value
- `aud` (audience) matches this API
- `exp` (expiry) is in the future
- `scope` covers the requested operation
- Signature verification with trusted JWKS endpoint

RBAC audit:

- Roles assigned at group level, not individual user
- Principle of least privilege; no wildcard scopes
- Separate admin endpoints from user endpoints

## Rate Limiting Reference

| Pattern | Implementation |
|---|---|
| Per-user rate limiting | Token bucket or leaky bucket by user ID/API key |
| Per-endpoint rate limiting | Different limits for read vs write endpoints |
| Burst limiting | Allow short bursts; throttle sustained volume |
| Quota management | Daily/monthly quotas with 429 + Retry-After headers |

## Output Report Format

```yaml
api_security_assessment:
  scope: "<API name and version>"
  date: "<ISO date>"
  owasp_findings:
    - id: "API1"
      title: "BOLA - Broken Object Level Authorization"
      severity: "critical | high | medium | low"
      affected_endpoints: ["/users/{id}", "/orders/{id}"]
      cvss_score: 9.1
      remediation: "<specific fix>"
  threat_model:
    attack_surface: [...]
    data_flows: [...]
  auth_review:
    jwt_validation: "pass | fail"
    rbac_enforcement: "pass | fail"
  recommendations: [...]
  risk_rating: "critical | high | medium | low"
```
