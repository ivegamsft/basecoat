# Agent and Skill Taxonomy

This document defines the allowed `metadata.category` values for agent frontmatter.
`Uncategorized` is a placeholder and must not be used.

## Allowed category values

- AI & Development
- AI & Learning
- AI & Machine Learning
- AI & Operations
- API & Integration
- Architecture & Design
- CI/CD & Automation
- Cost & FinOps
- Data & Analytics
- Design & UX
- Developer Experience
- Development & Engineering
- Development & Review
- Documentation & Knowledge
- Governance & Compliance
- Infrastructure & DevOps
- Infrastructure & Operations
- Knowledge & Learning
- Modernization & Migration
- Onboarding & Deployment
- Operations & Support
- Orchestration
- Performance & Optimization
- Product & Strategy
- Project Management & Planning
- Release & Deployment
- Security & Compliance
- Testing & Quality

## Category policy

- Do not use `Uncategorized` in `metadata.category`.
- If `metadata.category` is missing, add the most specific value from this list.
- Legacy value `security` should be normalized to `Security & Compliance` when touched.
