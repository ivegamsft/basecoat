# Basecoat Portal Architecture v1.0

## Executive Summary

The Basecoat Portal is an enterprise governance, security audit, and compliance platform designed to serve 100-1000+ concurrent users across multi-region cloud deployments. This document outlines the complete system architecture, deployment topology, scalability strategy, and disaster recovery plan to support Basecoat's governance mission.

**Key Characteristics:**
- **Scale**: 100-1000+ concurrent users with burst capacity to 2000+
- **Availability**: 99.99% uptime SLA (RTO <4 hours, RPO <1 hour)
- **Regions**: Multi-region deployment (AWS/Azure/GCP agnostic)
- **Security**: Zero-trust, SOC 2 Type II, FedRAMP-ready compliance
- **Cost**: Optimized for 60-70% cost efficiency through auto-scaling and reserved capacity

---

## C4 Model - System Architecture

### Level 1: System Context Diagram

\\\
┌──────────────────────────────────────────────────────────────┐
│                    Basecoat Portal System                      │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  Governance | Security Audits | Compliance | Metrics         │
│                                                                │
└────────────────────────────────┬────────────────────────────┘
         ▲                        │                    ▲
         │                        │                    │
         │ GitHub Events          │ Compliance         │ Portal
         │ (Webhooks)             │ Reporting         │ Users
         │                        │ (Export)          │
         │                        ▼                    │
    ┌────────────────┐  ┌──────────────────┐  ┌─────────────┐
    │ GitHub.com     │  │ Reporting Engine │  │ Enterprise  │
    │ (Repositories, │  │ (PDF, Excel,     │  │ Users (SSO) │
    │  Issues, PRs)  │  │  Dashboards)     │  └─────────────┘
    └────────────────┘  └──────────────────┘
`

**External Systems:**
- **GitHub.com**: Source of truth for repository metadata, audit trails, PR/issue activity
- **Enterprise SSO**: Okta/Entra ID for authentication and RBAC
- **Reporting Consumers**: Governance teams, compliance officers, stakeholders

### Level 2: Container Architecture

\\\
┌─────────────────────────────────────────────────────────────────┐
│                         Portal Infrastructure                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐   │
│  │   Web Frontend   │      │  API Gateway   │      │   Auth Service   │   │
│  │  (React/SPA)     │      │  (gRPC + REST) │      │  (OIDC + JWT)    │   │
│  └────────┬─────┘      └────────┬────┘      └──────────┬─────┘   │
│           │                     │                      │          │
│           └─────────────────────┼──────────────────────┘          │
│                                 │                                 │
│  ┌──────────────┐      ┌────────┴──────┐      ┌──────────────┐   │
│  │   Audit      │      │  Compliance   │      │   GitHub     │   │
│  │   Module     │      │   Module      │      │  Sync Service    │   │
│  └──────────────┘      └───────────────┘      └──────────────┘   │
│                                                                   │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐   │
│  │  Reporting   │      │   Events     │      │  Metrics     │   │
│  │   Engine     │      │   Stream     │      │  Collector   │   │
│  └──────────────┘      └──────────────┘      └──────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
         │                    │                      │
         ▼                    ▼                      ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   SQL Database   │  │  Event Stream    │  │   Object Storage │
│   (PostgreSQL)   │  │  (Kafka/RabbitMQ)│  │  (S3/Blob)       │
└──────────────────┘  └──────────────────┘  └──────────────────┘
`

**Container Responsibilities:**
- **Frontend**: Single-page application with governance dashboards, audit viewer, compliance checklists
- **API Gateway**: gRPC (internal) + REST (external), rate limiting, authentication
- **Auth Service**: OIDC with enterprise SSO, JWT tokens, RBAC policies
- **Audit Module**: GitHub webhook consumer, audit event normalization, retention
- **Compliance Module**: Policy evaluation, rule engine, exception tracking
- **GitHub Sync**: Periodic GitHub API polling, repository/user sync, cache invalidation
- **Reporting Engine**: PDF/Excel generation, scheduled exports, email delivery
- **Events Stream**: Event bus for async communication, event ordering, at-least-once delivery
- **Metrics Collector**: Application metrics, system telemetry, observability signals

