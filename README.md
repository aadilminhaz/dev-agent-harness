# Dev Agent Harness

> **From ticket to merge request — one command, any AI agent.**

Dev Agent Harness gives your AI coding assistant (Kiro CLI, Claude Code, or Codex) the skills to run your entire development workflow: pick up a ticket, write code, run tests, push, and open a reviewed MR/PR — hands-free.

---

## Why

AI coding agents are powerful, but they don't know *your* workflow. They don't know where your tickets live, how you name branches, or how to open a merge request on your platform.

Dev Agent Harness bridges that gap. Install once, and your agent speaks your team's process fluently.

---

## What You Get

| Skill | What it does |
|-------|-------------|
| **start-story** | Clones the repo, creates a branch, auto-generates `spec.md` from your ticket |
| **finish-story** | Runs tests, commits, pushes, opens MR/PR, posts issue update, **auto-reviews the MR** |
| **review-mr** | Reviews the diff against 18 coding standards, posts categorised comments |
| **full-lifecycle** | All of the above in one shot — ticket to reviewed MR |

---

## Supported Platforms

| | Options |
|---|---|
| **Issue Trackers** | Jira · GitHub Issues · Linear |
| **Code Platforms** | GitLab · GitHub |
| **AI Agents** | Kiro CLI · Claude Code · Codex |

Mix and match. The installer handles the wiring.

---

## Install

```bash
git clone https://github.com/aadilminhaz/dev-agent-harness.git
cd dev-agent-harness
./install.sh
```

The installer walks you through:

```
1. Pick your AI agent        →  Kiro CLI / Claude Code / Codex
2. Pick your issue tracker   →  Jira / GitHub Issues / Linear
3. Pick your code platform   →  GitLab / GitHub
4. Set preferences           →  Target branch, IDE, branch naming
```

That's it. Config is saved to `~/.dev-agent-harness/config.yml`, skills are installed to the right place for your agent, and MCP is configured for platform API access.

---

## Usage

Once installed, just talk to your agent:

### Start Story — Auto-generates `spec.md`

```
start story on order-service, ticket PROJ-1234, feature
```

This does:
1. Finds and clones the repo from your code platform
2. Creates a `feat/PROJ-1234` branch from your target branch
3. **Fetches the ticket from your issue tracker and generates a `spec.md`** — a structured requirements document with summary, problem statement, requirements, acceptance criteria, and testing notes
4. Opens your configured IDE

The generated `spec.md` becomes the single source of truth for what needs to be built.

---

### Develop with `spec.md` — Spec-Driven Development

> This isn't a separate skill — it's how you work between `start-story` and `finish-story`.

Once `spec.md` is generated, you use it to drive the implementation. Tell your agent:

```
implement the requirements in spec.md
```
```
look at spec.md and write the code for this ticket
```
```
work through each requirement in spec.md, write code and tests
```

Your agent will:
1. Read `spec.md` to understand the requirements
2. Analyse the project structure and existing patterns
3. Implement the changes — production code + tests
4. Verify tests pass

**Why spec-driven?** The `spec.md` gives the agent clear, structured context about *what* to build. It's more reliable than a vague prompt because the requirements came directly from your issue tracker, formatted into an actionable document.

**Tip:** Review and enrich `spec.md` before asking the agent to implement — add edge cases, architectural notes, or links to related files. The richer the spec, the better the output.

---

### Finish Story — With Automatic Review

```
finish story
```

This does:
1. Runs the test suite (fails? stops and reports)
2. Shows modified files for your approval
3. Commits with conventional format (`feat: PROJ-1234 description`)
4. Pushes the branch
5. Creates MR/PR on your code platform
6. Posts a summary comment on the ticket
7. **Automatically triggers a code review** — analyses the diff against 18 rules and posts categorised findings (`[REQUIRED]`, `[RECOMMENDATION]`, `[SUGGESTION]`) directly on the MR/PR

You get a reviewed MR without running a separate command.

---

### Review MR — Standalone Review

```
review the MR
```

