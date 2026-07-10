---
description: "Portal LLM Integration implementation guide showing prompt deployment, configuration, and operations"
---

# Portal LLM Integration Implementation Guide

## Quick Start

### 1. Deploy Prompts

All optimized prompts are located in `prompts/portal-*.prompt.md`:

```
prompts/
├── portal-audit-risk-analysis.prompt.md          # Risk severity assessment
├── portal-remediation-planning.prompt.md         # Remediation planning
├── portal-compliance-mapping.prompt.md           # Compliance standards mapping
├── portal-threat-analysis.prompt.md              # OWASP threat analysis
└── portal-plain-language.prompt.md               # Plain language explanation
```

### 2. Configuration

**Model Settings** (all prompts):

```json
{
  "provider": "azure-openai",
  "model": "gpt-4-turbo",
  "api_version": "2024-02",
  "temperature": 0.3,
  "top_p": 0.9,
  "max_tokens": 2000,
  "timeout": 5.0,
  "retry_policy": {
    "max_retries": 3,
    "backoff_multiplier": 2
  }
}
```

**Per-Prompt Overrides**:

| Prompt | Temperature | Tokens | Timeout |
|--------|-------------|--------|---------|
| Risk Analysis | 0.3 | 1500 | 5s |
| Remediation | 0.3 | 1800 | 8s |
| Compliance | 0.2 | 1600 | 6s |
| Threat Analysis | 0.25 | 1700 | 6s |
| Plain Language | 0.4 | 800 | 4s |

### 3. Environment Variables

```bash
# .env
AZURE_OPENAI_API_KEY=sk-...
AZURE_OPENAI_ENDPOINT=https://...
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4-turbo
PROMPT_CACHE_TTL=86400  # 24 hours
COMPLIANCE_AUDIT_LOG=/var/log/portal/compliance.log
```

## Architecture

### Request Flow

```
User Query
    ↓
Input Validation (no jailbreak, well-formed)
    ↓
Route to Appropriate Prompt
    ↓
Load from Cache (if applicable)
    ↓
Call Azure OpenAI with Temperature/Tokens Settings
    ↓
Parse Response (JSON validation)
    ↓
Safety Checks (hallucination detection, accuracy validation)
    ↓
Format for UI (user-friendly output)
    ↓
Log for Compliance + Feedback Collection
    ↓
Return to User
```

### Caching Strategy

**Cached Queries (24-hour TTL):**
- Compliance mappings for specific finding types
- OWASP threat mappings
- Plain language explanations for common findings

**Not Cached (always fresh):**
- Risk analysis (findings change frequently)
- Remediation plans (context-dependent)
- Threat assessment (attack landscape changes)

## Deployment Checklist

- [ ] Create Azure OpenAI deployment with gpt-4-turbo
- [ ] Configure API keys and endpoints in environment
- [ ] Deploy prompt files to `prompts/` directory
- [ ] Set up compliance audit logging
- [ ] Configure response timeout (5-8 seconds)
- [ ] Set up cache infrastructure (Redis recommended)
- [ ] Run unit tests: `pytest tests/unit`
- [ ] Run safety tests: `pytest tests/safety`
- [ ] Run performance tests: `pytest tests/performance`
- [ ] Set up monitoring: response latency, error rates, accuracy metrics
- [ ] Train compliance team on Portal features
- [ ] Beta test with 5 internal users (1 week)
- [ ] Rollout to all compliance users

## Monitoring & Operations

### Key Metrics

**Accuracy:**
- Risk severity accuracy: target >95%
- Compliance mapping accuracy: target >98%
- Remediation feasibility: target >90%

**Performance:**
- Response latency (p95): target <5s
- Cache hit rate: target >40%
- Error rate: target <1%

**Safety:**
- Jailbreak attempts blocked: 100%
- Hallucinations detected: <1%
- False positives in moderation: <5%

### Monitoring Dashboard

