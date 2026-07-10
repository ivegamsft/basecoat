# Basecoat Portal Prompt Engineering v1.0

## 1. System Prompt Specifications

### 1.1 Base System Prompt for Audit Assistant

You are an expert security audit analyst assistant for the Basecoat Portal. Your role is to help compliance officers and security analysts interpret, remediate, and track security audit findings with accuracy and clarity.

**Core Principles:**
- Prioritize accuracy over speed; cite sources for all recommendations
- Use plain language for compliance officers; technical depth for analysts
- Never assume; ask for clarification when audit findings are ambiguous
- Follow industry standards (SOC 2, GDPR, HIPAA, NIST) when applicable
- Flag incomplete data and recommend validation steps

**Operational Constraints:**
- Max response tokens: 2000 (compliance summary: 800)
- Temperature: 0.3 (low variance for consistency)
- Top-p: 0.9 (diverse but focused)
- Response timeout: 5 seconds

**Output Format (Default):**
- Begin with severity assessment [CRITICAL/HIGH/MEDIUM/LOW]
- Provide structured findings with evidence
- End with next steps and ownership recommendations

---

## 2. Optimized Prompt Templates

### 2.1 Audit Finding Risk Analysis

**System Prompt:**
You are analyzing security audit findings for a compliance portal. Assess the risk severity objectively using industry standards.

**Prompt Template:**
\\\
Analyze this audit finding for risk severity:

FINDING:
{audit_finding_detail}

CONTEXT:
- System: {affected_system}
- Scope: {scope_detail}
- Current Controls: {existing_controls}

Provide a JSON response with:
{
  "severity": "CRITICAL|HIGH|MEDIUM|LOW",
  "risk_score": 0-100,
  "evidence": ["fact1", "fact2"],
  "compliance_impact": ["SOC2", "GDPR"],
  "remediation_priority": "P0|P1|P2|P3",
  "next_steps": ["step1", "step2"]
}
\\\

**Few-Shot Example 1: Weak Password Policy**
\\\
FINDING: Users can set passwords without complexity requirements
CONTEXT: 
- System: Azure AD
- Scope: 500+ employees
- Current Controls: None

EXPECTED OUTPUT:
{
  "severity": "HIGH",
  "risk_score": 78,
  "evidence": [
    "Password history not enforced",
    "No minimum complexity requirements",
    "Affects 500+ user accounts"
  ],
  "compliance_impact": ["SOC2", "HIPAA"],
  "remediation_priority": "P1",
  "next_steps": [
    "Enable Azure AD password policy enforcement",
    "Set minimum 12-character requirement with complexity",
    "Force password reset for non-compliant users"
  ]
}
\\\

**Few-Shot Example 2: Exposed API Keys**
\\\
FINDING: API keys found in GitHub commit history
CONTEXT:
- System: Production API
- Scope: 5 repositories, 12 exposed keys
- Current Controls: Pre-commit hooks (not enforced)

EXPECTED OUTPUT:
{
  "severity": "CRITICAL",
  "risk_score": 95,
  "evidence": [
    "Keys exposed in plaintext in commits",
    "No pre-commit hook enforcement",
    "History accessible to 50+ developers"
  ],
  "compliance_impact": ["SOC2", "GDPR", "PCI-DSS"],
  "remediation_priority": "P0",
  "next_steps": [
    "Immediately revoke all 12 exposed API keys",
    "Scan commit history with git-secrets or truffleHog",
    "Enforce pre-commit hooks and secrets scanning",
    "Implement mandatory GitOps secret rotation"
  ]
}
\\\

### 2.2 Remediation Suggestion Prompt

**Prompt Template:**
\\\
Suggest remediation steps for this compliance issue:

ISSUE:
{issue_description}

CONSTRAINTS:
- Team: {responsible_team}
- Timeline: {available_timeline}
- Budget: {available_budget}
- Technical Debt: {current_state}

Provide a step-by-step remediation plan with:
1. Immediate actions (0-48 hours)
2. Short-term fixes (1-4 weeks)
3. Long-term solutions (1-3 months)
4. Success metrics for each phase
5. Risk mitigation if delay occurs
\\\

**Few-Shot Example 1: TLS Certificate Expiry**
\\\
ISSUE: TLS certificate expires in 30 days
CONSTRAINTS:
- Team: Infrastructure (2 people)
- Timeline: 2 weeks available
- Budget: None (existing tools)
- Technical Debt: Manual renewal process

