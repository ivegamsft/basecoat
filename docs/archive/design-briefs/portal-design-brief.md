# Basecoat Portal: Design Brief

**Quick Reference for Portal Initiative Design**

## Vision
SaaS portal for automated repository audits, AI-powered recommendations, and GitHub issue management at enterprise scale (100+ concurrent users, 1000+ repositories).

## Core Requirements

### Functional
- **Multi-tenant SaaS**: Secure org-level isolation, row-level security
- **Audit Engine**: Pluggable analyzers (security, best-practices, dependencies)
- **Recommendation Engine**: AI-powered suggestions with priority ranking
- **GitHub Integration**: OAuth, webhooks, auto-file issues
- **Dashboard**: Audit results, findings, recommendations, issue status
- **API**: REST API with rate limiting, pagination, filtering

### Non-Functional
- **Scalability**: 100+ concurrent users, 1000+ repos, async job processing
- **Performance**: API latency p95 <500ms, dashboard <2s
- **Reliability**: 99.9% uptime (multi-AZ, failover)
- **Security**: GDPR compliance, SOC 2 readiness, GitHub OAuth
- **Accessibility**: WCAG 2.1 AA (keyboard, screen reader, color contrast)

## Architecture Decision: Monolith (Phase 1-2)
**Recommendation**: Single Express.js/FastAPI service with clear service boundaries  
**Rationale**: Simpler deployment, easier debugging, reduced DevOps overhead initially  
**Migration Path**: Separate into microservices (audit svc, recommendation svc, GitHub integrator) if needed in Phase 3+

## Design Phases

### Phase 1: Architecture + API + Data (3 days, 3 agents)
- **Agent #3 - solution-architect**:
  - C4 system architecture (4 levels)
  - Multi-tenancy + security model
  - Scaling strategy (1000+ repos)
  - Compliance checklist (GDPR, SOC 2)

- **Agent #4 - api-designer**:
  - OpenAPI 3.0 specification
  - REST endpoints (repos, audits, issues, recommendations)
  - Rate limiting & pagination model
  - Postman collection for testing

- **Agent #5 - data-tier**:
  - PostgreSQL schema (multi-tenant design)
  - Row-level security (RLS) policies
  - Indexing strategy + query optimization
  - Migrations strategy (zero-downtime)

### Phase 2: Backend Design (2 days, 2 agents)
- **Agent #6 - backend-dev**:
  - Framework selection (Express vs Fastify vs FastAPI)
  - Audit engine architecture (pluggable analyzers)
  - GitHub integration (OAuth, webhooks, rate limiting)
  - Async job processing (background audits, webhook handling)
  - Caching strategy (Redis)

- **Agent #7 - data-tier** (continued):
  - Query optimization guide (join patterns, aggregations)
  - Connection pooling & monitoring
  - Stored procedures (if needed)

### Phase 3: Frontend + DevOps (2 days, 2 agents)
- **Agent #8 - frontend-dev**:
  - UI framework selection (React vs Vue)
  - Component architecture (dashboard, audit results, recommendations)
  - Wireframes (repo list, findings detail, issue filing)
  - State management + accessibility (WCAG 2.1 AA)
  - Performance optimization (code splitting, lazy loading)

- **Agent #9 - devops-engineer**:
  - CI/CD pipeline (GitHub Actions)
  - Infrastructure architecture (IaC: Terraform/Bicep)
  - Observability (logs, metrics, alerts)
  - Backup & disaster recovery

## Key Deliverables

### Architecture
- C4 diagrams (system context → components → service boundaries → audit engine)
- Monolith vs microservices analysis (with Phase 3+ migration path)
- Multi-tenancy architecture (org isolation, RLS policies)
- Scaling strategy (horizontal scaling, caching, async jobs, database sharding prep)

### API
- OpenAPI 3.0 specification (complete, machine-readable)
- REST endpoints (repos, audits, findings, recommendations, issues)
- Rate limiting model (per-tenant, per-user)
- Postman collection

### Database
- PostgreSQL schema (organizations, repos, audit_runs, findings, recommendations, github_issues)
- ERD diagram showing relationships
- Indexing strategy + query plans
- Row-level security (RLS) policies
- Migration strategy (versioning, rollback, zero-downtime)

### Backend
- Framework selection (with comparison: performance, ecosystem, multi-tenancy patterns)
- Project structure (routes, services, models, middleware)
- Audit engine (pluggable analyzers: security, best-practices, dependencies)
- Recommendation engine (rule-based mapper, priority calculator)
- GitHub integration (OAuth app, webhook handler, rate limiting)
- Async job processing (background audits, webhook processing, reports)
- Caching strategy (query cache, audit result cache, recommendation cache)

### Frontend
- Framework selection (React vs Vue with comparison)
- Component architecture (Layout, RepoList, AuditDashboard, FindingsDetail, RecommendationCard)
- Wireframe requirements (dashboard, audit results, recommendations, issue filing)
- State management pattern (Zustand or Redux)
- WCAG 2.1 AA compliance checklist
- Performance targets (<300 KB main bundle)

### DevOps
- CI/CD pipeline (GitHub Actions: lint, test, docker build, staging deploy, production approval)
- Infrastructure as Code (Terraform or Bicep)
- Observability stack (logs, metrics, traces, alerts)
- Backup & disaster recovery (RTO <1h, RPO <1h)

## Estimated Data Scale

| Metric | Value |
|--------|-------|
| Repos | 1,000 |
| Audits per repo | 50 |
| Total audit runs | 50,000 |
| Findings per audit | 20 |
| Total findings | 1,000,000 |
| Estimated storage | 500 MB |
| Query latency target | <200 ms |

## Integration Points

1. **Frontend ↔ API**: OpenAPI spec drives component API calls
2. **API ↔ Database**: Schema supports all audit + recommendation queries
3. **Backend ↔ GitHub**: OAuth scoping, webhook validation, issue filing
4. **Backend ↔ Redis**: Cache warming, async job queue, rate limiting
5. **DevOps ↔ Backend**: CI/CD deploys container, observability ingests metrics

## Success Metrics

- ✅ Portal scales to 1000+ repos without re-architecture
- ✅ Multi-tenancy is enforced (RLS policies, no data leaks)
- ✅ API is complete, testable, and well-documented
- ✅ Audit engine is extensible (easy to add new analyzers)
- ✅ Frontend is WCAG 2.1 AA compliant
- ✅ DevOps stack is fully automated (one-click deployments)

## Timeline

- **Days 1-2**: Phase 1 (architecture + API + data)
- **Day 3**: Integration gate 1 (alignment review)
- **Days 3-4**: Phase 2 (backend design)
- **Day 4**: Integration gate 2 (backend alignment)
- **Days 5-6**: Phase 3 (frontend + DevOps)
- **Day 6**: Integration gate 3 (final alignment)
- **Day 7**: Final review + master architecture document
