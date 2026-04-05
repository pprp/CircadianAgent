---
description: "Show the circa loop state — pending/completed/flagged tasks, candidate proposals, and unprocessed feature directives"
---

# /circa-status — Show loop state

Read `.circa/queue.md`, `.circa/completed.md`, `.circa/flags.md`, `.circa/candidate.md`, `.circa/feature.md`, `.circa/config.toml`, and `.circa/loop.local.md`, then print:

| Category            | Count | Items                                |
|---------------------|-------|--------------------------------------|
| Pending tasks       |  N    | task_ids...                          |
| Completed tasks     |  N    | (last 5)                             |
| Flagged tasks       |  N    | task_ids needing review              |
| Candidates (review) |  N    | confidence < threshold, awaiting [y] |
| Feature directives  |  N    | unprocessed [ ] directives           |

Also show:
- Loop active: **YES** / **NO** (based on `.circa/loop.local.md`)
- Last activity timestamp (from completed.md)
- `approval_mode` and `confidence_threshold` (from config.toml)
