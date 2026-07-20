---
name: start-story
description: Starts work on a new ticket - finds the service on the code platform, clones it, creates branch, fetches ticket into spec.md, and opens IDE. Use when beginning work on a ticket.
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
- `code_platform.<provider>.base_url` → platform URL
- `code_platform.<provider>.auth.token_path` → read token from file
- `code_platform.<provider>.default_target_branch` → target branch (e.g., `main`, `development`)
- `code_platform.<provider>.clone_protocol` → `https` or `ssh`
- `issue_tracker.provider` → `jira`, `github-issues`, or `linear`
- `issue_tracker.<provider>.auth.token_path` → read token from file
- `branching.feature_prefix` / `branching.fix_prefix` → branch prefix
- `branching.separator` → separator character
- `ide.open_command` → IDE to open

Store resolved values for use in subsequent steps.

## Execution

Execute all steps automatically. Only pause if multiple repo matches are found (Step 1).

## Steps

### 1. Resolve project/repository

**If code_platform.provider = gitlab:**
```
MCP tool: search_repositories
Parameters:
  query: "<service-name>"
```

Resolution:
- Filter results to **exact name matches** (repo name = `<service-name>`).
- **1 match** → use `path_with_namespace` as `<project-path>`. Proceed.
- **Multiple matches** → show numbered list, ask user to select.
- **0 matches** → ask user for full project path.

Clone URL (https): `{code_platform.gitlab.base_url}/<project-path>.git`
Clone URL (ssh): `git@{hostname}:<project-path>.git`

**If code_platform.provider = github:**
```bash
gh repo list --json name,nameWithOwner --jq '.[] | select(.name == "<service-name>")'
```

Or via GitHub MCP:
```
MCP tool: search_repositories
Parameters:
  query: "<service-name>"
```

Resolution:
- Filter results to **exact name matches**.
- **1 match** → use `nameWithOwner` as `<project-path>`. Proceed.
- **Multiple matches** → show numbered list, ask user to select.
- **0 matches** → ask user for full `owner/repo`.

Clone URL (https): `https://github.com/<project-path>.git`
Clone URL (ssh): `git@github.com:<project-path>.git`

### 2. Clone and checkout

```bash
git clone <clone-url>
cd <service-name>
git checkout <target-branch> && git pull origin <target-branch>
```

Where `<target-branch>` = `code_platform.<provider>.default_target_branch` from config.

Branch name: `<prefix><separator><ticket-id>`
- feature → `{branching.feature_prefix}{branching.separator}<ticket-id>`
- fix → `{branching.fix_prefix}{branching.separator}<ticket-id>`

Check if branch exists:

**If code_platform.provider = gitlab:**
```
MCP tool: list_branches
Parameters: { project_id: "<project-path>", search: "<branch-name>" }
```

- Exists → `git checkout <branch-name> && git pull origin <branch-name>`
- Not exists → create via MCP (`create_branch`, ref: `<target-branch>`), then `git fetch origin && git checkout <branch-name>`

**If code_platform.provider = github:**
```bash
gh api repos/<project-path>/branches/<branch-name> 2>/dev/null
```

- Exists → `git checkout <branch-name> && git pull origin <branch-name>`
- Not exists → `git checkout -b <branch-name> && git push -u origin <branch-name>`

### 3. Fetch ticket and create spec.md

**If issue_tracker.provider = jira:**

Auth: Read token from path specified in `issue_tracker.jira.auth.token_path`. If missing, ask user, save it.

Fetch with field filter (reduces response size):
```bash
curl -s -H "Authorization: Bearer <token>" \
  "{issue_tracker.jira.base_url}/rest/api/2/issue/<ticket-id>?fields=summary,description,status,issuetype,{issue_tracker.jira.fields.acceptance_criteria}"
```

Extract: summary, description, acceptance criteria (custom field from config), status, type.

**If issue_tracker.provider = github-issues:**

Extract ticket number from `<ticket-id>` (e.g., `#42` → `42`).

```bash
gh issue view <number> --repo <project-path> --json title,body,labels,state
```

Extract: title (as summary), body (as description/requirements), labels, state.

**If issue_tracker.provider = linear:**

Auth: Read token from `issue_tracker.linear.auth.token_path`.

```bash
curl -s -X POST "{issue_tracker.linear.api_url}/graphql" \
  -H "Authorization: <token>" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ issue(id: \"<ticket-id>\") { title description state { name } labels { nodes { name } } } }"}'
```

Extract: title (as summary), description, state, labels.

**Create `spec.md`:**
```markdown
# Ticket Spec
## Ticket ID
<ticket-id>
## Summary
<summary/title>
## Problem Statement
<from description>
## Requirements
<from description>
## Acceptance Criteria
<from acceptance criteria field or description>
## Testing
Write new test cases for changes. Ensure all tests pass.
## Notes
<!-- Additional context -->
```

If ticket info is sparse, tell user to enrich `spec.md`.

### 4. Open IDE

Based on `ide.open_command` from config:

| Config Value | Command |
|---|---|
| `code` | `code .` |
| `idea` | `open -a "IntelliJ IDEA" .` (macOS) or `idea .` (Linux/Windows) |
| `cursor` | `cursor .` |
| `none` | Skip — do not open any IDE |

## Token Usage Report

After completion, output:
```
📊 start-story token usage:
  Issue response: ~<X> lines (field-filtered)
  Repository search results: <N> repos returned
  MCP/API calls: <count>
  Estimated context: ~<total> tokens
```
