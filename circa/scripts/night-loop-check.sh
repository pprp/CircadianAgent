#!/usr/bin/env bash
# circa loop-check.sh
#
# Stop hook — fires after every Claude response.
# Drives the continuous circa loop indefinitely.
# To stop the loop, delete .circa/loop.local.md.
#
# Follows the ralph-loop pattern: https://ghuntley.com/ralph/

LOOP_STATE_FILE=".circa/loop.local.md"

# Nothing to do if the loop is not active
if [[ ! -f "$LOOP_STATE_FILE" ]]; then
  exit 0
fi

# Loop is active — always inject the continuation prompt.
# The orchestrator itself decides what work to do each cycle.
echo "circa loop: continue. Work through the steps in order — stop at the FIRST step that produces work:
1. Check .circa/feature.md for the first unprocessed [ ] directive — process it (queue or flag).
2. Check .circa/candidate.md for human-approved [y] items or [ ] items whose confidence score meets the threshold in config.toml — queue the first one found.
3. Check .circa/queue.md for the first pending [ ] task — invoke the appropriate circa subagent via the Task tool, evaluate the result, mark [x] or [!], and log to completed.md or flags.md.
4. If steps 1-3 found no work, invoke the circa-critic subagent to analyze the codebase and write new proposals to .circa/candidate.md, then immediately re-check candidate.md for any auto-approvable proposals and queue the first one.
Process exactly ONE unit of work this turn, then end your response."