```sql
-- Daily accuracy report
SELECT
  DATE(created_at) as date,
  prompt_type,
  COUNT(*) as total_responses,
  SUM(CASE WHEN accuracy_verified THEN 1 ELSE 0 END) as accurate_count,
  ROUND(100.0 * SUM(CASE WHEN accuracy_verified THEN 1 ELSE 0 END) / COUNT(*), 2) as accuracy_pct,
  AVG(response_latency_ms) as avg_latency_ms,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_latency_ms) as p95_latency_ms
FROM prompt_responses
GROUP BY DATE(created_at), prompt_type
ORDER BY date DESC;
```

### Alerting Rules

```yaml
alerts:
  - name: High Latency
    condition: response_latency_p95 > 6000  # 6 seconds
    severity: warning
    action: notify_sre

  - name: Accuracy Drop
    condition: daily_accuracy < 90  # Drop from 95% baseline
    severity: critical
    action: page_on_call_engineer

  - name: High Error Rate
    condition: error_rate > 5%
    severity: critical
    action: page_on_call_engineer

  - name: Jailbreak Attempt
    condition: jailbreak_detected = true
    severity: warning
    action: log_and_review
```

## User Guide

### For Compliance Officers

1. **Submit Audit Finding** → Portal captures finding details
2. **Select Analysis Type** → Risk Assessment, Compliance Check, or Threat Analysis
3. **Review AI Response** → Read risk score, compliance impact, next steps
4. **Rate Response** → 1-5 stars feedback
5. **Export Report** → Generate compliance documentation
6. **Track Remediation** → Monitor progress on Portal dashboard

### For Security Analysts

1. **Deep Dive Analysis** → Select "Threat Analysis" for OWASP/CWE mapping
2. **Multi-Framework Review** → Check compliance against all applicable standards
3. **Evidence Gathering** → Use plain language summaries for stakeholder comms
4. **Remediation Planning** → Export detailed remediation plans
5. **Trends Analysis** → Dashboard shows most common findings by framework

## Integration Points

### API Endpoints

```
POST /api/v1/audit/analyze-risk
  Body: { finding: {...} }
  Response: { severity, risk_score, compliance_impact, ... }

POST /api/v1/compliance/map-standards
  Body: { issue: {...}, frameworks: ["GDPR", "SOC2", ...] }
  Response: { GDPR: {...}, SOC2: {...}, ... }

POST /api/v1/threat/identify-risks
  Body: { audit_result: {...}, context: {...} }
  Response: { threat_vectors: [...], business_impact: {...}, ... }

POST /api/v1/audit/remediation-plan
  Body: { issue: {...}, constraints: {...} }
  Response: { phases: {...}, timeline: "...", resource_estimate: {...} }

POST /api/v1/audit/explain-plaintext
  Body: { finding: {...}, audience: "compliance_officer" }
  Response: { explanation: "...", next_steps: [...], timeline: "..." }
```

### Database Schema

```sql
CREATE TABLE audit_findings (
    id UUID PRIMARY KEY,
    finding_type VARCHAR(100),
    description TEXT,
    severity VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR(100)
);

CREATE TABLE prompt_responses (
    id UUID PRIMARY KEY,
    finding_id UUID REFERENCES audit_findings(id),
    prompt_type VARCHAR(50),
    response_json JSONB,
    response_latency_ms INTEGER,
    user_rating INTEGER,
    user_comment TEXT,
    accuracy_verified BOOLEAN,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE compliance_mappings (
    id UUID PRIMARY KEY,
    finding_id UUID REFERENCES audit_findings(id),
    framework VARCHAR(50),
    requirement_section VARCHAR(50),
    compliance_gap TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE remediation_tracking (
    id UUID PRIMARY KEY,
    finding_id UUID REFERENCES audit_findings(id),
    status VARCHAR(50),
    owner VARCHAR(100),
    target_completion_date DATE,
    actual_completion_date DATE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

## Troubleshooting

### Issue: Slow Responses (>5s latency)

**Diagnosis:**
1. Check API response time: `curl -w "@curl-format.txt" -o /dev/null -s https://api.openai.com/...`
2. Check cache hit rate: `SELECT SUM(CASE WHEN from_cache THEN 1 ELSE 0 END) / COUNT(*) FROM prompt_responses`
3. Monitor Azure OpenAI quota usage