Use this for on-demand reviews (e.g., reviewing someone else's MR, or re-reviewing after changes). Fetches the diff, applies only relevant rules, posts findings as comments with severity levels.

---

### Full Lifecycle — Fully Autonomous

```
full lifecycle on order-service, ticket PROJ-1234, feature
```

Runs everything end-to-end: start → analyse → implement → finish → review. Only pauses for your file approval before committing. One command, ticket to reviewed MR.

---

## Workflow: Step-by-Step vs Autonomous

**Step-by-step** (more control):
```
start story on order-service, ticket PROJ-1234, feature   ← sets up branch + spec.md
implement spec.md                                         ← you guide the coding
finish story                                              ← commit, push, MR, review
```

**Fully autonomous** (hands-off):
```
full lifecycle on order-service, ticket PROJ-1234, feature
```

Both paths produce the same outcome: a pushed branch with an MR/PR and automated review comments.

---

## How It Works

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Issue Tracker│────▶│  Dev Agent Harness│────▶│  Code Platform  │
│ (Jira/GH/   │     │                  │     │  (GitLab/GitHub) │
│  Linear)     │     │  Skills + Config │     │                 │
└─────────────┘     └──────────────────┘     └─────────────────┘
                            │
                     ┌──────┴──────┐
                     │  AI Agent    │
                     │ (Kiro/Claude │
                     │  /Codex)     │
                     └─────────────┘
```

1. Skills read `~/.dev-agent-harness/config.yml` to know which APIs to call
2. The agent executes the skill steps using MCP (for GitLab/GitHub API) or CLI tools
3. Everything adapts at runtime — same skills, different platforms

---

## Where Things Live After Install

**Kiro CLI:**
```
~/.kiro/skills/start-story/SKILL.md
~/.kiro/skills/finish-story/SKILL.md
~/.kiro/skills/review-mr/SKILL.md
~/.kiro/skills/full-lifecycle/SKILL.md
~/.kiro/settings/mcp.json
```

**Claude Code:**
```
~/.claude/CLAUDE.md           # All skills as system prompt
~/.claude/commands/           # Slash commands per skill
~/.claude/mcp.json
```

**Codex:**
```
~/.codex/instructions.md      # All skills combined
```

---

## Configuration

Generated at `~/.dev-agent-harness/config.yml`:

```yaml
issue_source:
  type: jira
  jira:
    base_url: "https://jira.example.com"
    auth:
      token_path: "~/.dev-agent-harness/secrets/jira-token"

code_platform:
  type: github
  github:
    default_branch: "main"
    clone_protocol: https

agent:
  type: kiro-cli

preferences:
  ide: vscode
  branch_prefix_feature: "feat"
  branch_prefix_fix: "fix"
  commit_format: conventional
```

Tokens are stored separately in `~/.dev-agent-harness/secrets/` with `chmod 600`.

---

## Review Rules

The automated reviewer checks for:

| Category | Rules |
|----------|-------|
| **Security** | No hardcoded secrets, no SQL concatenation, input validation |
| **Code Quality** | No commented code, no magic numbers, TODOs need tickets, no empty catches |
| **Testing** | New logic needs tests, no skipped tests |
| **Architecture** | Layered architecture respected, no circular deps |
| **Performance** | No N+1 queries, pagination on list endpoints |
| **Style** | Naming conventions, meaningful variable names |
| **Docs** | Public APIs documented, breaking changes noted |

Rules are in `~/.dev-agent-harness/review-rules.yml` — edit to match your team's standards.

---

## Project Structure

```
dev-agent-harness/
├── install.sh                        # Interactive installer
├── skills/
│   ├── start-story/SKILL.md          # Start work + generate spec.md
│   ├── finish-story/
│   │   ├── SKILL.md                  # Finish + auto-review
│   │   └── mr-template.md            # MR/PR description template
│   ├── review-mr/
│   │   ├── SKILL.md                  # Standalone code review
│   │   └── review-rules.yml          # Review rules (18 rules)
│   └── full-lifecycle/SKILL.md       # End-to-end automation
├── mcp/
│   ├── gitlab-mcp.json               # GitLab MCP template
│   └── github-mcp.json               # GitHub MCP template
├── config/
│   ├── config.schema.yml             # Config schema reference
│   └── config.example.yml            # Example configurations
└── README.md
```

---

## Contributing

PRs welcome. Some ideas:

- **New platforms** — Bitbucket, Azure DevOps, Shortcut, Notion
- **New agents** — Aider, Continue, Windsurf
- **Better rules** — Language-specific review rules (Go, Rust, Python)
- **Bug fixes** — Cross-platform edge cases

```bash
git checkout -b feat/your-feature
# make changes
git commit -m "feat: your feature"
# open a PR
```

---

## License

MIT — see [LICENSE](LICENSE).
