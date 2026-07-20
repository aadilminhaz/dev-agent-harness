#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Dev Agent Harness — Interactive Installer
# ═══════════════════════════════════════════════════════════════════════════════
# Configures issue tracking, code platform, AI agent, and installs skills/MCP.
# Safe to re-run — merges config, never blindly overwrites.
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Paths ────────────────────────────────────────────────────────────────────
HARNESS_DIR="$HOME/.dev-agent-harness"
SECRETS_DIR="$HARNESS_DIR/secrets"
CONFIG_FILE="$HARNESS_DIR/config.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
MCP_TEMPLATES="$SCRIPT_DIR/mcp"

# ─── Colours ──────────────────────────────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
banner() {
  echo ""
  echo -e "${CYAN}${BOLD}"
  echo "  ╔══════════════════════════════════════════════════════════════╗"
  echo "  ║                                                              ║"
  echo "  ║        Dev Agent Harness                                     ║"
  echo "  ║        Open Source Development Automation                    ║"
  echo "  ║                                                              ║"
  echo "  ╚══════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
  echo -e "  ${BOLD}Interactive Installer${RESET}"
  echo "  Configures your AI agent, issue tracker, code platform, and preferences."
  echo ""
}

info()    { echo -e "  ${CYAN}ℹ${RESET}  $1"; }
success() { echo -e "  ${GREEN}✅${RESET} $1"; }
warn()    { echo -e "  ${YELLOW}⚠️${RESET}  $1"; }
error()   { echo -e "  ${RED}❌${RESET} $1"; }

prompt_choice() {
  local prompt="$1"
  shift
  local options=("$@")
  echo ""
  echo -e "  ${BOLD}${prompt}${RESET}"
  for i in "${!options[@]}"; do
    echo "    [$((i + 1))] ${options[$i]}"
  done
  echo ""
  while true; do
    read -p "  → Choice [1-${#options[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
      return $((choice - 1))
    fi
    echo -e "  ${RED}Invalid choice. Please enter a number between 1 and ${#options[@]}.${RESET}"
  done
}

prompt_input() {
  local prompt="$1"
  local default="${2:-}"
  local is_secret="${3:-false}"

  if [ -n "$default" ]; then
    prompt="$prompt [$default]"
  fi

  if [ "$is_secret" = "true" ]; then
    read -s -p "  → $prompt: " value
    echo ""
  else
    read -p "  → $prompt: " value
  fi

  echo "${value:-$default}"
}

write_secret() {
  local filename="$1"
  local value="$2"
  local filepath="$SECRETS_DIR/$filename"

  mkdir -p "$SECRETS_DIR"
  echo "$value" > "$filepath"
  chmod 600 "$filepath"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

banner

# Check for existing config
if [ -f "$CONFIG_FILE" ]; then
  warn "Existing config found at $CONFIG_FILE"
  echo ""
  read -p "  → Overwrite with new configuration? (y/N): " overwrite
  if [[ ! "$overwrite" =~ ^[Yy] ]]; then
    info "Keeping existing config. Re-running installation steps only."
    echo ""
    # Source existing config values if needed — for now, just skip collection
    RERUN_ONLY=true
  else
    RERUN_ONLY=false
  fi
else
  RERUN_ONLY=false
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: AI Agent Selection
# ═══════════════════════════════════════════════════════════════════════════════

if [ "${RERUN_ONLY:-false}" = "false" ]; then

  prompt_choice "Which AI agent are you using?" "Kiro CLI" "Claude Code" "Codex"
  agent_choice=$?
  case $agent_choice in
    0) AGENT_TYPE="kiro-cli" ;;
    1) AGENT_TYPE="claude-code" ;;
    2) AGENT_TYPE="codex" ;;
  esac
  success "Agent: $AGENT_TYPE"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Issue Tracker
