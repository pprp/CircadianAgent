# /circa — Circa Agent Framework

**Raw arguments**: $ARGUMENTS

Parse `$ARGUMENTS` to extract `--mode <value>`. Then follow the matching section below.

---

## MODE: day

Goal: Help the human plan the work queue for tonight's autonomous run.

Steps:
1. Read `.circa/queue.md` and display all tasks grouped by status (pending / blocked / done).
2. Read `.circa/config.toml` and confirm `approval_mode` setting.
3. Interactively help the user add new tasks. For each task ask:
   - What is the task? (one-line title)
   - What files/directories are in scope? (hard boundary — agents must not touch others)
   - What does "done" look like? (acceptance criteria — runnable test, passing lint, etc.)
   - What should the agent do if it gets stuck? (default: log to flags.md and skip)
4. Auto-assign a task ID: `task_<YYYYMMDD>_<NNN>` where NNN increments from existing tasks.
5. Append new tasks to `.circa/queue.md` in this format:

```
- [ ] task_20240615_001: Refactor db/query.py to async/await
  scope: src/db/query.py, tests/test_db.py
  criteria: all tests pass, no sync calls remain in scope files
  escalate_if: test failures after 3 retries → mark [!], log to flags.md
  agent: impl
```

6. After adding tasks, print a summary of tonight's queue and confirm with the user.
7. Remind the user to run `/circa --mode night` to start the autonomous run.

---

## MODE: night

Goal: Run every pending task in the queue autonomously using Codex subagents via MCP.
Do not wait for human input. Log all decisions. Complete or flag every task.

Pre-flight checklist:
1. Read `.circa/config.toml` → get `approval_mode` (default: `full-auto`).
2. Read `.circa/queue.md` → collect all tasks with status `[ ]` (pending).
3. If no pending tasks, report "Queue empty — nothing to run tonight." and stop.
4. Confirm Codex MCP server is available. If not, run: `npx codex mcp &`
5. Log run start time to `.circa/completed.md`:
   `## Run started: <ISO timestamp>`

For EACH pending task, in queue order:
1. Identify the agent role from the task's `agent:` field (impl / test / review / search).
2. Read the subagent instructions from `.circa/agents/<role>.md`.
3. Build the Codex prompt by combining:
   - The subagent role instructions
   - The task title, scope, and acceptance criteria
   - The escalation rule for this task
   - This universal rule: "Never modify files outside the stated scope. If uncertain about a
     design decision, choose the simpler path, note your choice, and continue."
4. Call Codex via MCP tool `codex` with that prompt.
5. Evaluate the result:
   - SUCCESS: criteria met, tests pass → mark task `[x]` in queue.md,
     append `- [x] task_id: <title> (completed: <timestamp>)` to completed.md
   - FAILURE after retries → mark task `[!]` in queue.md,
     append to flags.md: `## task_id\n**reason**: <what failed>\n**last output**: <summary>`
6. Continue to the next task regardless of outcome.

After all tasks are processed:
- Append run summary to `.circa/completed.md`
- Print final report: tasks completed, tasks flagged, tasks skipped

IMPORTANT: Never block the loop waiting for human input.
If you cannot resolve something, flag it and move on.

---

## MODE: review

Goal: Present the morning summary and help the human resolve flagged items.

Steps:
1. Print the run summary from `.circa/completed.md` (last run section).
2. Read `.circa/flags.md`. For each flag:
   - Show the task ID, reason it was flagged, and the agent's last output.
   - Ask the human: "How should I resolve this?"
   - Options to offer: retry with clarification / skip permanently / human will fix manually.
   - Write the human's resolution back to the flag entry in flags.md.
3. For tasks the human will fix manually: re-add them to queue.md with updated criteria.
4. Run `git log --oneline -15` and display it.
5. Show any tasks marked `[!]` that haven't been resolved yet.
6. Ask: "Do you want to add new tasks for tonight?"
   If yes → switch to day mode flow.

---

## MODE: config

Goal: Let the user edit `.circa/config.toml` interactively.
Read the file, display current settings, ask what to change, write back.

---

## Fallback

If `--mode` is missing or unrecognized, print:
```
circa commands:
  /circa --mode day      plan & queue tasks
  /circa --mode night    run queue autonomously
  /circa --mode review   morning review + resolve flags
  /circa --mode config   edit settings
```
