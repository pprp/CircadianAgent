#!/usr/bin/env bash
# circa meta-log.sh
#
# PostToolUse hook — fires after every tool call during a circa loop session.
# Passively logs tool invocations to .circa/meta/events.jsonl for meta-optimization.
# Zero impact when meta_logging is disabled in config.toml or .circa is not present.
#
# Environment variables provided by Claude Code hooks:
#   CLAUDE_TOOL_NAME    — name of the tool that was just used
#   CLAUDE_TOOL_INPUT   — JSON input to the tool (may be large, trimmed)
#   CLAUDE_TOOL_OUTPUT  — JSON output from the tool (may be large, trimmed)
#   CLAUDE_SESSION_ID   — current session ID

# Skip if not in a circa project
if [[ ! -f ".circa/config.toml" ]]; then
  exit 0
fi

# Check if meta_logging is enabled (default: true)
META_LOGGING=$(grep -A1 '\[meta\]' .circa/config.toml 2>/dev/null | grep 'meta_logging' | grep -o 'true\|false' || echo "true")
if [[ "$META_LOGGING" == "false" ]]; then
  exit 0
fi

# Ensure the meta directory exists
mkdir -p .circa/meta

# Build the log entry (trim large payloads to avoid huge log files)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TOOL_NAME="${CLAUDE_TOOL_NAME:-unknown}"

# Trim input/output to 500 chars each to keep log files manageable
TOOL_INPUT_TRIMMED=$(echo "${CLAUDE_TOOL_INPUT:-}" | head -c 500)
TOOL_OUTPUT_TRIMMED=$(echo "${CLAUDE_TOOL_OUTPUT:-}" | head -c 500)

# Detect if in circa loop (loop.local.md exists)
LOOP_ACTIVE="false"
if [[ -f ".circa/loop.local.md" ]]; then
  LOOP_ACTIVE="true"
fi

# Read cycle count from loop_state.json if available
CYCLE=0
if [[ -f ".circa/loop_state.json" ]]; then
  CYCLE=$(python3 -c "import json,sys; d=json.load(open('.circa/loop_state.json')); print(d.get('cycle',0))" 2>/dev/null || echo "0")
fi

# Append JSONL entry
printf '{"timestamp":"%s","event":"tool_use","tool":"%s","loop_active":%s,"cycle":%s,"input_preview":%s,"output_preview":%s}\n' \
  "$TIMESTAMP" \
  "$TOOL_NAME" \
  "$LOOP_ACTIVE" \
  "$CYCLE" \
  "$(echo "$TOOL_INPUT_TRIMMED" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo '""')" \
  "$(echo "$TOOL_OUTPUT_TRIMMED" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo '""')" \
  >> .circa/meta/events.jsonl

exit 0
