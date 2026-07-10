# Queue Rebalancer Dependency DAG and Unblock Lane Gates

This diagram documents the blocker-first execution model used by the queue rebalancer.

- Source diagram: [queue-rebalancer-dependency-dag-and-lane-gates.excalidraw](queue-rebalancer-dependency-dag-and-lane-gates.excalidraw)
- Primary source terminology: `agents/basecoat-60-workflow-queue-rebalancer.agent.md` and `skills/queue-rebalancer/SKILL.md`

## What it covers

1. A dependency DAG example that separates blockers, blocked items, chain members, and independent work.
2. The unblock lane sequence from collection through verification and return to regular dependency order.
3. Gate decisions with explicit outcomes (`gate:no-tests`, `gate:needs-check-in`) and stalled-chain handling.

## Assumptions

- DAG edges are execution dependencies inferred from explicit relationship signals only.
- Gate labels represent promotion decisions, not issue closure outcomes.
- Example issue and PR numbers are illustrative; operators should substitute live queue items.

## Intended operator usage

1. Build the live DAG from open PR and issue relationships.
2. Use the unblock lane flow to keep the fast lane limited to unblock-critical fixes.
3. Apply the gate decision tree before promotion, and pause branches behind gated items.
4. Resume standard dependency ordering after unblock verification completes.
