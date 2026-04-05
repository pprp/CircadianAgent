# /circa-status — Show queue and run state

Read `.circa/queue.md` and `.circa/completed.md` and print a summary table:

| Status    | Count | Tasks                          |
|-----------|-------|--------------------------------|
| Pending   |  N    | task_ids...                    |
| Completed |  N    | (last 5)                       |
| Flagged   |  N    | task_ids needing review        |

Also show:
- Last run timestamp (from completed.md)
- Current approval_mode (from config.toml)
- Whether Codex MCP is in the Claude Code mcpServers config
