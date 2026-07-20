---
name: finish-story
description: Finishes work on a ticket - runs tests, verifies files, commits, pushes, creates MR/PR, posts issue tracker update, and triggers review. Use when ready to submit work.
---

## Inputs

| Parameter | Description |
|-----------|-------------|
| ticket-id | Ticket ID. If not provided, infer from branch name. |

## Config Resolution

Read `~/.dev-agent-harness/config.yml` and resolve:
- `code_platform.provider` → `gitlab` or `github`
- `code_platform.<provider>.default_target_branch` → target branch
- `code_platform.<provider>.auth.token_path` → read token from file
- `issue_tracker.provider` → `jira`, `github-issues`, or `linear`
- `issue_tracker.<provider>.auth.token_path` → read token from file
- `commits.format` → `conventional` or `simple`
- `branching.feature_prefix` / `branching.fix_prefix` → for commit prefix detection

Store resolved values for use in subsequent steps.

## Execution

Execute in order. Pause only for file acceptance (Step 2).

## Steps

### 1. Run tests (truncated output)

Detect build tool and run tests in quiet mode:
```bash
# Maven
mvn test -q 2>&1 | tail -30

# Gradle
./gradlew test --console=plain 2>&1 | tail -30

# npm/yarn
npm test 2>&1 | tail -30

# pytest
pytest -q 2>&1 | tail -30

# go
go test ./... 2>&1 | tail -30
```

- **Pass** → report success, continue.
- **Fail** → show last 30 lines only. Ask user to proceed or debug. Do NOT continue until confirmed.

### 2. Show modified files

```bash
git status --short
```

- Exclude: `*.properties`, `*.env`, `*credentials*`, `*secrets*`, `spec.md`
- Show remaining files. **Wait for user acceptance.**

### 3. Stage and commit

- Stage accepted files only.
- Determine prefix from branch name:
  - `{branching.feature_prefix}/` → feature prefix (e.g., `feat:`)
  - `{branching.fix_prefix}/` → fix prefix (e.g., `fix:`)

Commit message format based on `commits.format`:
- **conventional**: `<prefix>: <ticket-id> <short message>`
- **simple**: `<ticket-id>: <short message>`

### 4. Push

```bash
git push -u origin <current-branch>
```

### 5. Create or find MR/PR

Get project path:
```bash
git remote get-url origin
```
Extract path (after hostname, without `.git`).

**If code_platform.provider = gitlab:**

Check for existing MR:
```
MCP tool: list_merge_requests
Parameters: { project_id: "<project-path>", source_branch: "<branch>", target_branch: "<target-branch>", state: "opened" }
```

- **MR exists** → show URL.
- **No MR** → read template from `~/.dev-agent-harness/mr-template.md` (or co-located `mr-template.md`), then:
  ```
  MCP tool: create_merge_request
  Parameters:
    project_id: "<project-path>"
    title: "<prefix>: <ticket-id> <short message>"
    source_branch: "<branch>"
    target_branch: "<target-branch>"
    description: <contents of mr-template.md, filled in>
  ```

**If code_platform.provider = github:**

Check for existing PR:
```bash
gh pr list --head "<branch>" --base "<target-branch>" --state open --json number,url
```

- **PR exists** → show URL.
- **No PR** → read template from `~/.dev-agent-harness/mr-template.md` (or co-located `mr-template.md`), then:
  ```bash
  gh pr create \
    --title "<prefix>: <ticket-id> <short message>" \
    --base "<target-branch>" \
    --body "<contents of mr-template.md, filled in>"
  ```

### 6. Post issue tracker update

**If issue_tracker.provider = jira:**

Auth: Read token from `issue_tracker.jira.auth.token_path`.

Build summary from: `git diff --stat <target-branch>...HEAD`, commit messages, `spec.md`.

Post (field-filtered, concise):
```bash
curl -s -X POST \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"body": "<summary>"}' \
  "{issue_tracker.jira.base_url}/rest/api/2/issue/<ticket-id>/comment"
```

**If issue_tracker.provider = github-issues:**

```bash
gh issue comment <ticket-number> --repo <project-path> --body "<summary>"
```

**If issue_tracker.provider = linear:**

Auth: Read token from `issue_tracker.linear.auth.token_path`.

```bash
curl -s -X POST "{issue_tracker.linear.api_url}/graphql" \
  -H "Authorization: <token>" \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { commentCreate(input: { issueId: \"<ticket-id>\", body: \"<summary>\" }) { success } }"}'
```

Summary format (all providers):
```
*Development Update — <branch>*
*Changes:* • <max 5 bullet points>
*Files modified:* <count> | *MR/PR:* <URL> | *Status:* Ready for review
```

If API fails, warn but continue.

### 7. Trigger MR/PR review

Immediately execute the `review-mr` skill using the project path and branch from Step 5. Do NOT ask — proceed directly.

## Token Usage Report

After completion, output:
```
📊 finish-story token usage:
  Test output: <N> lines captured (truncated mode)
  MR/PR template: loaded from file (not inline)
  Issue comment: <N> chars posted
  MCP/API calls: <count>
  Estimated context: ~<total> tokens
```