# ═══════════════════════════════════════════════════════════════════════════════

  prompt_choice "Where do your tickets/issues come from?" "Jira" "GitHub Issues" "Linear"
  issue_choice=$?

  case $issue_choice in
    0)
      ISSUE_TYPE="jira"
      echo ""
      info "Jira Configuration"
      JIRA_BASE_URL=$(prompt_input "Jira base URL (e.g., https://jira.example.com)" "")
      while [ -z "$JIRA_BASE_URL" ]; do
        error "Jira base URL is required."
        JIRA_BASE_URL=$(prompt_input "Jira base URL" "")
      done
      JIRA_TOKEN=$(prompt_input "Jira API token" "" "true")
      while [ -z "$JIRA_TOKEN" ]; do
        error "Jira API token is required."
        JIRA_TOKEN=$(prompt_input "Jira API token" "" "true")
      done
      JIRA_PROJECT_KEY=$(prompt_input "Jira project key (e.g., PROJ)" "")
      ;;
    1)
      ISSUE_TYPE="github"
      echo ""
      info "GitHub Issues Configuration"
      info "Authentication will use your code platform token (configured next)."
      GITHUB_ISSUES_OWNER=$(prompt_input "Repository owner (user or org)" "")
      while [ -z "$GITHUB_ISSUES_OWNER" ]; do
        error "Repository owner is required."
        GITHUB_ISSUES_OWNER=$(prompt_input "Repository owner" "")
      done
      GITHUB_ISSUES_REPO=$(prompt_input "Repository name" "")
      while [ -z "$GITHUB_ISSUES_REPO" ]; do
        error "Repository name is required."
        GITHUB_ISSUES_REPO=$(prompt_input "Repository name" "")
      done
      ;;
    2)
      ISSUE_TYPE="linear"
      echo ""
      info "Linear Configuration"
      LINEAR_API_KEY=$(prompt_input "Linear API key" "" "true")
      while [ -z "$LINEAR_API_KEY" ]; do
        error "Linear API key is required."
        LINEAR_API_KEY=$(prompt_input "Linear API key" "" "true")
      done
      LINEAR_TEAM_ID=$(prompt_input "Linear team ID (e.g., ENG)" "")
      while [ -z "$LINEAR_TEAM_ID" ]; do
        error "Linear team ID is required."
        LINEAR_TEAM_ID=$(prompt_input "Linear team ID" "")
      done
      ;;
  esac
  success "Issue tracker: $ISSUE_TYPE"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Code Platform
# ═══════════════════════════════════════════════════════════════════════════════

  prompt_choice "Where does your code live?" "GitLab" "GitHub"
  code_choice=$?

  case $code_choice in
    0)
      CODE_PLATFORM="gitlab"
      echo ""
      info "GitLab Configuration"
      GITLAB_API_URL=$(prompt_input "GitLab API URL" "https://gitlab.com/api/v4")
      GITLAB_TOKEN=$(prompt_input "GitLab Personal Access Token (scopes: api, read_repository)" "" "true")
      while [ -z "$GITLAB_TOKEN" ]; do
        error "GitLab PAT is required."
        GITLAB_TOKEN=$(prompt_input "GitLab Personal Access Token" "" "true")
      done
      # Derive base URL from API URL
      GITLAB_BASE_URL="${GITLAB_API_URL%/api/v4}"
      ;;
    1)
      CODE_PLATFORM="github"
      echo ""
      info "GitHub Configuration"
      echo ""
      prompt_choice "Authentication method:" "Personal Access Token" "Use gh CLI auth (must be logged in)"
      auth_choice=$?
      if [ $auth_choice -eq 0 ]; then
        GITHUB_AUTH_METHOD="token"
        GITHUB_TOKEN=$(prompt_input "GitHub Personal Access Token (scopes: repo, read:org)" "" "true")
        while [ -z "$GITHUB_TOKEN" ]; do
          error "GitHub PAT is required."
          GITHUB_TOKEN=$(prompt_input "GitHub Personal Access Token" "" "true")
        done
      else
        GITHUB_AUTH_METHOD="gh-cli"
        GITHUB_TOKEN=""
        # Verify gh is available
        if ! command -v gh &>/dev/null; then
          warn "gh CLI not found. Install it from https://cli.github.com"
          warn "You can still proceed — just ensure gh is installed before using skills."
        elif ! gh auth status &>/dev/null 2>&1; then
          warn "gh CLI is not authenticated. Run 'gh auth login' before using skills."
        else
          success "gh CLI authenticated"
        fi
      fi
      ;;
  esac
  success "Code platform: $CODE_PLATFORM"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: Default Target Branch
# ═══════════════════════════════════════════════════════════════════════════════

  echo ""
  DEFAULT_BRANCH=$(prompt_input "Default target branch for MRs/PRs" "main")
  success "Target branch: $DEFAULT_BRANCH"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: IDE Preference
