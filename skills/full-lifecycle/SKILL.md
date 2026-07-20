---
name: full-lifecycle
description: End-to-end ticket → MR/PR in one shot. Chains start, analyse, implement, finish, and review skills. Use for fully autonomous delivery.
---

## Inputs

| Parameter | Description |
|-----------|-------------|
| service-name | Repository name (e.g., `order-service`) |
| ticket-id | Ticket ID (e.g., PROJ-1234, #42, ENG-567) |
| branch-type | `feature` or `fix` |

## Config Resolution

Read `~/.dev-agent-harness/config.yml` and resolve:
- `code_platform.provider` → `gitlab` or `github`
- `issue_tracker.provider` → `jira`, `github-issues`, or `linear`
- All other config values will be resolved by each chained skill.

Validate config exists and is readable before proceeding.

## Execution

Execute ALL phases sequentially. Only pause where explicitly marked. Fully autonomous otherwise.

## Phase 1: Start

Execute `start-story` skill with: service-name, ticket-id, branch-type.
(Pause only if multiple repo matches — user selects.)

## Phase 2: Analyse

1. Read `spec.md` — understand requirements and acceptance criteria.
2. Explore project structure — identify patterns, conventions, affected modules.
3. Plan implementation — map spec requirements to files/changes needed.

## Phase 3: Implement

1. Execute each task/requirement from `spec.md`.
2. Write production code following existing project patterns.
3. Write/update test cases.
4. Run tests — fix failures before proceeding.

## Phase 4: Finish

Execute `finish-story` skill.
(**PAUSE** for file acceptance before commit — this is the only required user interaction.)

## Phase 5: Review

Execute `review-mr` skill using project path and branch from Phase 4.
Autonomous — no user interaction needed.

## User Confirmation Points

Only two possible pauses:
1. **Phase 1** — if multiple repo name matches found.
2. **Phase 4** — file acceptance before commit.

## Token Usage Report

After full lifecycle completion, output:
```
📊 full-lifecycle token usage:
  Phase 1 (start): ~<N> tokens
  Phase 2 (analyse): ~<N> tokens
  Phase 3 (implement): ~<N> tokens
  Phase 4 (finish): ~<N> tokens
  Phase 5 (review): ~<N> tokens
  ─────────────────────────
  Total estimated: ~<total> tokens
  MCP/API calls total: <count>
```