### Level 3: Component Architecture

\\\
┌────────────────────────────────────────────────────────┐
│              API Gateway (Envoy/nginx)                  │
├────────────────────────────────────────────────────────┤
│ - gRPC multiplexer (internal services)                  │
│ - REST endpoints (external consumers)                   │
│ - Rate limiting (100 req/sec per user)                  │
│ - Circuit breakers, retries, timeouts                   │
└────────┬───────────────────┬──────────────┬────────────┘
         │                   │              │
    ┌────▼──────┐  ┌────────▼─┐  ┌────────▼──────┐
    │ Auth      │  │ Audit    │  │ Compliance   │
    │ Service   │  │ Consumer │  │ Evaluator    │
    └───────────┘  └──────────┘  └──────────────┘
        │ gRPC         │             │
        └─────────────┬─────────────┘
                      │
           ┌──────────▼────────────┐
           │  Event Bus (Kafka)     │
           │  - GitHub.webhook      │
           │  - policy.updated      │
           │  - compliance.check    │
           │  - report.scheduled    │
           └──────────┬─────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
    ┌───▼──┐  ┌──────▼────┐  ┌────▼──────┐
    │ Rules│  │ Metrics   │  │ Reporting │
    │Engine│  │ Exporter  │  │ Scheduler │
    └──────┘  └───────────┘  └───────────┘
`

**Components Breakdown:**
- **Auth Service**: JWT token generation, RBAC evaluation, session management
- **Audit Consumer**: Kafka topic subscriber, GitHub webhook handler, event deduplication
- **Compliance Evaluator**: Policy DSL interpreter, rule engine, exception management
- **Rules Engine**: Domain-specific language for governance rules, versioning
- **Metrics Exporter**: Prometheus metrics, trace exports (OpenTelemetry)
- **Reporting Scheduler**: Cron-based report generation, email notifications

### Level 4: Code Structure

Each component follows a standard Go service layout:
\\\
service/
  ├── cmd/
  │   └── main.go (entry point, dependency injection)
  ├── internal/
  │   ├── handler/ (HTTP/gRPC handlers)
  │   ├── service/ (business logic)
  │   ├── repository/ (data access)
  │   └── model/ (domain entities)
  ├── api/ (proto definitions for gRPC)
  └── config/ (environment configuration)
\\\

---

## Data Flow Diagrams

### GitHub Audit Flow

\\\
GitHub.com                    Portal System
   │                              │
   ├─ webhook (push event) ─────→ │
   │                         API Gateway
   │                              │
   │                         Audit Consumer
   │                              │
   │                         Event Bus (Kafka)
   │                              │
   │                         Rules Engine
   │                              │
   │                         Database (Store)
   │
   ├─ periodic API call ←────── GitHub Sync Service
   │  (rate: 1 req/min per org)
   │
   └─ Repository metadata ──────→ Cache (Redis)
`

**Flow Details:**
1. GitHub webhook delivers push/PR/issue events to API Gateway
2. Audit Consumer deserializes events, applies schema validation
3. Events published to Kafka topic with deduplication key (event_id)
4. Rules Engine consumes events, evaluates compliance policies
5. Violations stored in PostgreSQL with audit trail (timestamp, user, action)
6. GitHub Sync Service performs periodic API polling for missed webhooks
7. Repository metadata cached in Redis (TTL: 1 hour)

### Compliance Reporting Flow

\\\
Database                    Reporting Engine
   │                              │
   ├─ Query violations ─────────→ │
   │  (date range filter)         Report Generator
   │                              │
   │                         Template Renderer
   │                              │
   │                         PDF/Excel Encoder
   │                              │
   │                         Email Service
   │                              │
   └─ Store report metadata ←────── │
      (report_id, generated_at)
