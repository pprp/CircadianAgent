#!/usr/bin/env bash
set -e

# circa install.sh — standalone installation (no plugin marketplace required)
# Usage: bash circa/install.sh [target-project-dir]
# Default target: current directory

CIRCA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-.}"

echo "Installing circa to $TARGET_DIR ..."

# ── Create dirs ────────────────────────────────────────────────────────────────
mkdir -p "$TARGET_DIR/.claude/commands"
mkdir -p "$TARGET_DIR/.claude/agents"
mkdir -p "$TARGET_DIR/.claude/scripts"
mkdir -p "$TARGET_DIR/.circa"
mkdir -p "$TARGET_DIR/.circa/meta"

# ── Copy commands (from plugin-root commands/) ─────────────────────────────────
cp "$CIRCA_DIR/commands/circa.md"        "$TARGET_DIR/.claude/commands/circa.md"
cp "$CIRCA_DIR/commands/circa-add.md"    "$TARGET_DIR/.claude/commands/circa-add.md"
cp "$CIRCA_DIR/commands/circa-status.md" "$TARGET_DIR/.claude/commands/circa-status.md"

# ── Copy subagents to .claude/agents/ ─────────────────────────────────────────
cp "$CIRCA_DIR/agents/impl.md"         "$TARGET_DIR/.claude/agents/circa-impl.md"
cp "$CIRCA_DIR/agents/test.md"         "$TARGET_DIR/.claude/agents/circa-test.md"
cp "$CIRCA_DIR/agents/review.md"       "$TARGET_DIR/.claude/agents/circa-review.md"
cp "$CIRCA_DIR/agents/search.md"       "$TARGET_DIR/.claude/agents/circa-search.md"
cp "$CIRCA_DIR/agents/critic.md"       "$TARGET_DIR/.claude/agents/circa-critic.md"
cp "$CIRCA_DIR/agents/cross-critic.md" "$TARGET_DIR/.claude/agents/circa-cross-critic.md"

# ── Copy hook scripts ─────────────────────────────────────────────────────────
cp "$CIRCA_DIR/scripts/night-loop-check.sh" \
    "$TARGET_DIR/.claude/scripts/circa-loop.sh"
cp "$CIRCA_DIR/scripts/meta-log.sh" \
    "$TARGET_DIR/.claude/scripts/circa-meta-log.sh"
chmod +x "$TARGET_DIR/.claude/scripts/circa-loop.sh"
chmod +x "$TARGET_DIR/.claude/scripts/circa-meta-log.sh"

# ── Copy .circa config files (skip if already present) ────────────────────────
for f in config.toml queue.md flags.md completed.md feature.md candidate.md; do
  if [[ ! -f "$TARGET_DIR/.circa/$f" ]]; then
    cp "$CIRCA_DIR/.circa/$f" "$TARGET_DIR/.circa/$f"
    echo "  Created .circa/$f"
  else
    echo "  Skipped .circa/$f (already exists)"
  fi
done

# ── Register Stop + PostToolUse hooks in .claude/settings.json ────────────────
SETTINGS="$TARGET_DIR/.claude/settings.json"
if [[ ! -f "$SETTINGS" ]]; then
  echo '{}' > "$SETTINGS"
fi

SETTINGS_PATH="$SETTINGS" node - << 'EOF'
const fs = require('fs');
const path = process.env.SETTINGS_PATH;
const cfg = JSON.parse(fs.readFileSync(path, 'utf8'));
cfg.hooks = cfg.hooks || {};

// Stop hook (loop continuation)
cfg.hooks.Stop = cfg.hooks.Stop || [];
const stopCmd = '.claude/scripts/circa-loop.sh';
const stopAlready = cfg.hooks.Stop.some(
  h => h.hooks && h.hooks.some(s => s.command === stopCmd)
);
if (!stopAlready) {
  cfg.hooks.Stop.push({ hooks: [{ type: 'command', command: stopCmd }] });
  console.log('  Registered Stop hook in .claude/settings.json');
} else {
  console.log('  Stop hook already registered — skipped');
}

// PostToolUse hook (meta-logging)
cfg.hooks.PostToolUse = cfg.hooks.PostToolUse || [];
const metaCmd = '.claude/scripts/circa-meta-log.sh';
const metaAlready = cfg.hooks.PostToolUse.some(
  h => h.hooks && h.hooks.some(s => s.command === metaCmd)
);
if (!metaAlready) {
  cfg.hooks.PostToolUse.push({ matcher: '.*', hooks: [{ type: 'command', command: metaCmd }] });
  console.log('  Registered PostToolUse meta-log hook in .claude/settings.json');
} else {
  console.log('  PostToolUse hook already registered — skipped');
}

fs.writeFileSync(path, JSON.stringify(cfg, null, 2));
EOF

# ── Check for Node.js (required for settings.json above) ──────────────────────
if ! command -v node &> /dev/null; then
  echo "Warning: Node.js not found. The settings.json hook registration was skipped."
  echo "         Manually add to .claude/settings.json:"
  echo '         { "hooks": { "Stop": [{ "hooks": [{ "type": "command", "command": ".claude/scripts/circa-loop.sh" }] }], "PostToolUse": [{ "matcher": ".*", "hooks": [{ "type": "command", "command": ".claude/scripts/circa-meta-log.sh" }] }] } }'
fi

# ── Check for Codex CLI (optional but recommended for cross-model review) ──────
echo ""
if command -v codex &> /dev/null || npx codex --version &> /dev/null 2>&1; then
  echo "Codex CLI: found ✓ (cross-model critic enabled)"
  echo "  Run 'codex setup' to configure the reviewer model (recommended: gpt-5.4)"
  echo "  Run 'claude mcp add codex -s user -- codex mcp-server' to register the MCP server"
else
  echo "Codex CLI: not found"
  echo "  Cross-model critic will fall back to self-review."
  echo "  To enable: npm install -g @openai/codex && codex setup"
  echo "             claude mcp add codex -s user -- codex mcp-server"
fi

echo ""
echo "circa installed in $TARGET_DIR"
echo ""
echo "Available commands in Claude Code:"
echo "  /circa --mode run           start continuous loop (reads feature.md, runs indefinitely)"
echo "  /circa --mode review        interactive review — resolve flags, approve candidates"
echo "  /circa --mode meta-optimize analyze usage logs and improve agent prompts (after 20+ cycles)"
echo "  /circa --mode config        edit settings"
echo "  /circa-add 'directive'      add a human directive to feature.md"
echo "  /circa-status               show loop state, cycle count, and config"
echo ""
echo "To stop the loop: rm .circa/loop.local.md"
echo "To steer the loop: edit .circa/feature.md  (or use /circa-add)"
echo "To review candidates: /circa --mode review"
