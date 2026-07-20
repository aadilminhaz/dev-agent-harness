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
| **start-story** | Clones the repo, creates a branch from your ticket, pulls requirements into a `spec.md` |
| **finish-story** | Runs tests, commits, pushes, opens MR/PR, posts update to your issue tracker |
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
git clone https://github.com/AadilMinhworx/dev-agent-harness.git
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

```
start story on order-service, ticket PROJ-1234, feature
```
→ Clones repo, creates `feat/PROJ-1234` branch, fetches ticket into `spec.md`, opens IDE.

```
finish story
```
→ Tests pass → commit → push → MR created → Jira comment posted → auto-review triggered.

```
review the MR
```
→ Fetches diff, applies rules, posts findings as MR/PR comments with severity levels.

```
full lifecycle on order-service, ticket PROJ-1234, feature
```
→ Everything above, end to end, autonomously.

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
│   ├── start-story/SKILL.md          # Start work on a ticket
│   ├── finish-story/
│   │   ├── SKILL.md                  # Finish and create MR/PR
│   │   └── mr-template.md            # MR/PR description template
│   ├── review-mr/
│   │   ├── SKILL.md                  # Automated code review
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
