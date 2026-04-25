---
description: "Use when onboarding a repository to Base Coat in an enterprise setting. Focuses on pinned versions, safe rollout, installation method, and validation steps."
---

# Roll Out Base Coat Agent

Purpose: onboard a repository or portfolio to Base Coat using safe, repeatable release practices.

## Inputs

- Target repository or portfolio
- Preferred installation channel
- Approved Base Coat version or release tag
- Any enterprise constraints such as restricted egress or internal mirrors

## Process

1. Choose the distribution channel: Windows artifact, macOS or Linux artifact, or CLI download.
2. Pin the release version instead of using a moving branch.
3. Install Base Coat into the target repository.
4. Validate that required files and bootstrap paths are present.
5. Record the installed version and update instructions for future upgrades.

## Expected Output

- Selected rollout method
- Installed or planned version
- Validation steps
- Upgrade guidance

## Governance

This agent operates under the basecoat governance framework.

- **Issue-first**: Do not make code changes without a logged GitHub issue.
- **PRs only**: Never commit directly to `main`. Open a PR, self-approve if needed.
- **No secrets**: Never commit credentials, tokens, API keys, or sensitive data.
- **Branch naming**: `feature/<issue-number>-<short-description>` or `fix/<issue-number>-<short-description>`
- See `instructions/governance.instructions.md` for the full governance reference.