# Security Analyst Agent — Detail Reference

Full OWASP Top 10 review table, STRIDE threat modeling guidance, secret scanning patterns,
dependency vulnerability assessment steps, secure coding checklist, and issue-filing table
for `agents/basecoat-50-security-security-analyst.agent.md`.

## OWASP Top 10 Review

Evaluate each category and document the result:

| # | Category | Focus Areas |
|---|---|---|
| A01 | Broken Access Control | Missing auth checks, IDOR, privilege escalation, CORS misconfiguration |
| A02 | Cryptographic Failures | Weak algorithms, plaintext secrets, missing TLS, improper key management |
| A03 | Injection | SQL injection, NoSQL injection, OS command injection, LDAP injection |
| A04 | Insecure Design | Missing threat model, no rate limiting, no abuse-case testing |
| A05 | Security Misconfiguration | Default credentials, verbose errors, unnecessary features enabled |
| A06 | Vulnerable Components | Outdated dependencies, known CVEs, unmaintained libraries |
| A07 | Auth Failures | Weak passwords allowed, missing MFA, session fixation, brute-force exposure |
| A08 | Data Integrity Failures | Unsigned updates, deserialization of untrusted data, CI/CD pipeline tampering |
| A09 | Logging & Monitoring Failures | Missing audit logs, no alerting on auth failures, PII in logs |
| A10 | SSRF | Unvalidated URLs, internal network access via user-supplied URLs |

## STRIDE Threat Modeling

For each component or trust boundary, evaluate:

- **S**poofing — Can an attacker impersonate a user, service, or component?
- **T**ampering — Can data in transit or at rest be modified without detection?
- **R**epudiation — Can actions be performed without an audit trail?
- **I**nformation Disclosure — Can sensitive data leak through errors, logs, or side channels?
- **D**enial of Service — Can the system be overwhelmed or made unavailable?
- **E**levation of Privilege — Can a low-privilege user gain higher access?

Document each threat with likelihood, impact, and recommended mitigation.

## Secret Scanning

Search for patterns including but not limited to:

- API keys and tokens (AWS, Azure, GCP, Stripe, Twilio, etc.)
- Private keys (RSA, SSH, PGP)
- Database connection strings with embedded credentials
- `.env` files committed to source control
- Hardcoded passwords or passphrases in source code
- JWT signing secrets

Any finding is automatically **Critical** severity.

## Dependency Vulnerability Assessment

- Parse all dependency manifests in the repository.
- Cross-reference each dependency and version against known CVE databases.
- Flag transitive dependencies with known vulnerabilities.
- Recommend pinning, upgrading, or replacing vulnerable packages.
- Document findings using `skills/security/dependency-audit-template.md`.

## Secure Coding Checklist

- [ ] All endpoints enforce authentication and authorization explicitly.
- [ ] All database queries use parameterized statements or ORM binding.
- [ ] All user input is validated and sanitized at the boundary.
- [ ] Output encoding is applied to prevent XSS.
- [ ] Secrets are loaded from environment variables or a secrets manager — never hardcoded.
- [ ] Error responses do not leak stack traces, internal paths, or implementation details.
- [ ] CORS is configured to specific origins — no wildcard in production.
- [ ] Rate limiting is applied to authentication and sensitive endpoints.
- [ ] HTTPS/TLS is enforced for all external communication.
- [ ] Security headers are set: CSP, X-Content-Type-Options, X-Frame-Options, Strict-Transport-Security.
- [ ] Session tokens are rotated on privilege changes and have appropriate expiry.
- [ ] File uploads validate type, size, and content — never trust the extension alone.

## GitHub Issue Filing Table

File a GitHub Issue immediately when any of the following are discovered. Do not defer. Use the shared command template in `agents/references/issue-filing-pattern.md` with:

- **Title prefix:** `[Security]`
- **Base labels:** `security,vulnerability`
- **Severity:** `<Critical | High | Medium | Low>`
- **OWASP Category:** `<A01–A10 or N/A>`
- **STRIDE Category:** `<Spoofing | Tampering | Repudiation | Information Disclosure | Denial of Service | Elevation of Privilege | N/A>`
- **File:** `<path/to/file.ext>`
- **Line(s):** `<line range>`
- **Description** must cover the attack vector, not just the observation.
- **Extra body section (in addition to the shared template):**
  - `### Proof of Concept` — steps to reproduce or exploit, if applicable.

| Finding | Severity | Labels |
|---|---|---|
| Hardcoded secret or credential | Critical | `security,vulnerability,critical` |
| SQL injection or command injection | Critical | `security,vulnerability,critical` |
| Missing authentication on a public endpoint | High | `security,vulnerability` |
| Missing authorization check (IDOR risk) | High | `security,vulnerability` |
| Dependency with known Critical/High CVE | High | `security,vulnerability,dependencies` |
| Missing input validation | Medium | `security,vulnerability` |
| Verbose error exposing internals | Medium | `security,vulnerability` |
| Missing security headers | Low | `security,vulnerability` |
| Outdated dependency without known CVE | Low | `security,tech-debt,dependencies` |
