---
description: "Show the circa loop state — pending/completed/flagged tasks, candidate proposals, unprocessed feature directives, and loop statistics"
---

# /circa-status — Show loop state

Read `.circa/queue.md`, `.circa/completed.md`, `.circa/flags.md`, `.circa/candidate.md`, `.circa/feature.md`, `.circa/config.toml`, `.circa/loop.local.md`, and `.circa/loop_state.json`, then print:

## Task Queue

| Category            | Count | Items                                |
|---------------------|-------|--------------------------------------|
| Pending tasks       |  N    | task_ids...                          |
| Completed tasks     |  N    | (last 5)                             |
| Flagged tasks       |  N    | task_ids needing review              |
| Candidates (auto)   |  N    | confidence ≥ threshold, queued next  |
| Candidates (review) |  N    | confidence < threshold, awaiting [y] |
| Feature directives  |  N    | unprocessed [ ] directives           |

## Loop State

Read `.circa/loop_state.json` (if it exists) and show:
- **Loop active**: YES / NO (based on `.circa/loop.local.md`)
- **Loop started**: timestamp from loop_state.json
- **Cycles completed**: cycle count from loop_state.json
- **Current task**: task ID being executed (or "none")
- **Tasks completed this run**: completed_count from loop_state.json
- **Tasks flagged this run**: flagged_count from loop_state.json
- **Critic cycles**: how many times the critic has been invoked
- **Last activity**: last_cycle timestamp

## Config

- `approval_mode`: value from config.toml
- `confidence_threshold`: value from config.toml
- `cross_model_review`: true/false — whether GPT adversarial critic is enabled
- `human_checkpoint`: true/false — whether loop pauses each cycle
- `meta_logging`: true/false — whether events are being logged
- **Events logged**: count of lines in `.circa/meta/events.jsonl` (if it exists)
- **Webhook**: configured / not configured (based on `webhook_url`)

## Codex MCP

Check if `codex` appears in `~/.claude.json` mcpServers. Print:
- Codex MCP: **configured** / **not configured** (cross-model critic requires this)

