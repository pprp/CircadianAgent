# Circa Framework — Build Specification

Build the `circa` plugin framework for Claude Code. Scaffold all files below exactly.
Circa turns Claude Code into a day/night orchestrator with Codex as subagent workers.

---

## 1. Directory structure to create

```
circa/
├── install.sh
├── README.md
├── .claude/
│   └── commands/
│       ├── circa.md          ← main slash command  /circa
│       ├── circa-add.md      ← /circa-add "task description"
│       └── circa-status.md   ← /circa-status
├── .circa/
│   ├── config.toml           ← user-editable settings
│   ├── queue.md              ← task queue (agents read/write this)
│   ├── flags.md              ← escalation log (agents write, human resolves)
│   └── completed.md          ← audit log of finished tasks
└── agents/
    ├── impl.md               ← Codex subagent: write & edit code
    ├── test.md               ← Codex subagent: run & fix tests
    ├── review.md             ← Codex subagent: check diff quality
    └── search.md             ← Codex subagent: docs & web lookup
```

---

## 2. File: install.sh

```bash
#!/usr/bin/env bash
set -e

echo "Installing circa framework..."

# Create dirs
mkdir -p .claude/commands .circa agents

# Copy command files into project
cp circa/.claude/commands/circa.md .claude/commands/circa.md
cp circa/.claude/commands/circa-add.md .claude/commands/circa-add.md
cp circa/.claude/commands/circa-status.md .claude/commands/circa-status.md
cp circa/.circa/config.toml .circa/config.toml
cp circa/.circa/queue.md .circa/queue.md
cp circa/.circa/flags.md .circa/flags.md
cp circa/.circa/completed.md .circa/completed.md
cp -r circa/agents/ .circa/agents/

# Add Codex MCP to Claude Code settings
SETTINGS="$HOME/.claude.json"
if [ -f "$SETTINGS" ]; then
  echo "Adding codex MCP server to $SETTINGS..."
  node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync('$SETTINGS', 'utf8'));
    cfg.mcpServers = cfg.mcpServers || {};
    cfg.mcpServers.codex = { command: 'npx', args: ['-y', 'codex', 'mcp'] };
    fs.writeFileSync('$SETTINGS', JSON.stringify(cfg, null, 2));
  "
fi

# Verify Codex CLI is installed
if ! command -v codex &> /dev/null && ! npx codex --version &> /dev/null 2>&1; then
  echo "Installing Codex CLI..."
  npm install -g @openai/codex
fi

echo ""
echo "circa installed. Available commands in Claude Code:"
echo "  /circa --mode day       plan tasks interactively"
echo "  /circa --mode night     run queue autonomously"
echo "  /circa --mode review    morning summary + resolve flags"
echo "  /circa-add 'task'       quick-add a task to queue"
echo "  /circa-status           show queue state"
```

---

## 3. File: .claude/commands/circa.md

This is the core slash command. When the user types `/circa --mode night`,
Claude Code reads this file and executes the instructions with `$ARGUMENTS = "--mode night"`.

```markdown
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
```

---

## 4. File: .claude/commands/circa-add.md

```markdown
# /circa-add — Quick-add a task to the circa queue

**Task description**: $ARGUMENTS

1. Parse `$ARGUMENTS` as the task title.
2. Read `.circa/queue.md` to determine the next task ID.
3. Ask the user (briefly):
   - Scope (files/dirs)? 
   - Acceptance criteria?
   - Agent role? (impl / test / review / search) — default: impl
4. Append the task to `.circa/queue.md`.
5. Confirm: "Added task_<id>. Run /circa --mode night when ready."
```

---

## 5. File: .claude/commands/circa-status.md

```markdown
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
```

---

## 6. File: .circa/config.toml

```toml
[circa]
version = "0.1.0"

[night]
# full-auto: agents never ask for approval (use for overnight runs)
# auto-edit: agents ask before shell commands, not file edits
# suggest: agents always ask (use for sensitive codebases)
approval_mode = "full-auto"
max_retries = 3
# How many tasks to run in parallel (1 = sequential, safe default)
parallelism = 1

[agents]
# Default agent role when not specified in task
default_role = "impl"

[escalation]
# Default rule appended to every task that doesn't define its own
default_rule = "If uncertain, pick the simpler path, log the decision, continue."
```

---

## 7. File: .circa/queue.md

```markdown
# Circa Task Queue

<!-- 
Task format:
- [ ] task_id: title
  scope: files/dirs in scope (agents must not touch others)
  criteria: what "done" looks like
  escalate_if: condition → action
  agent: impl | test | review | search
-->

## Pending
<!-- Add tasks here with /circa --mode day or /circa-add -->

## Blocked
<!-- Tasks marked [!] by agents — resolve with /circa --mode review -->

## Completed
<!-- Tasks marked [x] — archived automatically -->
```

---

## 8. File: .circa/flags.md

