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

# ── Copy commands (from plugin-root commands/) ─────────────────────────────────
cp "$CIRCA_DIR/commands/circa.md"        "$TARGET_DIR/.claude/commands/circa.md"
cp "$CIRCA_DIR/commands/circa-add.md"    "$TARGET_DIR/.claude/commands/circa-add.md"
cp "$CIRCA_DIR/commands/circa-status.md" "$TARGET_DIR/.claude/commands/circa-status.md"

# ── Copy subagents to .claude/agents/ ─────────────────────────────────────────
cp "$CIRCA_DIR/agents/impl.md"   "$TARGET_DIR/.claude/agents/circa-impl.md"
cp "$CIRCA_DIR/agents/test.md"   "$TARGET_DIR/.claude/agents/circa-test.md"
cp "$CIRCA_DIR/agents/review.md" "$TARGET_DIR/.claude/agents/circa-review.md"
cp "$CIRCA_DIR/agents/search.md" "$TARGET_DIR/.claude/agents/circa-search.md"
cp "$CIRCA_DIR/agents/critic.md" "$TARGET_DIR/.claude/agents/circa-critic.md"

# ── Copy hook script ──────────────────────────────────────────────────────────
cp "$CIRCA_DIR/scripts/night-loop-check.sh" \
    "$TARGET_DIR/.claude/scripts/circa-loop.sh"
chmod +x "$TARGET_DIR/.claude/scripts/circa-loop.sh"

# ── Copy .circa config files (skip if already present) ────────────────────────
for f in config.toml queue.md flags.md completed.md feature.md candidate.md; do
  if [[ ! -f "$TARGET_DIR/.circa/$f" ]]; then
    cp "$CIRCA_DIR/.circa/$f" "$TARGET_DIR/.circa/$f"
    echo "  Created .circa/$f"
  else
    echo "  Skipped .circa/$f (already exists)"
  fi
done

# ── Register Stop hook in .claude/settings.json ───────────────────────────────
SETTINGS="$TARGET_DIR/.claude/settings.json"
if [[ ! -f "$SETTINGS" ]]; then
  echo '{}' > "$SETTINGS"
fi

SETTINGS_PATH="$SETTINGS" node - << 'EOF'
const fs = require('fs');
const path = process.env.SETTINGS_PATH;
const cfg = JSON.parse(fs.readFileSync(path, 'utf8'));
cfg.hooks = cfg.hooks || {};
cfg.hooks.Stop = cfg.hooks.Stop || [];
const hookCmd = '.claude/scripts/circa-loop.sh';
const already = cfg.hooks.Stop.some(
  h => h.hooks && h.hooks.some(s => s.command === hookCmd)
);
if (!already) {
  cfg.hooks.Stop.push({ hooks: [{ type: 'command', command: hookCmd }] });
  fs.writeFileSync(path, JSON.stringify(cfg, null, 2));
  console.log('  Registered Stop hook in .claude/settings.json');
} else {
  console.log('  Stop hook already registered — skipped');
}
EOF

# ── Check for Node.js (required for hook script optionally, settings.json above) ─
if ! command -v node &> /dev/null; then
  echo "Warning: Node.js not found. The settings.json hook registration was skipped."
  echo "         Manually add to .claude/settings.json:"
  echo '         { "hooks": { "Stop": [{ "hooks": [{ "type": "command", "command": ".claude/scripts/circa-loop.sh" }] }] } }'
fi

echo ""
echo "circa installed in $TARGET_DIR"
echo ""
echo "Available commands in Claude Code:"
echo "  /circa --mode run      start continuous loop (reads feature.md, runs indefinitely)"
echo "  /circa --mode review   interactive review — resolve flags, approve candidates"
echo "  /circa --mode config   edit settings"
echo "  /circa-add 'directive' add a human directive to feature.md"
echo "  /circa-status          show loop state"
echo ""
echo "To stop the loop: delete .circa/loop.local.md"
echo "To steer the loop: edit .circa/feature.md"
echo ""
echo "Plugin install (alternative, requires Claude Code marketplace):"
echo "  claude --plugin-dir ./circa"