`

**Flow Details:**
1. Scheduled jobs trigger compliance report generation (daily, weekly, monthly)
2. Report Engine queries violations, exceptions, metrics from PostgreSQL
3. Template Renderer applies customizable report layouts (HTML → PDF)
4. PDF/Excel encoders generate downloadable artifacts
5. Email Service delivers reports to subscribed compliance officers
6. Report metadata stored with retention policy (7 years for audit)

### GitHub Integration Sync Flow

\\\
GitHub API                  Portal Services
   │                              │
   ├─ List repositories ─────────→ GitHub Sync
   │  (paginated, per_page=100)
   │
   ├─ Repository details ────────→ Cache (Redis)
   │
   ├─ Collaborators ─────────────→ User Service
   │
   ├─ Branch protection rules ───→ Compliance Module
   │
   └─ Audit log ────────────────→ Audit Store
      (v3 API + Events API)
`

**Flow Details:**
1. Sync Service calls GitHub API v3 (GraphQL for complex queries)
2. Rate limit awareness: GitHub Copilot Portal uses service account with 15k/hour quota
3. Pagination handled with cursor-based iteration (GraphQL after: cursor)
4. Repository metadata cached with 1-hour TTL
5. Compliance rules evaluated against branch protection, CODEOWNERS, required status checks

---

## Deployment Topology

### Multi-Region Architecture

\\\
┌─────────────────────────────────────────────────────────────┐
│                    Global Load Balancer                       │
│                  (Weighted DNS + Health Checks)               │
└────────────┬────────────────────┬─────────────────┬──────────┘
             │                    │                 │
        60% traffic           30% traffic        10% traffic
             │                    │                 │
    ┌────────▼──────┐  ┌──────────▼────┐  ┌────────▼──────┐
    │   Region 1    │  │   Region 2    │  │   Region 3    │
    │  (Primary)    │  │  (Secondary)  │  │  (Tertiary)   │
    │   US-East     │  │   EU-West     │  │   AP-SE       │
    └────────┬──────┘  └───────┬────────┘  └────────┬──────┘
             │                 │                    │
        ┌────▼────┐       ┌────▼────┐         ┌────▼────┐
        │ AKS/EKS │       │ AKS/EKS │         │ AKS/EKS │
        │ Cluster │       │ Cluster │         │ Cluster │
        └────┬────┘       └────┬────┘         └────┬────┘
             │                 │                    │
      ┌──────┼──────┐   ┌──────┼──────┐   ┌────────┼───────┐
      │      │      │   │      │      │   │       │        │
    ┌─▼─┐ ┌─▼─┐ ┌──▼─┐ ┌─▼─┐ ┌─▼─┐ ┌──▼─┐ ┌─▼─┐ ┌─▼─┐ ┌──▼─┐
    │Pod│ │Pod│ │Pod │ │Pod│ │Pod│ │Pod │ │Pod│ │Pod│ │Pod │
    │ 1 │ │ 2 │ │ 3 │ │ 1 │ │ 2 │ │ 3 │ │ 1 │ │ 2 │ │ 3 │
    └─┬─┘ └─┬─┘ └──┬─┘ └─┬─┘ └─┬─┘ └──┬─┘ └─┬─┘ └─┬─┘ └──┬─┘
      │     │     │     │     │     │     │     │     │
      └─────┼─────┘     └─────┼─────┘     └─────┼─────┘
            │                 │                 │
      ┌─────▼─────┐    ┌─────▼─────┐   ┌──────▼──────┐
      │  Database │    │ Database  │   │   Database  │
      │ (Primary) │    │ (Replica) │   │  (Replica)  │
      └───────────┘    └───────────┘   └─────────────┘
            │                 │              │
            └─────────────────┼──────────────┘
                              │
                      ┌───────▼────────┐
                      │ Backup Storage │
                      │  (Cross-Region)│
                      └────────────────┘
