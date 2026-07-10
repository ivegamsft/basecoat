# Basecoat Portal Incident Response Playbook

## Quick Reference: Incident Response Decision Tree

`
ALERT TRIGGERED
  |
  +---> P0 (Critical)?
  |     - Data breach detected
  |     - Authentication system down
  |     - Widespread service outage (>50% users)
  |     ACTION: Page VP Eng + Security + Legal immediately
  |             Activate war room
  |
  +---> P1 (High)?
  |     - Single service down
  |     - Target authentication failure
  |     - Suspicious activity detected
  |     ACTION: Page Engineering Manager within 15 min
  |             Investigate and contain
  |
  +---> P2 (Medium)?
  |     - Performance degradation (<5% latency impact)
  |     - Non-critical vulnerability reported
  |     ACTION: Alert team lead
  |             Remediate within 4 hours
  |
  +---> P3 (Low)?
        - Minor config issue
        - Non-urgent policy violation
        ACTION: File ticket
                Resolve within 1 business day
`

---

## Incident Classification

### Priority 0 - Critical (Response: < 15 minutes)

**Characteristics**:
- Data breach confirmed or suspected
- Authentication system completely unavailable
- Service outage affecting >50% of concurrent users
- Privilege escalation or authorization bypass confirmed
- Malicious code injected into production

**Examples**:
- Attacker gains access to customer data
- /auth/login endpoint returning 500 for 5+ minutes
- Database encryption key compromised
- Admin account hijacked

**Escalation**:
1. Incident commander (VP Engineering)
2. Security Officer / CISO
3. Legal / Compliance Officer
4. Communications team (customer notification)

**Activation**:
- PagerDuty: severity: critical
- Slack: #incident-response with @here
- On-call: Activate full incident war room

---

### Priority 1 - High (Response: < 1 hour)

**Characteristics**:
- Single service degradation or brief outage (< 15 min duration)
- Targeted authentication failure (< 100 users affected)
- Suspicious activity requiring investigation
- Performance degradation (> 1 second latency increase)
- Failed security control (e.g., failed MFA check)

**Examples**:
- API endpoint returning errors for 10-minute period
- Redis cache down, fallback to database active
- Unusual API usage pattern detected (possible brute force)
- Rate limiting triggered on /auth/login

**Escalation**:
1. On-call engineer
2. Engineering manager
3. Team lead
4. Security team (if security-related)

**Activation**:
- PagerDuty: severity: high
- Slack: #engineering notification
- On-call: Investigate and implement fix

---

### Priority 2 - Medium (Response: < 4 hours)

**Characteristics**:
- Non-critical service degradation
- Vulnerability reported in dependency
- Failed backup or recovery attempt
- Configuration drift detected
- Policy violation without immediate impact

**Examples**:
- Database query slow (5-10 second latency)
- npm audit reports vulnerability (not actively exploited)
- Backup job took longer than expected
- GitHub Actions secret accidentally logged

**Escalation**:
1. Team lead
2. On-call engineer
3. Security team (if security-related)

**Activation**:
- PagerDuty: severity: medium
- Slack: #engineering channel
- Timeline: Remediate within 4 hours

---

### Priority 3 - Low (Response: < 1 business day)

**Characteristics**:
- Minor configuration issue
- Non-urgent policy violation
- Documentation inconsistency
- Feature request
- Informational security alert

**Examples**:
- Typo in error message
- Telemetry not recording optional metric
- Developer forgot to add PR description
- Security.txt file needs update

**Escalation**:
1. Team member discovering issue
2. Team lead (approval for changes)

**Activation**:
- GitHub issue filed
- Added to backlog for next sprint
- No PagerDuty alert required

---

## Incident Response Procedures

### Phase 1: Detection & Triage (0-30 minutes)

**Goals**:
- Confirm incident is real (not false alarm)
- Classify severity level
- Alert appropriate personnel
- Open incident tracking ticket

**Steps**:
1. **Verify Alert**: Check monitoring dashboard to confirm issue
   - [ ] Application health checks
   - [ ] Database connectivity
   - [ ] Error rate and latency metrics
   - [ ] Security alerts and log analysis

2. **Gather Initial Context**:
   - [ ] When did issue start? (Compare to deployments/changes)
   - [ ] What systems are affected? (All users or specific org?)
   - [ ] Is service completely down or degraded?
   - [ ] Are there related alerts (upstream/downstream)?

3. **Classify Incident**:
   - [ ] Determine priority level (P0/P1/P2/P3)
   - [ ] Identify incident category (outage/security/performance)
   - [ ] Note affected services and users

4. **Activate Response**:
   - [ ] Page on-call engineer (all levels)
   - [ ] Create incident ticket: INC-####
   - [ ] Post to #incident-response Slack channel
   - [ ] Note initial assessment in ticket