# ═══════════════════════════════════════════════════════════════════════════════

  prompt_choice "Preferred IDE?" "IntelliJ IDEA" "VS Code" "Cursor" "None"
  ide_choice=$?
  case $ide_choice in
    0) IDE="intellij" ;;
    1) IDE="vscode" ;;
    2) IDE="cursor" ;;
    3) IDE="none" ;;
  esac
  success "IDE: $IDE"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: Write Config & Secrets
# ═══════════════════════════════════════════════════════════════════════════════

  echo ""
  echo -e "  ${BOLD}Writing configuration...${RESET}"
  echo ""

  mkdir -p "$HARNESS_DIR"
  mkdir -p "$SECRETS_DIR"

  # Write secrets and .gitignore
  echo "*" > "$SECRETS_DIR/.gitignore"

  if [ "$ISSUE_TYPE" = "jira" ] && [ -n "${JIRA_TOKEN:-}" ]; then
    write_secret "jira-token" "$JIRA_TOKEN"
    success "Jira token saved to $SECRETS_DIR/jira-token"
  fi

  if [ "$ISSUE_TYPE" = "linear" ] && [ -n "${LINEAR_API_KEY:-}" ]; then
    write_secret "linear-token" "$LINEAR_API_KEY"
    success "Linear API key saved to $SECRETS_DIR/linear-token"
  fi

  if [ "$CODE_PLATFORM" = "gitlab" ] && [ -n "${GITLAB_TOKEN:-}" ]; then
    write_secret "gitlab-token" "$GITLAB_TOKEN"
    success "GitLab token saved to $SECRETS_DIR/gitlab-token"
  fi

  if [ "$CODE_PLATFORM" = "github" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
    write_secret "github-token" "$GITHUB_TOKEN"
    success "GitHub token saved to $SECRETS_DIR/github-token"
  fi

  # ─── Generate config.yml ──────────────────────────────────────────────────
  cat > "$CONFIG_FILE" <<YAML
# ═══════════════════════════════════════════════════════════════════════════════
# Dev Agent Harness — Configuration
# Generated by install.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# ═══════════════════════════════════════════════════════════════════════════════

schema_version: "1.0"

# ─── Issue Source ──────────────────────────────────────────────────────────────
issue_source:
  type: $ISSUE_TYPE
YAML

  case $ISSUE_TYPE in
    jira)
      cat >> "$CONFIG_FILE" <<YAML
  jira:
    base_url: "$JIRA_BASE_URL"
    auth:
      token_path: "~/.dev-agent-harness/secrets/jira-token"
      type: bearer
    project_key: "${JIRA_PROJECT_KEY:-}"
YAML
      ;;
    github)
      cat >> "$CONFIG_FILE" <<YAML
  github:
    base_url: "https://api.github.com"
    auth:
      method: ${GITHUB_AUTH_METHOD:-token}
      token_path: "~/.dev-agent-harness/secrets/github-token"
    owner: "$GITHUB_ISSUES_OWNER"
    repo: "$GITHUB_ISSUES_REPO"
YAML
      ;;
    linear)
      cat >> "$CONFIG_FILE" <<YAML
  linear:
    base_url: "https://api.linear.app/graphql"
    auth:
      token_path: "~/.dev-agent-harness/secrets/linear-token"
    team_key: "$LINEAR_TEAM_ID"
YAML
      ;;
  esac

  cat >> "$CONFIG_FILE" <<YAML

# ─── Code Platform ────────────────────────────────────────────────────────────
code_platform:
  type: $CODE_PLATFORM
YAML

  case $CODE_PLATFORM in
    gitlab)
      cat >> "$CONFIG_FILE" <<YAML
  gitlab:
    base_url: "$GITLAB_BASE_URL"
    api_url: "$GITLAB_API_URL"
    auth:
      token_path: "~/.dev-agent-harness/secrets/gitlab-token"
    default_branch: "$DEFAULT_BRANCH"
    clone_protocol: https
YAML
      ;;
    github)
      cat >> "$CONFIG_FILE" <<YAML
  github:
    base_url: "https://api.github.com"
    auth:
      token_path: "~/.dev-agent-harness/secrets/github-token"
      method: ${GITHUB_AUTH_METHOD:-token}
    default_branch: "$DEFAULT_BRANCH"
    clone_protocol: https
YAML
      ;;
  esac

  cat >> "$CONFIG_FILE" <<YAML

# ─── Agent ────────────────────────────────────────────────────────────────────
agent:
  type: $AGENT_TYPE