`

**Deployment Details:**
- **Primary Region** (US-East): Handles 60% of traffic, leader database, authoritative API
- **Secondary Region** (EU-West): Handles 30% of traffic, read-only replica, failover ready
- **Tertiary Region** (AP-SE): Handles 10% of traffic, read-only replica, disaster recovery
- **DNS Failover**: Health checks every 10s, failover time <30s
- **Database Replication**: PostgreSQL streaming replication with <1s lag (RPO target)
- **Cross-Region Backup**: Daily snapshots to S3 (replicated to all regions)

### Kubernetes Pod Topology (Per Region)

\\\
┌──────────────────────────────────────┐
│        Kubernetes Cluster             │
├──────────────────────────────────────┤
│                                       │
│  ┌────────────────────────────────┐  │
│  │      Ingress Controller         │  │
│  │ (nginx, TLS termination)        │  │
│  └────────┬───────────────────────┘  │
│           │                           │
│  ┌────────▼─────────────────────────┐ │
│  │  API Gateway Service             │ │
│  │ (3 replicas, anti-affinity)      │ │
│  └────────┬─────────────────────────┘ │
│           │                            │
│  ┌────────┼────────────────────────┐  │
│  │        │                         │  │
│  │ ┌──────▼──────┐ ┌──────────────┐│  │
│  │ │ Audit Pod   │ │Compliance Pod││  │
│  │ │ (2 replicas)│ │(2 replicas)  ││  │
│  │ └─────────────┘ └──────────────┘│  │
│  │        │                         │  │
│  │ ┌──────▼──────┐ ┌──────────────┐│  │
│  │ │ Reporting   │ │GitHub Sync   ││  │
│  │ │ Pod (1 rep) │ │Pod (1 rep)   ││  │
│  │ └─────────────┘ └──────────────┘│  │
│  │                                  │  │
│  └──────────────────────────────────┘  │
│                                       │
│  ┌────────────────────────────────┐  │
│  │  Monitoring & Logging Stack    │  │
│  │ (Prometheus, Loki, Jaeger)     │  │
│  └────────────────────────────────┘  │
│                                       │
└──────────────────────────────────────┘
`

---

## Scalability Analysis

### User Load Tiers

#### Tier 1: 100 Concurrent Users

**Resource Sizing:**
- API Gateway: 1 pod (2 CPU, 4 GB RAM)
- Services: 1 pod each (1 CPU, 2 GB RAM)
- Database: Single PostgreSQL instance (4 CPU, 16 GB RAM)
- Total: ~12 CPU, ~36 GB RAM

**Performance:**
- API P99 latency: <100ms
- Database queries: <50ms average
- Throughput: 500 req/sec

#### Tier 2: 500 Concurrent Users

**Resource Scaling:**
- API Gateway: 2 pods (4 CPU, 8 GB RAM)
- Services: 2 pods each (2 CPU, 4 GB RAM)
- Database: Primary + 1 read replica (8 CPU, 32 GB RAM)
- Cache layer (Redis): 2 GB, 3 replicas
- Total: ~24 CPU, ~80 GB RAM

**Performance:**
- API P99 latency: <150ms
- Database queries: <60ms average
- Throughput: 2500 req/sec
- Cache hit rate: 80%+

#### Tier 3: 1000+ Concurrent Users

**Full Resource Deployment:**
- Multi-region setup (3 regions, active-passive)
- API Gateway: 3 pods per region (6 CPU, 12 GB RAM per region)
- Services: 3 pods each per region (3 CPU, 6 GB RAM per region)
- Database: Primary (16 CPU, 64 GB) + 2 read replicas (8 CPU, 32 GB each)
- Cache layer (Redis): 5 GB, 5 replicas
- Kafka: 3 brokers, 3 replicas per partition
- Total: ~60 CPU, ~200 GB RAM across all regions

**Performance:**
- API P99 latency: <200ms
- Database queries: <80ms average
- Throughput: 5000 req/sec per region
- Cache hit rate: 85%+
- Event processing lag: <5 seconds (Kafka)

### Auto-Scaling Strategy