**Triage Template**:
`
Incident: INC-XXXX
Priority: P0 | P1 | P2 | P3
Start Time: [UTC timestamp]
Affected Service: [Service name]
Impact: [Description]
Initial Assessment: [Findings]
Status: INVESTIGATING
Incident Commander: [Name]
`

---

### Phase 2: Containment (30-60 minutes)

**Goals**:
- Prevent incident from escalating
- Isolate affected components
- Preserve evidence for investigation
- Notify stakeholders

**Steps**:
1. **Isolate Affected Systems**:
   - [ ] If authentication compromised: Disable/rotate compromised credentials
   - [ ] If service down: Kill processes, scale down to prevent cascade failure
   - [ ] If database compromised: Enable read-only mode, restrict access
   - [ ] If network compromised: Block malicious IP / revoke stolen token

2. **Preserve Evidence**:
   - [ ] Collect logs before cleanup (min 7 days retention)
   - [ ] Memory dump of affected process (if crash)
   - [ ] Copy database transaction log
   - [ ] Screenshot monitoring dashboards

3. **Communicate Status**:
   - [ ] Post initial incident summary to #incident-response
   - [ ] Send customer notification (P0 only): "We are investigating a potential issue..."
   - [ ] Update incident ticket with containment actions

4. **Activate War Room** (P0 only):
   - [ ] Start Zoom call with VP Eng, Security, Legal
   - [ ] Establish incident bridge: [Zoom link]
   - [ ] Designate incident commander
   - [ ] Set status update cadence (every 15 min)

**Containment Checklist**:
`
✓ Issue isolated to specific component
✓ Blast radius assessed (% users affected)
✓ Evidence collected (logs, metrics, state)
✓ Stakeholders notified
✓ War room activated (P0 only)
✓ Incident tracking ticket updated
`

---

### Phase 3: Investigation & Root Cause Analysis (60+ minutes)

**Goals**:
- Determine root cause of incident
- Identify if data was compromised
- Assess blast radius and impact
- Plan remediation strategy

**Investigation Flow**:

1. **Examine Logs** (First 30 minutes):
   `
   Timeline: Look for anomalies in sequence of events
   - Application logs: Errors, exceptions, stack traces
   - Database logs: Failed connections, slow queries, locks
   - Network logs: Firewall denies, DDoS patterns
   - Security logs: Failed auth attempts, permission denials
   `

2. **Identify Root Cause**:
   - [ ] Was there a recent code deployment?
   - [ ] Was there an infrastructure change?
   - [ ] Was there a quota/limit exceeded?
   - [ ] Was there a security attack?
   - [ ] Was there an external dependency failure?

3. **Assess Impact** (If security breach):
   - [ ] What data was accessed? (sensitivity level)
   - [ ] How many records were exposed? (user count)
   - [ ] How long was access possible? (time window)
   - [ ] Are there signs of unauthorized use?

4. **Determine GDPR Notification Requirement**:
   - [ ] Did breach involve personal data of EU residents? (YES = GDPR breach)
   - [ ] Was data encrypted or otherwise unintelligible? (NO = requires notification)
   - [ ] Is there likelihood of harm to rights/freedoms? (YES = notify authorities + users)
   - If YES to all: Trigger breach notification procedure (72-hour timer starts)

**Investigation Template**:
`
Root Cause: [Technical explanation]
Timeline:
  - 14:32 UTC: Alert triggered (high error rate)
  - 14:33 UTC: Engineer investigates
  - 14:38 UTC: Identified issue in service X
  - 14:42 UTC: Root cause determined
Contributing Factors:
  - Recent deployment introduced bug in rate limiting
  - Load spike from new customer triggered latency
Blast Radius: [% users affected, services down, time duration]
`

---

### Phase 4: Remediation & Recovery (60+ minutes, ongoing)

**Goals**:
- Implement fix or workaround
- Deploy fix to production safely
- Verify incident is resolved
- Monitor for regression

**Steps**:

1. **Develop Fix Strategy**:
   - [ ] Option A: Rollback recent change
   - [ ] Option B: Deploy hotfix to production
   - [ ] Option C: Apply temporary workaround (manual scaling, traffic reroute)

2. **Implement & Test**:
   - [ ] Code fix or runbook procedure documented
   - [ ] Fix tested in staging environment
   - [ ] Change approval obtained (for P0/P1)
   - [ ] Deployment plan prepared

3. **Deploy to Production**:
   - [ ] Deploy fix with monitoring enabled
   - [ ] Check monitoring for errors/alerts
   - [ ] Verify service health (synthetic tests)
   - [ ] Monitor for 5-10 minutes after deployment

4. **Verify Resolution**:
   - [ ] Error rates returned to baseline
   - [ ] Latency returned to baseline
   - [ ] No new errors or alerts triggered
   - [ ] Customer-facing service responsive