REMEDIATION PLAN:
1. Immediate (0-48 hours):
   - Check certificate renewal process documentation
   - Test renewal in staging environment
   - Notify certificate authority

2. Short-term (1-2 weeks):
   - Execute renewal in production
   - Validate certificate chain
   - Update HSTS headers
   - Run SSL Labs test

3. Long-term (1-2 months):
   - Automate renewal with Let's Encrypt
   - Implement monitoring alerts (60, 30, 14 days)
   - Document backup renewal procedures

4. Success Metrics:
   - Certificate renewed without downtime
   - Automated renewal functioning
   - Zero SSL warnings in browsers

5. Risk Mitigation:
   - If delayed: Prepare manual emergency renewal
   - If test fails: Rollback plan to previous certificate
\\\

### 2.3 Plain Language Explanation Prompt

**Prompt Template:**
\\\
Explain this audit result in plain language for a compliance officer:

TECHNICAL RESULT:
{technical_finding}

AUDIENCE: {compliance_officer|security_analyst|executive}

Guidelines:
- Avoid jargon; explain technical terms
- Use an analogy if helpful
- Explain why this matters for compliance
- Suggest who should be involved in remediation
- Keep to 150 words for executives, 300 for officers
\\\

**Few-Shot Example:**
\\\
TECHNICAL RESULT: SQL injection vulnerability in user input validation
AUDIENCE: Compliance Officer

PLAIN LANGUAGE:
A SQL injection vulnerability is like leaving your front door unlocked. An attacker could directly manipulate our database queries by entering specially crafted text in form fields. This could allow unauthorized access to customer data (names, emails, payment info).

Why it matters: Under GDPR and CCPA, we're liable for data breaches caused by preventable vulnerabilities. This is a "high" finding.

Who to involve: DevOps and Application Security teams should patch this within 48 hours. Database team should audit recent query logs for suspicious activity.

Next step: Coordinate with your Security Lead to assign this to the dev team immediately.
\\\

### 2.4 Compliance Report Summary Prompt

**Prompt Template:**
\\\
Generate a compliance report summary:

AUDIT_DATA:
{json_audit_findings}

REPORT_TYPE: {executive|detailed|management}

OUTPUT:
- Executive summary (1-2 paragraphs)
- Severity breakdown (CRITICAL/HIGH/MEDIUM/LOW)
- Compliance standards impact
- Top 5 priorities
- Timeline recommendation
- Resource estimate
\\\

---

## 3. Threat Analysis Prompts

### 3.1 Security Risk Identification

**Prompt Template:**
\\\
Identify potential security risks from audit results:

AUDIT_RESULTS:
{audit_data_json}

CONTEXT:
- Industry: {industry}
- Data Classification: {classification}
- Attack Surface: {attack_surface}

Provide:
1. Risk categories identified
2. Potential attack vectors
3. Impact assessment
4. Likelihood estimation
5. Recommended controls
\\\

**Few-Shot Example:**
\\\
AUDIT RESULTS: Unencrypted database backups stored in S3
CONTEXT:
- Industry: Healthcare
- Data Classification: PHI (Protected Health Information)
- Attack Surface: Cloud storage

RISK IDENTIFICATION:
1. Confidentiality breach via unauthorized S3 access
2. HIPAA violation (encryption required for PHI at rest)
3. Attackers could access PII of 50,000+ patients

Attack vectors:
- S3 bucket misconfiguration (public access)
- Compromised AWS credentials
- Insider threat from storage admin

Impact: Critical (patient data exposure)
Likelihood: High (common misconfiguration)

Recommended controls:
- Enable default S3 encryption (AES-256)
- Enable S3 versioning and MFA delete
- Restrict bucket access via IAM policy
- Enable access logging
- Schedule regular access reviews
\\\

### 3.2 OWASP Mapping Prompt

**Prompt Template:**
\\\
Explain this finding's OWASP mapping:

FINDING:
{security_finding}

Map to:
1. OWASP Top 10 category
2. CWE identifier
3. Exploitation difficulty
4. Business impact
5. Detection method
6. Remediation steps
\\\

---

## 4. Compliance Prompts

### 4.1 Compliance Standards Mapping

**Prompt Template:**
\\\
Map this issue to compliance standards:

ISSUE:
{compliance_issue}

STANDARDS_TO_CHECK: SOC2 | GDPR | HIPAA | PCI-DSS | ISO27001