# ─── Preferences ──────────────────────────────────────────────────────────────
preferences:
  ide: $IDE
  branch_prefix_feature: "feat"
  branch_prefix_fix: "fix"
  branch_separator: "/"
  commit_format: conventional
  review:
    rules_path: "~/.dev-agent-harness/review-rules.yml"
    post_comments: true
    severity_labels:
      required: "🔴 REQUIRED"
      recommendation: "🟡 RECOMMENDATION"
      suggestion: "🟢 SUGGESTION"
YAML

  success "Config written to $CONFIG_FILE"

  # Copy review-rules.yml if available
  REVIEW_RULES_SRC="$SCRIPT_DIR/skills/review-mr/review-rules.yml"
  if [ -f "$REVIEW_RULES_SRC" ] && [ ! -f "$HARNESS_DIR/review-rules.yml" ]; then
    cp "$REVIEW_RULES_SRC" "$HARNESS_DIR/review-rules.yml"
    success "Review rules installed to $HARNESS_DIR/review-rules.yml"
  fi

fi  # end of RERUN_ONLY check

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: Install Skills & MCP (Agent-Specific)
# ═══════════════════════════════════════════════════════════════════════════════

# Re-read agent type from config if doing a re-run
if [ "${RERUN_ONLY:-false}" = "true" ]; then
  AGENT_TYPE=$(grep "^  type:" "$CONFIG_FILE" | head -1 | awk '{print $2}' | tr -d '"')
  CODE_PLATFORM=$(grep "^  type:" "$CONFIG_FILE" | sed -n '2p' | awk '{print $2}' | tr -d '"')
  # Read tokens from existing secret files
  if [ -f "$SECRETS_DIR/gitlab-token" ]; then
    GITLAB_TOKEN=$(cat "$SECRETS_DIR/gitlab-token")
  fi
  if [ -f "$SECRETS_DIR/github-token" ]; then
    GITHUB_TOKEN=$(cat "$SECRETS_DIR/github-token")
  fi
  # Read GITLAB_API_URL from config
  GITLAB_API_URL=$(grep "api_url:" "$CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "")
fi

echo ""
echo -e "  ${BOLD}Installing skills for ${AGENT_TYPE}...${RESET}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Kiro CLI Installation
# ─────────────────────────────────────────────────────────────────────────────
install_kiro() {
  local KIRO_SKILLS_DIR="$HOME/.kiro/skills"
  local KIRO_MCP_DIR="$HOME/.kiro/settings"

  mkdir -p "$KIRO_SKILLS_DIR"
  mkdir -p "$KIRO_MCP_DIR"

  # Install skills
  if [ -d "$SKILLS_SRC" ]; then
    local skill_count=0
    for skill_dir in "$SKILLS_SRC/"*/; do
      [ -d "$skill_dir" ] || continue
      local skill_name
      skill_name=$(basename "$skill_dir")
      # Remove existing and copy fresh
      rm -rf "$KIRO_SKILLS_DIR/$skill_name"
      cp -r "$skill_dir" "$KIRO_SKILLS_DIR/$skill_name"
      local file_count
      file_count=$(find "$KIRO_SKILLS_DIR/$skill_name" -type f | wc -l | tr -d ' ')
      success "Skill: $skill_name ($file_count file(s))"
      skill_count=$((skill_count + 1))
    done
    info "Installed $skill_count skills to $KIRO_SKILLS_DIR"
  else
    warn "Skills source directory not found at $SKILLS_SRC"
    warn "Skipping skill installation. Ensure skills/ exists."
  fi

  # Install MCP config
  echo ""
  info "Configuring MCP server..."

  local mcp_target="$KIRO_MCP_DIR/mcp.json"

  install_mcp_config "$mcp_target"
  success "MCP config written to $mcp_target"
}

# ─────────────────────────────────────────────────────────────────────────────
# Claude Code Installation
# ─────────────────────────────────────────────────────────────────────────────
install_claude_code() {
  local CLAUDE_DIR="$HOME/.claude"
  local CLAUDE_COMMANDS_DIR="$CLAUDE_DIR/commands"

  mkdir -p "$CLAUDE_DIR"
  mkdir -p "$CLAUDE_COMMANDS_DIR"

  # Generate CLAUDE.md with all skills embedded
  info "Generating CLAUDE.md system prompt..."

  cat > "$CLAUDE_DIR/CLAUDE.md" <<'HEADER'
# Dev Agent Harness — Claude Code Instructions

You are configured with the Dev Agent Harness development automation skills.
Read `~/.dev-agent-harness/config.yml` at the start of every skill execution
to resolve issue tracker, code platform, and preferences.

---

HEADER

  # Embed each skill as a section
  if [ -d "$SKILLS_SRC" ]; then
    for skill_dir in "$SKILLS_SRC/"*/; do
      [ -d "$skill_dir" ] || continue
      local skill_name
      skill_name=$(basename "$skill_dir")
      local skill_file="$skill_dir/SKILL.md"

      if [ -f "$skill_file" ]; then
        echo "## Skill: $skill_name" >> "$CLAUDE_DIR/CLAUDE.md"
        echo "" >> "$CLAUDE_DIR/CLAUDE.md"
        cat "$skill_file" >> "$CLAUDE_DIR/CLAUDE.md"
        echo "" >> "$CLAUDE_DIR/CLAUDE.md"
        echo "---" >> "$CLAUDE_DIR/CLAUDE.md"
        echo "" >> "$CLAUDE_DIR/CLAUDE.md"

        # Also create a command file for each skill
        cp "$skill_file" "$CLAUDE_COMMANDS_DIR/${skill_name}.md"
        success "Skill: $skill_name (CLAUDE.md section + command file)"
      fi
    done
  fi

  success "CLAUDE.md written to $CLAUDE_DIR/CLAUDE.md"
  success "Commands written to $CLAUDE_COMMANDS_DIR/"

  # Install MCP config for Claude Code
  echo ""
  info "Configuring MCP server for Claude Code..."

  local mcp_target="$CLAUDE_DIR/mcp.json"
  install_mcp_config "$mcp_target"
  success "MCP config written to $mcp_target"
}

# ─────────────────────────────────────────────────────────────────────────────
# Codex Installation
# ─────────────────────────────────────────────────────────────────────────────
install_codex() {
  local CODEX_DIR="$HOME/.codex"

  mkdir -p "$CODEX_DIR"

  # Generate instructions.md with all skills
  info "Generating Codex instructions..."

  cat > "$CODEX_DIR/instructions.md" <<'HEADER'
# Dev Agent Harness — Codex Instructions

You are configured with the Dev Agent Harness development automation skills.
Read `~/.dev-agent-harness/config.yml` at the start of every skill execution
to resolve issue tracker, code platform, and preferences.

---

HEADER

  if [ -d "$SKILLS_SRC" ]; then
    for skill_dir in "$SKILLS_SRC/"*/; do
      [ -d "$skill_dir" ] || continue
      local skill_name
      skill_name=$(basename "$skill_dir")
      local skill_file="$skill_dir/SKILL.md"

      if [ -f "$skill_file" ]; then
        echo "## Skill: $skill_name" >> "$CODEX_DIR/instructions.md"
        echo "" >> "$CODEX_DIR/instructions.md"
        cat "$skill_file" >> "$CODEX_DIR/instructions.md"
        echo "" >> "$CODEX_DIR/instructions.md"
        echo "---" >> "$CODEX_DIR/instructions.md"
        echo "" >> "$CODEX_DIR/instructions.md"
        success "Skill: $skill_name"
      fi
    done
  fi

  success "Instructions written to $CODEX_DIR/instructions.md"

  # Codex doesn't have native MCP — generate a reference config
  echo ""
  info "Note: Codex does not natively support MCP. Skills will use CLI tools directly."
  info "Config reference stored at $CODEX_DIR/mcp-reference.json"

  install_mcp_config "$CODEX_DIR/mcp-reference.json"
}

# ─────────────────────────────────────────────────────────────────────────────
# MCP Config Generator (shared by all agents)
# ─────────────────────────────────────────────────────────────────────────────
install_mcp_config() {
  local target_path="$1"
  local existing_config="{}"

  # Preserve existing MCP servers if file exists
  if [ -f "$target_path" ]; then
    existing_config=$(cat "$target_path" 2>/dev/null || echo "{}")
    info "Existing MCP config found — merging (preserving other servers)."
  fi

  python3 -c "
import json, sys

target_path = '''$target_path'''
code_platform = '''${CODE_PLATFORM:-}'''
gitlab_token = '''${GITLAB_TOKEN:-}'''
gitlab_api_url = '''${GITLAB_API_URL:-}'''
github_token = '''${GITHUB_TOKEN:-}'''

# Load existing config
try:
    existing = json.loads('''$existing_config''')
except (json.JSONDecodeError, ValueError):
    existing = {}

if 'mcpServers' not in existing:
    existing['mcpServers'] = {}

if code_platform == 'gitlab':
    existing['mcpServers']['gitlab'] = {
        'command': 'npx',
        'args': [
            '-y',
            '@zereight/mcp-gitlab@latest',
            '--token=' + gitlab_token,
            '--api-url=' + gitlab_api_url
        ],
        'env': {
            'GITLAB_PERSONAL_ACCESS_TOKEN': gitlab_token,
            'GITLAB_API_URL': gitlab_api_url,
            'USE_PIPELINE': 'true'
        }
    }
elif code_platform == 'github':
    server_config = {
        'command': 'npx',
        'args': [
            '-y',
            '@modelcontextprotocol/server-github'
        ],
        'env': {}
    }
    if github_token:
        server_config['env']['GITHUB_PERSONAL_ACCESS_TOKEN'] = github_token
    existing['mcpServers']['github'] = server_config

with open(target_path, 'w') as f:
    json.dump(existing, f, indent=2)
    f.write('\n')
" || {
    error "Failed to write MCP config. Ensure python3 is available."
    return 1
  }
}

