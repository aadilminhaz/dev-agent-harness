---
name: review-mr
description: Reviews a MR/PR against team coding standards. Fetches only relevant diffs, applies only matching rules, posts categorised comments. Use after creating a MR/PR or for on-demand review.
---

## Inputs

| Parameter | Description |
|-----------|-------------|
| project-path | Project path (e.g., `org/repo`). If not provided, infer from `git remote get-url origin`. |
| source-branch | MR/PR source branch. If not provided, infer from `git branch --show-current`. |
| mr-id | (Optional) MR iid or PR number. If not provided, look it up. |

## Config Resolution

Read `~/.dev-agent-harness/config.yml` and resolve:
- `code_platform.provider` → `gitlab` or `github`
- `code_platform.<provider>.auth.token_path` → read token from file
- `code_platform.<provider>.default_target_branch` → target branch
- `review.rules_path` → path to review rules file (default: `~/.dev-agent-harness/review-rules.yml`)
- `review.post_comments` → whether to post findings to MR/PR
- `review.severity_labels` → display labels for severity levels

Store resolved values for use in subsequent steps.

## Execution

Execute ALL steps autonomously. Do NOT ask for confirmation. Post findings directly to the MR/PR.

## Steps

### 1. Resolve project path and MR/PR

If `project-path` not provided:
```bash
git remote get-url origin
```
Extract path (after hostname, without `.git`).

**If code_platform.provider = gitlab:**

Find MR:
```
MCP tool: list_merge_requests
Parameters: { project_id: "<project-path>", source_branch: "<source-branch>", state: "opened" }
```
Use first result's `iid`. If none found → report "No open MR for branch" and stop.

**If code_platform.provider = github:**

Find PR:
```bash
gh pr list --head "<source-branch>" --state open --json number,url,title
```
Use first result's `number`. If none found → report "No open PR for branch" and stop.

### 2. Get changed file list (lightweight)

**If code_platform.provider = gitlab:**
```
MCP tool: list_merge_request_changed_files
Parameters: { project_id: "<project-path>", merge_request_iid: "<mr-iid>" }
```

**If code_platform.provider = github:**
```bash
gh pr diff <pr-number> --name-only
```

This returns only file paths — NOT full diffs. Use this to determine which rules apply.

### 3. Load and filter review rules

Read rules from path specified in `review.rules_path` (default: `~/.dev-agent-harness/review-rules.yml`).

**Filter rules**: For each rule, check if its `applies_to` glob matches ANY changed file path. Discard rules that don't match any changed files.

**Filter files**: Exclude files matching any rule's `exclude` pattern from review.

Record: which rules apply to which files.

### 4. Fetch diffs selectively

Only fetch diffs for files that have at least one applicable rule:

**If code_platform.provider = gitlab:**
```
MCP tool: get_merge_request_file_diff
Parameters:
  project_id: "<project-path>"
  merge_request_iid: "<mr-iid>"
  file_paths: [<only files with matching rules>]
```

**If code_platform.provider = github:**
```bash
gh pr diff <pr-number> -- <file1> <file2> ...
```

Or if selective diff not supported:
```bash
gh pr diff <pr-number>
```
Then filter to only relevant file sections.

Skip files that no rule applies to (e.g., README.md, .yml configs, images).

### 5. Analyse changes against rules

For each file diff, apply only its matching rules:
- Examine **added/modified lines only** — never flag removed lines.
- Only flag **clear violations**, not borderline cases.
- Consider context (test code vs production).
- Group related findings.

For each violation, record: rule ID, severity, file, line, explanation.

### 6. Post findings to MR/PR

**If code_platform.provider = gitlab:**

Post each finding immediately:
```
MCP tool: create_merge_request_note
Parameters:
  project_id: "<project-path>"
  merge_request_iid: "<mr-iid>"
  body: |
    **[<SEVERITY>]** `<RULE-ID>`: <rule-name>

    <explanation>

    > **Rationale:** <rationale>

    ---
    _Automated review · review-mr_
```

**If code_platform.provider = github:**

Post each finding as a PR review comment:
```bash
gh pr comment <pr-number> --body "**[<SEVERITY>]** \`<RULE-ID>\`: <rule-name>

<explanation>

> **Rationale:** <rationale>

---
_Automated review · review-mr_"
```

Or use the GitHub review API for inline comments:
```bash
gh api repos/<project-path>/pulls/<pr-number>/comments \
  -f body="<comment>" \
  -f path="<file>" \
  -f line=<line-number> \
  -f side="RIGHT"
```

Severity labels from config: `review.severity_labels.required`, `.recommendation`, `.suggestion`

### 7. Post summary

**If code_platform.provider = gitlab:**
```
MCP tool: create_merge_request_note
Parameters:
  project_id: "<project-path>"
  merge_request_iid: "<mr-iid>"
  body: |
    ## 🔍 Automated MR Review Summary

    | Severity | Count |
    |----------|-------|
    | 🔴 Required | <N> |
    | 🟡 Recommendation | <N> |
    | 🟢 Suggestion | <N> |

    **Files reviewed:** <count> / <total changed>
    **Rules applied:** <count> / <total rules> (filtered to relevant)

    <⚠️ or ✅ message>

    ---
    _review-mr · selective diff mode_
```

**If code_platform.provider = github:**
```bash
gh pr comment <pr-number> --body "## 🔍 Automated PR Review Summary

| Severity | Count |
|----------|-------|
| 🔴 Required | <N> |
| 🟡 Recommendation | <N> |
| 🟢 Suggestion | <N> |

**Files reviewed:** <count> / <total changed>
**Rules applied:** <count> / <total rules> (filtered to relevant)

<⚠️ or ✅ message>

---
_review-mr · selective diff mode_"
```

### 8. Report to user

Brief summary:
- MR/PR reviewed: `<title>` (`!<iid>` or `#<number>`)
- Findings: X required, Y recommendations, Z suggestions
- Comments posted to: `<MR/PR URL>`

## Token Usage Report

After completion, output:
```
📊 review-mr token usage:
  Files changed (total): <N>
  Files reviewed (filtered): <M> (skipped <N-M> non-matching)
  Rules loaded: <R> / <total> (filtered to applicable)
  Diff lines in context: ~<L>
  MCP/API calls: <count>
  Estimated context: ~<total> tokens
  Savings vs full-diff: ~<percentage>% reduction
```