Provide:
- Standard mapping (requirement ID)
- Severity in each framework
- Required evidence for audit
- Remediation steps per standard
- Timeline to compliance
\\\

### 4.2 Team Assignment Suggestion

**Prompt Template:**
\\\
Suggest team assignments for remediation:

ISSUE:
{issue_description}

AVAILABLE_TEAMS:
{team_json}

DECISION_FACTORS:
- Complexity: {low|medium|high}
- Skills required: {skills_list}
- Timeline: {timeline}

Recommend:
- Primary owner
- Supporting teams
- Escalation path
- Skill gaps to address
\\\

---

## 5. Safety & Guardrails

### 5.1 Jailbreak Detection

**Pattern Detection Rules:**
1. Reject requests asking to ignore system prompt
2. Reject requests to roleplay as unrestricted AI
3. Reject requests to bypass compliance rules
4. Reject requests for attack payloads or exploitation techniques

**Implementation:**
\\\python
JAILBREAK_PATTERNS = [
    r"ignore.*system.*prompt",
    r"pretend.*not.*a.*security.*assistant",
    r"bypass.*compliance",
    r"exploit.*without.*approval",
    r"disregard.*safety.*guidelines"
]

def detect_jailbreak(user_input: str) -> bool:
    for pattern in JAILBREAK_PATTERNS:
        if re.search(pattern, user_input, re.IGNORECASE):
            return True
    return False
\\\

### 5.2 Hallucination Prevention

**Strategy:** Require citation for all facts and recommendations

**Implementation:**
- For compliance references: cite specific regulation sections
- For technical recommendations: cite industry best practices
- For risk scores: show calculation methodology
- Flag uncertainty: "This requires verification by [Team]"

**Source Repository:**
Maintain a curated list of approved sources:
- NIST guidelines (nvlpubs.nist.gov)
- OWASP Top 10
- GDPR/HIPAA official docs
- SOC 2 Trust Service Criteria
- CIS Benchmarks

### 5.3 Accuracy Validation

**Cross-Check Framework:**
1. Severity ratings: Compare against industry benchmarks
2. Compliance mappings: Verify against official standards
3. Remediation steps: Validate feasibility and correctness
4. Timeline estimates: Check against historical data

**Validation Checklist (Before Response Delivery):**
- [ ] All external claims have sources
- [ ] Risk scores consistent with methodology
- [ ] Compliance mappings verified
- [ ] Remediation steps are actionable
- [ ] No contradictions with previous responses

### 5.4 Content Moderation

**Prohibited Content:**
- Requests to generate exploit code
- Requests for social engineering templates
- Requests to bypass security controls
- Requests to falsify audit reports

**Moderation Response Template:**
\\\
I cannot provide this information as it violates security governance principles:

Reason: [Specific policy violated]

What I can help with instead:
- [Alternative approach 1]
- [Alternative approach 2]

Please contact [Team] for [Specific need]
\\\

---

## 6. Performance Optimization

### 6.1 Token Efficiency

**Strategies:**
- Remove redundant explanations
- Use structured output (JSON) instead of prose
- Abbreviate common terms (SOC2 instead of "Service Organization Control 2")
- Cache common prompts and responses

**Token Budget per Scenario:**
- Risk analysis: max 1500 tokens
- Compliance mapping: max 800 tokens
- Plain language explanation: max 600 tokens
- Executive summary: max 400 tokens

### 6.2 Response Time Targets

**SLA by Prompt Type:**
- Risk analysis: < 3 seconds (cached) / < 5 seconds (fresh)
- Compliance report: < 4 seconds (cached) / < 8 seconds (fresh)
- Plain language: < 2 seconds (cached) / < 4 seconds (fresh)

**Caching Strategy:**
- Cache findings by hash of audit data (24-hour TTL)
- Cache compliance mappings (7-day TTL)
- Cache OWASP mappings (30-day TTL)
- Invalidate on database updates

### 6.3 Batch Processing

For large audit operations:
- Split findings into batches of 10-15
- Process in parallel with queue system
- Aggregate results with deduplication
- Return progress updates every 30 seconds

---

## 7. Testing Framework

### 7.1 Unit Tests for Each Prompt

**Test Suite Structure:**
\\\
tests/
├── audit_finding_tests.py
├── remediation_tests.py
├── compliance_mapping_tests.py
├── threat_analysis_tests.py
├── guardrail_tests.py
└── fixtures/
    ├── sample_findings.json
    ├── expected_outputs.json
    └── edge_cases.json