# ─── Dispatch to agent-specific installer ────────────────────────────────────
case "${AGENT_TYPE:-kiro-cli}" in
  kiro-cli)    install_kiro ;;
  claude-code) install_claude_code ;;
  codex)       install_codex ;;
  *)
    error "Unknown agent type: $AGENT_TYPE"
    exit 1
    ;;
esac

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║                   Installation Complete! 🎉                  ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo ""
echo -e "  ${BOLD}Configuration:${RESET}"
echo "    Config     → $CONFIG_FILE"
echo "    Secrets    → $SECRETS_DIR/"
echo ""
echo -e "  ${BOLD}Agent: ${AGENT_TYPE}${RESET}"

case "${AGENT_TYPE:-kiro-cli}" in
  kiro-cli)
    echo "    Skills     → ~/.kiro/skills/"
    echo "    MCP        → ~/.kiro/settings/mcp.json"
    ;;
  claude-code)
    echo "    CLAUDE.md  → ~/.claude/CLAUDE.md"
    echo "    Commands   → ~/.claude/commands/"
    echo "    MCP        → ~/.claude/mcp.json"
    ;;
  codex)
    echo "    Instructions → ~/.codex/instructions.md"
    echo "    MCP Ref      → ~/.codex/mcp-reference.json"
    ;;