\\\
┌─────────────────────────────────────┐
│     Metrics-Driven Auto-Scaling     │
├─────────────────────────────────────┤
│                                     │
│  CPU: Target 70%, Min 2, Max 10     │
│  Memory: Target 75%, Min 2, Max 8   │
│  Request latency: <250ms P99        │
│  Queue depth: <100 (Kafka)          │
│                                     │
│  Scale-up delay: 30s                │
│  Scale-down delay: 5m (cooldown)    │
│  Max change per cycle: +2 pods      │
│                                     │
└─────────────────────────────────────┘
`

**Scaling Triggers:**
- CPU >70% for 2 minutes → add pod
- CPU <30% for 5 minutes → remove pod (min 2)
- Memory >75% → alert + manual review
- Request latency P99 >250ms → add pod
- Queue depth >100 → add Kafka consumer

---

## Disaster Recovery & Backup Strategy

### RTO & RPO Targets

| Scenario | RTO | RPO | Recovery Method |
|----------|-----|-----|-----------------|
| Pod failure | <5 min | 0 (stateless) | Kubernetes auto-restart |
| Single region outage | <4 hours | <1 hour | DNS failover to secondary |
| Database corruption | <30 min | <1 hour | Point-in-time restore |
| Complete region loss | <4 hours | <1 hour | Failover + restore from backup |

### Backup Architecture

\\\
┌──────────────────────────────────────┐
│      Production Database              │
│       (PostgreSQL Primary)            │
└──────────────────┬───────────────────┘
                   │
         ┌─────────┼─────────┐
         │         │         │
    ┌────▼──┐ ┌────▼───┐ ┌──▼────┐
    │Hourly │ │ Daily  │ │Weekly  │
    │ Snap  │ │ Snap   │ │ Snap   │
    │(1d)   │ │(7d)    │ │(52w)   │
    └────┬──┘ └────┬───┘ └──┬────┘
         │         │        │
         └─────────┼────────┘
                   │
         ┌─────────▼──────────┐
         │ S3 Backup Vault    │
         │ (All Regions)      │
         └────────────────────┘
`

**Backup Schedule:**
- **Hourly**: Last 24 hours (on-demand restore)
- **Daily**: Last 7 days (point-in-time recovery)
- **Weekly**: Last 52 weeks (long-term retention)
- **Cross-Region Replication**: All snapshots replicated to 3 regions

### Failover Procedure

**Detection (30s):**
1. Health check failure (3 consecutive failures)
2. Alert to ops team
3. Automated routing switch via DNS

**Failover (15m):**
1. Secondary region database promoted to primary
2. Connection strings updated (secrets rotation)
3. Kafka topic leadership transferred
4. Read replicas resynced

**Recovery (4h):**
1. Failed region infrastructure rebuilt
2. Database restored from last backup
3. Services restarted
4. Validation tests run
5. Gradual traffic shift back (5m each step)

---

## Security Posture

### Authentication & Authorization

- **SSO Integration**: OpenID Connect (OIDC) with Okta/Entra ID
- **Token Format**: JWT (RS256 signing)
- **Token Lifetime**: 1 hour access, 24 hour refresh
- **RBAC**: Role-based access control (Admin, Auditor, Viewer)
- **API Keys**: Service accounts with scoped permissions (GitHub Sync)

### Network Security

- **TLS 1.3**: All inter-service communication encrypted
- **Mutual TLS (mTLS)**: gRPC services use certificate validation
- **Network Policies**: Kubernetes NetworkPolicy enforces pod-to-pod traffic rules
- **WAF**: Cloud provider WAF (AWS CloudFront, Azure Front Door) blocks malicious traffic
- **DDoS Protection**: AWS Shield / Azure DDoS Protection (standard tier)

### Data Protection

- **At Rest**: PostgreSQL encryption (AES-256), S3 encryption
- **In Transit**: TLS 1.3 for all external traffic
- **Secrets Management**: HashiCorp Vault or cloud provider (AWS Secrets Manager, Azure Key Vault)
- **Audit Logging**: All data access logged with user, timestamp, action

### Compliance

- **SOC 2 Type II**: Annual audit with control assessment
- **FedRAMP Ready**: Aligned with control families (AC, AU, SC, SI)
- **Data Retention**: 7 years for audit logs (regulatory requirement)
- **Data Deletion**: GDPR right-to-be-forgotten (anonymization)

---

## Cost Model & Optimization

### Annual Cost Estimate (1000 user tier, 3 regions)

| Component | Cost/Month | Notes |
|-----------|-----------|-------|
| Compute (Kubernetes) | ,000 | 60 CPU, auto-scaling |
| Database (3x PostgreSQL) | ,000 | Primary + 2 replicas |
| Storage (Backups, Logs) | ,000 | S3 + cross-region replication |
| Network (Data transfer) | ,000 | Multi-region egress |
| CDN (Reporting assets) |  | CloudFront / Azure CDN |
| Monitoring & Logging | ,000 | Prometheus, Loki, Jaeger |
| **Total Monthly** | **,500** | ~/year |

