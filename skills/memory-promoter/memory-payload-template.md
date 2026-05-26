# Memory Payload Template

Use this structure for contribution-ready payloads.

```json
[
  {
    "subject": "<1-2 word topic>",
    "fact": "<actionable fact, <=300 chars>",
    "citations": "<source references>",
    "reason": "<why this should be retained>",
    "score": "High | Medium | Low",
    "frequency": 2
  }
]
```

## Quality Gates

- Fact is generalizable beyond one session.
- No secrets, credentials, PII, or sensitive customer data.
- At least two distinct observations support the fact.
- Language is directive and operational, not narrative.