```markdown
# Circa Escalation Flags

<!-- Agents write here when they encounter a decision that needs human input.
     Format: ## task_id\n**reason**:\n**agent output**:\n**resolution**: -->
```

---

## 9. File: .circa/completed.md

```markdown
# Circa Completed Log

<!-- Append-only audit log. Agents write here after each task and run. -->
```

---

## 10. File: agents/impl.md  (Codex impl subagent instructions)

```markdown
# Role: Implementation Agent

You are a code implementation subagent. Your job is to write and edit code.

Rules:
- Only modify files explicitly listed in the task's `scope` field.
- Follow the existing code style of the repository (no reformatting outside scope).
- Write code that passes the stated acceptance criteria before marking done.
- If a file you need to read is outside scope, read it but do not modify it.
- After implementing, run the relevant tests to confirm correctness.
- If tests fail, attempt to fix up to 3 times before escalating.
- Prefer small, focused commits over large changes.
- Do not introduce new dependencies without noting them in your output.

Output when done:
- A summary of what you changed and why
- Test results
- Any decisions you made that the human should know about
```

---

## 11. File: agents/test.md  (Codex test subagent)

```markdown
# Role: Test Agent

You are a test subagent. Your job is to run tests, diagnose failures, and fix them.

Rules:
- Run the full test suite for the scope files first to establish a baseline.
- For each failing test: read the error, trace the root cause, fix it.
- Only modify test files and the minimum production code needed to fix the failure.
- Do not change test assertions to make tests pass — fix the implementation.
- If a test failure requires a design change outside your scope, flag it.
- After fixing, re-run tests to confirm all pass.

Output when done:
- Before/after test counts (X passing, Y failing → Z passing, 0 failing)
- List of files changed
- Summary of each fix
```

---

## 12. File: agents/review.md  (Codex review subagent)

```markdown
# Role: Review Agent

You are a code review subagent. Your job is to check diff quality.

Rules:
- Read the git diff for the scope files since the last commit.
- Check for: logic errors, unhandled edge cases, missing error handling,
  security issues (injection, unvalidated input), and style violations.
- Do not rewrite code unless there is a clear correctness bug.
- Output findings as a structured list: BLOCKER / WARNING / NOTE severity.
- For each BLOCKER: apply the fix directly.
- For each WARNING/NOTE: log in your output but do not modify.

Output when done:
- Diff summary
- List of findings by severity
- Files modified (BLOCKERs fixed)
```

---

## 13. File: agents/search.md  (Codex search subagent)

```markdown
# Role: Search Agent

You are a search and lookup subagent. Your job is to find information.

Rules:
- Use web search and codebase reading to answer the question in the task.
- Do not modify any files.
- Write your findings to a markdown file named `.circa/research/<task_id>.md`.
- Be concise: bullet points preferred over prose.
- Include sources (URLs, file paths, line numbers).

Output when done:
- Path to the research file you created
- 3-sentence summary of key findings
```

---

## 14. File: README.md

```markdown
# circa

Day/night agent framework for Claude Code. Uses Codex CLI as autonomous subagents.

## Install

```bash
git clone https://github.com/yourname/circa
cd your-project
bash circa/install.sh
```

## Usage

**Daytime** — plan what the agents will do tonight:
```
/circa --mode day
```

**Nighttime** — kick off autonomous run and walk away:
```
/circa --mode night
```

**Morning** — review what happened, resolve flags:
```
/circa --mode review
```

**Quick-add a task**:
```
/circa-add "Add rate limiting to /api/infer — see issue #42"
```

**Check queue state**:
```
/circa-status
```

## How it works

Claude Code is the orchestrator. It reads the task queue in `.circa/queue.md`,
spawns Codex subagents via MCP for each task, and writes results back.
Agents never block for human input — they log ambiguity to `.circa/flags.md` and move on.
You review flags the next morning with `/circa --mode review`.

## Config

Edit `.circa/config.toml` to change:
- `approval_mode`: `full-auto` (night runs) or `auto-edit` (sensitive codebases)
- `max_retries`: how many times an agent retries before flagging
- `parallelism`: how many tasks run in parallel (start with 1)

## Requirements

- Claude Code
- Codex CLI (`npm install -g @openai/codex`)
- OpenAI API key (`OPENAI_API_KEY` env var)
```

---

## Build instructions for Claude Code

After creating all files above, run these validation steps:

1. Verify `.claude/commands/circa.md` exists and contains the full command spec
2. Verify `.circa/config.toml` is valid TOML
3. Verify all 4 agent files exist in `agents/`
4. Run `bash install.sh` from a test project directory and confirm:
   - All files copied to correct locations
   - `codex` MCP entry appears in `~/.claude.json`
5. Open Claude Code in the test project and verify `/circa` appears as an autocomplete option
6. Test `/circa-status` — it should read queue.md and print the empty state table

The framework is complete when `/circa --mode day` can add a task,
`/circa --mode night` runs it via Codex, and `/circa --mode review` shows the result.