### Cost Optimization Strategies

1. **Reserved Instances**: 30% discount on Kubernetes nodes
2. **Spot Instances**: 70% discount for non-critical pods (audit ingestion)
3. **Database Optimization**: Query indexing, connection pooling, caching
4. **Compression**: Gzip for reporting assets, Snappy for Kafka
5. **Consolidation**: Shared infrastructure for non-critical services
6. **Scheduling**: Off-peak batch jobs (reporting) at night

**Target**: 60-70% cost efficiency vs. on-demand pricing

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)

- [ ] Set up Kubernetes clusters (3 regions)
- [ ] Deploy PostgreSQL with streaming replication
- [ ] Implement authentication service (OIDC)
- [ ] Deploy API Gateway with rate limiting
- [ ] Set up observability stack (Prometheus, Loki, Jaeger)

### Phase 2: Core Services (Weeks 5-8)

- [ ] Implement Audit Consumer (GitHub webhook handler)
- [ ] Deploy Compliance Evaluator (rule engine)
- [ ] Set up Event Bus (Kafka)
- [ ] Implement GitHub Sync Service
- [ ] Create Reporting Engine

### Phase 3: Multi-Region & HA (Weeks 9-12)

- [ ] Configure database replication (primary → replicas)
- [ ] Set up cross-region backup strategy
- [ ] Implement DNS failover (health checks, routing)
- [ ] Test disaster recovery procedures
- [ ] Load testing (100, 500, 1000+ user scenarios)

### Phase 4: Operations & Governance (Weeks 13+)

- [ ] Deploy runbooks and playbooks
- [ ] Conduct chaos engineering exercises
- [ ] Compliance validation (SOC 2, FedRAMP)
- [ ] Documentation (architecture, operations, troubleshooting)
- [ ] Team training and knowledge transfer

---

## Coordination with Wave 3 Agents

### Data Tier Agent

**Collaboration Points:**
- Schema design for audit/compliance/reporting tables
- Query optimization for compliance rule evaluation
- Backup/restore strategy alignment
- Data retention policies (7-year audit trail)

### API Designer Agent

**Collaboration Points:**
- REST API contract (OpenAPI spec) for external consumers
- gRPC service definitions for internal communication
- Rate limiting policy (100 req/sec per user)
- Error code standardization

### Infrastructure Deploy Agent

**Collaboration Points:**
- Terraform/Bicep modules for Kubernetes cluster provisioning
- Database infrastructure setup (RDS/Azure Database for PostgreSQL)
- Auto-scaling policy definition
- Monitoring/alerting infrastructure

### Security Analyst Agent

**Collaboration Points:**
- Threat modeling for Portal system
- Security review of authentication/authorization
- Vulnerability assessment of dependencies
- Compliance mapping (SOC 2, FedRAMP controls)

---

## Recommendations for Stakeholders

1. **Start with single-region deployment** (US-East) to validate architecture and processes
2. **Implement monitoring and alerting** before production traffic (avoid blind spots)
3. **Conduct regular chaos engineering** exercises (monthly) to validate RTO/RPO targets
4. **Use feature flags** for gradual rollout of new compliance rules
5. **Maintain runbooks** for all failure scenarios (automated recovery preferred)
6. **Plan for 20-30% annual growth** in user base and data volume
7. **Coordinate with security team** for SOC 2 audit preparation (6-month lead time)

---

## Appendix: Technology Stack

- **Infrastructure**: Kubernetes (AKS/EKS), Terraform/Bicep
- **API Layer**: nginx Ingress, gRPC, REST
- **Services**: Go microservices (1.21+)
- **Database**: PostgreSQL 14+, Redis 7+
- **Message Broker**: Apache Kafka 3.x
- **Observability**: Prometheus, Loki, Jaeger (OpenTelemetry)
- **Authentication**: OIDC, OAuth 2.0
- **Reporting**: Chromium (headless) for PDF generation, go-reporting library for Excel

---

**Document Version**: 1.0  
**Last Updated**: May 5, 2026  
**Status**: Approved for Wave 3 Implementation