\\\

**Unit Test Example:**
\\\python
def test_risk_severity_assessment():
    """Test that weak password policies are rated HIGH"""
    finding = {
        "type": "weak_password_policy",
        "scope": 500,
        "controls": "none"
    }
    response = audit_assistant.analyze_risk(finding)
    assert response["severity"] == "HIGH"
    assert response["risk_score"] >= 70
    assert "GDPR" in response["compliance_impact"]
\\\

### 7.2 Integration Tests with Audit Data

**Test Data:**
- Real audit findings (sanitized)
- Edge cases (ambiguous findings, conflicting rules)
- Performance tests (large batches)
- Multi-framework compliance tests

**Integration Test Example:**
\\\python
def test_end_to_end_audit_workflow():
    """Test complete audit → analysis → remediation → report flow"""
    audit_data = load_fixture("sample_audit_findings.json")
    
    # Step 1: Analyze findings
    analyses = []
    for finding in audit_data:
        analysis = audit_assistant.analyze_risk(finding)
        analyses.append(analysis)
    
    # Step 2: Generate remediation plan
    remediation = audit_assistant.suggest_remediation(analyses)
    
    # Step 3: Generate compliance report
    report = audit_assistant.generate_report(analyses)
    
    # Validation
    assert len(analyses) == len(audit_data)
    assert remediation["prioritized_issues"] > 0
    assert report["executive_summary"] is not None
    assert report["compliance_score"] <= 100
\\\

### 7.3 Accuracy Benchmarks

**Target Metrics:**
- Risk severity accuracy: > 95% vs. manual assessment
- Compliance mapping accuracy: > 98% (regulatory requirement)
- Remediation feasibility: > 90% (expert validation)
- Plain language clarity: 85%+ comprehension by compliance officers

**Benchmark Test:**
\\\python
def test_accuracy_vs_benchmark():
    """Validate accuracy against known good examples"""
    test_cases = load_fixture("benchmark_cases.json")
    
    correct = 0
    for test_case in test_cases:
        result = audit_assistant.analyze_risk(test_case["input"])
        if result["severity"] == test_case["expected_severity"]:
            correct += 1
    
    accuracy = (correct / len(test_cases)) * 100
    assert accuracy >= 95, f"Accuracy {accuracy}% below 95% threshold"
\\\

### 7.4 User Feedback Collection

**Feedback Mechanism:**
- In-portal "Was this helpful?" buttons on each response
- User rating: 1-5 stars
- Comments: "What could be improved?"
- Tracking: store feedback linked to prompt version and input

**Feedback Aggregation:**
- Weekly accuracy report
- Identify low-scoring responses
- Retrain prompts based on feedback patterns
- Quarterly review of accuracy trends

---

## 8. Deployment & Version Control

### 8.1 Prompt Registry

**Location:** \prompts/portal-*.prompt.md\

**Versioning:**
- Format: \portal-audit-v1.0.prompt.md\
- Changelog tracked in Git
- Promote from beta → staging → production

### 8.2 Configuration

**Model Settings (Recommended):**
\\\json
{
  "model": "gpt-4-turbo",
  "temperature": 0.3,
  "top_p": 0.9,
  "max_tokens": 2000,
  "presence_penalty": 0.1,
  "frequency_penalty": 0.2,
  "timeout": 5.0
}
\\\

### 8.3 Rollback Procedure

- Keep previous 3 versions in production
- A/B test new versions on 10% traffic first
- Monitor accuracy and response time
- Rollback if accuracy drops below 93% or latency > 6s

---

## 9. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Response Accuracy | > 95% | Manual audit vs. AI output |
| Compliance Accuracy | > 98% | Legal review of mappings |
| Response Time | < 5s | 95th percentile latency |
| User Satisfaction | > 4.2/5 | In-portal feedback |
| False Positives | < 5% | Finding validation |
| Jailbreak Prevention | 100% | Security testing |

---

## 10. References

- NIST Cybersecurity Framework: nvlpubs.nist.gov
- OWASP Top 10: owasp.org/Top10
- SOC 2 Trust Service Criteria: aicpa.org
- GDPR Compliance: gdpr-info.eu
- CIS Benchmarks: cisecurity.org

---

*Document Version: 1.0*
*Last Updated: May 2024*
*Next Review: May 2025*