**Remediation Checklist**:
`
✓ Root cause fixed
✓ Fix deployed to production
✓ Monitoring shows normal operation
✓ Incident status: RESOLVED
✓ Monitoring for regression (60 minutes)
`

---

### Phase 5: Notification & Communication (Post-resolution)

**Goals**:
- Inform stakeholders that issue is resolved
- Communicate timeline and impact
- Provide next steps

**Customer Communication** (template):

`
Subject: RESOLVED: [Service] Incident - [Brief Description]

Dear Customers,

[Service] was unavailable from [start time] to [end time] UTC
on [date]. We have resolved the underlying issue.

Timeline:
- [start time]: Issue detected by monitoring
- [start time + 5 min]: Investigation began
- [resolution time]: Fix deployed and verified

Root Cause: [Technical summary]
Impact: [Number of customers, duration]

We apologize for any disruption to your workflow. We are
implementing the following improvements to prevent recurrence:
- [Action item 1]
- [Action item 2]

For questions, please reply to this email or contact
support@basecoat.dev.

Regards,
Basecoat Incident Response Team
`

**Internal Notification** (template):

`
[Slack message to #incident-response]

✅ INCIDENT RESOLVED: INC-XXXX
Service: [Service name]
Status: RESOLVED at [time] UTC
Duration: [N minutes]
Root Cause: [Brief technical description]
Blast Radius: [Number of affected users]
Fix: [How it was fixed]

Full postmortem scheduled for [date/time].
Incident details: [Link to ticket]
`

---

### Phase 6: Post-Incident Review (24-72 hours after resolution)

**Goals**:
- Analyze root cause in detail
- Identify preventive improvements
- Share learnings with team
- Update runbooks

**Postmortem Process**:

1. **Schedule Meeting**:
   - [ ] 24-48 hours after incident resolution
   - [ ] Attendees: Incident commander, on-call engineer, team lead, security (if relevant)
   - [ ] Duration: 60-90 minutes

2. **Review Incident Timeline**:
   - [ ] What was the alert?
   - [ ] How did we respond?
   - [ ] What was the root cause?
   - [ ] How did we fix it?
   - [ ] When was it fully resolved?

3. **Identify Action Items**:
   - [ ] **Prevent**: Could we have prevented this? (better testing, monitoring, etc.)
   - [ ] **Detect**: Could we have detected it faster? (better alerting, thresholds, etc.)
   - [ ] **Respond**: Could we have responded faster? (better runbooks, processes, etc.)
   - [ ] **Recover**: Could we have recovered faster? (better automation, redundancy, etc.)

4. **File Tickets**:
   - [ ] Create GitHub issue for each action item
   - [ ] Label as 	ype/incident-follow-up and priority/[P0-P3]
   - [ ] Link to incident ticket
   - [ ] Assign to sprint

5. **Document Learning**:
   - [ ] Update incident runbook with new procedures
   - [ ] Update monitoring thresholds if needed
   - [ ] Share learnings in team Slack (thread)

**Postmortem Template**:
`
# Postmortem: INC-XXXX - [Incident Title]

## Summary
Brief 1-paragraph description of incident, impact, and resolution time.

## Timeline
- 14:32 UTC: Alert triggered
- 14:33 UTC: On-call engineer paged
- 14:38 UTC: Root cause identified
- 14:42 UTC: Fix deployed
- 14:45 UTC: Service returned to normal

## Root Cause Analysis
Detailed explanation of what went wrong and why.

## Impact
- Duration: 15 minutes
- Users affected: 127
- Services: API, Web UI, Jobs
- Severity: P1 (high)

## What Went Well
- Alert triggered within 1 minute
- On-call engineer investigated quickly
- Rollback was smooth and uneventful

## What Could Be Improved
- Catch this bug in testing (add regression test)
- Implement canary deployments (catch issues in 1% of users first)
- Better monitoring for this error class

## Action Items
- [ ] Add regression test for [bug description] (Dev, Sprint N)
- [ ] Implement canary deployments (DevOps, Sprint N+1)
- [ ] Update runbook for faster response (Ops, Sprint N)

## Ticket Link
[GitHub issue for follow-up actions]
`

---

## Runbooks for Common Incidents

### Runbook: Authentication System Down

**Symptoms**:
- /auth/login returns 500
- /auth/refresh returns 500
- Monitoring shows >50% error rate on auth endpoints

**Investigation**:
1. Check if GitHub OAuth API is up: curl https://github.com/login/oauth/authorize
2. Check if database is reachable: z sql server show --resource-group [rg] --name [server]
3. Check if Key Vault is accessible: z keyvault secret show --vault-name [kv] --name oauth-client-id
4. Check application logs: z appservice log tail --resource-group [rg] --name [app]