esac

echo ""
echo -e "  ${BOLD}Platform:${RESET}"
echo "    Issues     → ${ISSUE_TYPE:-$(grep 'type:' "$CONFIG_FILE" 2>/dev/null | head -1 | awk '{print $2}')}"
echo "    Code       → ${CODE_PLATFORM:-$(grep 'type:' "$CONFIG_FILE" 2>/dev/null | sed -n '2p' | awk '{print $2}')}"
echo "    Branch     → ${DEFAULT_BRANCH:-main}"
echo "    IDE        → ${IDE:-$(grep 'ide:' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')}"
echo ""
echo -e "  ${BOLD}Available Skills:${RESET}"
echo "    • start-story        — Start work + auto-generate spec.md from ticket"
echo "    • finish-story       — Finish work, create MR/PR + automatic code review"
echo "    • review-mr          — Standalone review (18 rules, 3 severity levels)"
echo "    • full-lifecycle     — Ticket → reviewed MR, fully autonomous"
echo ""
echo -e "  ${BOLD}Workflow:${RESET}"
echo "    'start story on <service>, ticket <ID>, feature'   ← generates spec.md"
echo "    'implement the requirements in spec.md'            ← spec-driven development"
echo "    'finish story'                                     ← commit, MR, auto-review"
echo ""
echo "    Or fully autonomous:"
echo "    'full lifecycle on <service>, ticket <ID>, feature'"
echo ""

case "${AGENT_TYPE:-kiro-cli}" in
  kiro-cli)
    echo -e "  ${YELLOW}Restart Kiro CLI to activate the MCP server.${RESET}"
    ;;
  claude-code)
    echo -e "  ${YELLOW}Restart Claude Code to load the new CLAUDE.md and MCP config.${RESET}"
    ;;
  codex)
    echo -e "  ${YELLOW}Restart Codex to load the new instructions.${RESET}"
    ;;
esac

echo ""