**Resolution:**
- Increase cache TTL if cold starts are frequent
- Add batch processing for bulk operations
- Contact Azure support if API throttled

### Issue: Inaccurate Compliance Mappings

**Diagnosis:**
1. Check against official regulation: GDPR Article 32, SOC 2 CC6.1, etc.
2. Run accuracy benchmark: `pytest tests/unit/test_compliance_mapping.py -v`
3. Compare against baseline: `pytest tests/regression/test_compare_baseline.py`

**Resolution:**
- Update compliance mapping prompt with official regulation text
- Add new test case to regression suite
- Re-run full accuracy benchmarks
- Tag as "prompt update" in version control

### Issue: User Reports Jailbreak Attempt Was Not Blocked

**Diagnosis:**
1. Review logs: `grep "jailbreak" /var/log/portal/compliance.log`
2. Check jailbreak pattern list: `cat prompts/guardrails/jailbreak_patterns.json`
3. Validate detection rules were loaded

**Resolution:**
- Add new jailbreak pattern to detection list
- Test new pattern: `pytest tests/safety/test_jailbreak_detection.py`
- Deploy updated pattern list
- Monitor for similar patterns

## Compliance & Audit Trail

### Logging Requirements

All Portal LLM interactions must be logged for:
- **SOC 2 Audit**: User access to findings, who analyzed what
- **GDPR Compliance**: Data processing log (finding analysis = data processing)
- **Incident Response**: Sequence of analysis steps leading to decision

```python
def log_prompt_interaction(user_id, finding_id, prompt_type, response, latency_ms):
    """Log all Portal LLM interactions for compliance"""
    log_entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "user_id": user_id,
        "finding_id": finding_id,
        "prompt_type": prompt_type,
        "response_tokens": len(response),
        "latency_ms": latency_ms,
        "accuracy_verified": None,  # Set by human review
        "compliance_frameworks": response.get("compliance_impact", [])
    }
    
    # Write to audit log
    audit_logger.info(json.dumps(log_entry))
    
    # Store in database for reports
    db.save_prompt_interaction(log_entry)
```

### Annual Compliance Validation

- [ ] Run full accuracy benchmark suite
- [ ] Validate all compliance mappings against current regulations
- [ ] Review and update threat intelligence (OWASP updates)
- [ ] Assess performance against SLA targets
- [ ] Collect and analyze user feedback trends
- [ ] Update prompt versions if needed
- [ ] Generate compliance report for auditors

## Version Management

**Current Prompt Versions:**
- `portal-audit-risk-analysis.prompt.md`: v1.0
- `portal-remediation-planning.prompt.md`: v1.0
- `portal-compliance-mapping.prompt.md`: v1.0
- `portal-threat-analysis.prompt.md`: v1.0
- `portal-plain-language.prompt.md`: v1.0

**Release Process:**
1. Update prompt with improvements
2. Tag as v1.1-rc1 (release candidate)
3. Run full test suite
4. A/B test with 10% traffic
5. If accuracy >= 95%: promote to v1.1 stable
6. Commit to Git with changelog entry
7. Deploy to production

## Support & Escalation

- **Accuracy Issues**: Contact Security Team (security@company.com)
- **Performance Issues**: Contact Infrastructure Team (infra-support@company.com)
- **Compliance Questions**: Contact Legal & Compliance (legal@company.com)
- **Feature Requests**: File issue in Portal backlog

---

*Implementation Guide Version: 1.0*
*Last Updated: May 2024*
*Maintained by: Security & Compliance Engineering*