**Recovery**:
1. If GitHub OAuth is down: Implement fallback to Azure AD auth (code already in place)
2. If database is down: Failover to read replica (automatic in High Availability mode)
3. If Key Vault is down: Restart app service (Azure will refresh cached credentials)
4. If application logs show code error: Rollback most recent deployment

**Communication**:
`
We are currently experiencing issues with user login.
Status: INVESTIGATING
Impact: Users cannot log in
ETA: [time]
Workaround: Will be available shortly
`

---

### Runbook: API Service Down

**Symptoms**:
- API endpoints return 5xx errors
- Monitoring shows high latency
- Error rate spike in monitoring dashboard

**Investigation**:
1. Check application health: z appservice web show-instance-info --resource-group [rg] --name [app]
2. Check recent deployments: git log --oneline -5
3. Check database performance: SELECT * FROM sys.dm_exec_requests WHERE status != 'sleeping'
4. Check for resource exhaustion: Disk space, memory, CPU
5. Check application logs for exceptions

**Recovery**:
1. If recent deployment caused issue: Rollback to previous version
2. If database is slow: Kill blocking queries or restart database
3. If resource exhausted: Scale up or implement auto-scaling
4. If configuration issue: Update environment variables and restart

---

### Runbook: Data Breach Suspected

**Symptoms**:
- Unauthorized data access detected in logs
- Attacker IP identified in security events
- Unusual API calls to sensitive endpoints

**Immediate Actions** (First 15 minutes):
1. [ ] Do NOT continue business as usual
2. [ ] Page CISO and Legal immediately
3. [ ] Disable compromised user accounts (if known)
4. [ ] Revoke OAuth tokens for compromised org
5. [ ] Enable read-only mode on affected database
6. [ ] Preserve all evidence (logs, state snapshots)

**Investigation** (30-60 minutes):
1. [ ] Determine scope: How many records accessed? Which customers?
2. [ ] Determine timing: When did access start? When did it stop?
3. [ ] Determine method: How did attacker gain access? (stolen token, SQL injection, etc.)
4. [ ] Determine impact: What data was exposed? (PII, credentials, audit results)

**Response** (1-4 hours):
1. [ ] Legal: Assess notification requirements (GDPR 72-hour rule)
2. [ ] Security: Plug security hole that allowed access
3. [ ] Notifications: Prepare breach notification if required
4. [ ] Communications: Prepare public statement

**GDPR Breach Notification** (If triggered):
- Notify supervisory authority: Within 72 hours of discovery
- Notify affected individuals: If high risk of harm
- Document: Nature of breach, likely consequences, security measures

---

## On-Call Engineer Responsibilities

### Before Shift (30 minutes)

- [ ] Ensure PagerDuty is configured correctly (phone number verified)
- [ ] Test alerting: Ask someone to trigger low-priority alert
- [ ] Review recent incidents (any patterns?)
- [ ] Review runbooks and escalation procedures
- [ ] Notify team: "I'm on-call for [date/time]"

### During Shift

- [ ] Respond to PagerDuty alert within 5 minutes (P0), 15 minutes (P1)
- [ ] Triage incident: Classify priority and symptoms
- [ ] Investigate: Check logs, monitoring, recent changes
- [ ] Fix or escalate: Implement fix or page next level
- [ ] Communicate: Update ticket and Slack with status
- [ ] Monitor: Verify fix worked and check for regression (60 minutes)

### After Resolution

- [ ] Document incident details while fresh
- [ ] Collect evidence (logs, screenshots) for postmortem
- [ ] Notify team of resolution
- [ ] Hand off to next on-call engineer (if different person)

### After Shift Ends

- [ ] Ensure successor is on-call and aware
- [ ] Provide 30-minute overlap for handoff
- [ ] Note any ongoing incidents in ticket
- [ ] Update on-call runbook if procedures changed

---

## Escalation Contact List

| Role | Primary | Secondary | Notes |
|------|---------|-----------|-------|
| VP Engineering | [PagerDuty] | [Phone] | Final authority on P0 decisions |
| CISO / Security Officer | [PagerDuty] | [Phone] | For security incidents |
| Legal / Compliance | [Email] | [Phone] | For breach notifications |
| Database Team Lead | [Slack @dbteam] | [PagerDuty] | For database-specific issues |
| Ops Team Lead | [Slack @ops] | [PagerDuty] | For infrastructure issues |
| Customer Success Manager | [Email] | [Phone] | For customer communication |

---

## Document Control

**Version**: 1.0
**Last Updated**: 2026-05-04
**Next Review**: 90 days
**Owner**: Security Team
**Classification**: Internal - Security Sensitive

---

*This playbook is confidential and intended for authorized personnel only.*
