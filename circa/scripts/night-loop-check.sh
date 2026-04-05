#!/usr/bin/env bash
# circa loop-check.sh
#
# Stop hook — fires after every Claude response.
# Drives the continuous circa loop indefinitely.
# To stop the loop, delete .circa/loop.local.md.
#
# Follows the ralph-loop pattern: https://ghuntley.com/ralph/

LOOP_STATE_FILE=".circa/loop.local.md"
LOOP_JSON=".circa/loop_state.json"

# Nothing to do if the loop is not active
if [[ ! -f "$LOOP_STATE_FILE" ]]; then
  exit 0
fi

# Check max_cycles from config.toml (0 = unlimited)
MAX_CYCLES=$(grep 'max_cycles' .circa/config.toml 2>/dev/null | grep -o '[0-9]*' | head -1 || echo "0")

# Read current cycle count from loop_state.json
CURRENT_CYCLE=0
if [[ -f "$LOOP_JSON" ]]; then
  CURRENT_CYCLE=$(python3 -c "import json; d=json.load(open('$LOOP_JSON')); print(d.get('cycle',0))" 2>/dev/null || echo "0")
fi

# Stop if max_cycles exceeded
if [[ "$MAX_CYCLES" -gt 0 && "$CURRENT_CYCLE" -ge "$MAX_CYCLES" ]]; then
  echo "circa loop: max_cycles ($MAX_CYCLES) reached. Stopping loop."
  rm -f "$LOOP_STATE_FILE"
  # Send webhook if configured
  WEBHOOK_URL=$(grep 'webhook_url' .circa/config.toml 2>/dev/null | sed 's/.*= *"\(.*\)".*/\1/' | head -1 || echo "")
  if [[ -n "$WEBHOOK_URL" ]]; then
    curl -s -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{\"event\":\"loop_stop\",\"reason\":\"max_cycles_reached\",\"cycles\":$CURRENT_CYCLE}" \
      > /dev/null 2>&1 || true
  fi
  exit 0
fi

# Update last_cycle timestamp in loop_state.json
if [[ -f "$LOOP_JSON" ]]; then
  python3 -c "
import json, datetime
with open('$LOOP_JSON', 'r') as f:
    d = json.load(f)
d['last_cycle'] = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
with open('$LOOP_JSON', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null || true
fi

# Check meta_logging reminder
META_LOGGING=$(grep 'meta_logging' .circa/config.toml 2>/dev/null | grep -o 'true\|false' | head -1 || echo "true")
REMINDER_CYCLES=$(grep 'meta_optimize_reminder_cycles' .circa/config.toml 2>/dev/null | grep -o '[0-9]*' | head -1 || echo "20")
if [[ "$META_LOGGING" == "true" && "$REMINDER_CYCLES" -gt 0 ]]; then
  if [[ $((CURRENT_CYCLE % REMINDER_CYCLES)) -eq 0 && "$CURRENT_CYCLE" -gt 0 ]]; then
    META_REMINDER=" Note: $CURRENT_CYCLE cycles completed — consider running /circa --mode meta-optimize to improve agent prompts based on accumulated usage data."
  fi
fi

# Loop is active — inject the continuation prompt.
# The orchestrator itself decides what work to do each cycle.
echo "circa loop: continue (cycle $CURRENT_CYCLE).${META_REMINDER:-} Work through the steps in order — stop at the FIRST step that produces work:
1. Increment the cycle counter in .circa/loop_state.json. If human_checkpoint=true in config.toml, pause and ask the human before proceeding.
2. Check .circa/feature.md for the first unprocessed [ ] directive — process it (queue or flag).
3. Check .circa/candidate.md for human-approved [y] items or [ ] items whose confidence score meets the threshold in config.toml — queue the first one found.
4. Check .circa/queue.md for the first pending [ ] task — invoke the appropriate circa subagent via the Task tool, evaluate the result, mark [x] or [!], and log to completed.md or flags.md.
5. If steps 2-4 found no work, invoke the critic subagent (circa-cross-critic if cross_model_review=true in config, otherwise circa-critic) to analyze the codebase and write new proposals to .circa/candidate.md, then immediately re-check candidate.md for any auto-approvable proposals and queue the first one.
Process exactly ONE unit of work this turn, then end your response."

