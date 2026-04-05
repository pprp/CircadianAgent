---
description: "Circa continuous loop orchestrator — driven by feature.md (human directives) and candidate.md (agent proposals). Runs indefinitely via Stop hook. Usage: /circa --mode <run|review|config>"
---

# /circa — Circa Continuous Loop

**Raw arguments**: $ARGUMENTS

Parse `$ARGUMENTS` to extract `--mode <value>`. Then follow the matching section below.

---

## MODE: run

Goal: Start the continuous improvement loop. Runs indefinitely — the Stop hook drives each cycle automatically. Each response processes exactly one unit of work.

**CRITICAL — Before doing anything else:**
Write `ACTIVE` to `.circa/loop.local.md`.
Example: `echo "ACTIVE" > .circa/loop.local.md`
This enables the Stop hook. To stop the loop at any time, the human deletes this file.

**Pre-flight:**
1. Read `.circa/config.toml` → get `approval_mode` and `confidence_threshold`.
2. Log loop start to `.circa/completed.md`: `## Loop started: <ISO timestamp>`

---

**Each cycle, work through these steps in order. Stop at the FIRST step that produces work, then end your response.**

### Step 1 — Human directives (feature.md)

Read `.circa/feature.md`. Find the first `[ ]` directive (unprocessed, top-to-bottom).

If found:
- Parse the directive text.
- Assess confidence that this directive is clear and actionable (0–100%).
  - **≥ 70%**: Auto-assign a task ID (`task_<YYYYMMDD>_<NNN>`) and append a task entry to `.circa/queue.md`. Mark the directive `[>]` in feature.md with a note: `(queued as <task_id>)`.
  - **< 70%**: Write a clarification request to `.circa/flags.md`. Mark the directive `[?]` in feature.md.
- End your response.

### Step 2 — Approved and high-confidence candidates (candidate.md)

Read `.circa/candidate.md`. Process BOTH:
- **(a) Human-approved**: items marked `[y]` (regardless of confidence score).
- **(b) Auto-approvable**: items marked `[ ]` with `confidence: N%` where N ≥ `confidence_threshold` from config.toml (default: 80).

For the FIRST such item found:
- Auto-assign a task ID and append a task entry to `.circa/queue.md`.
- Mark the item `[>]` in candidate.md: append `(queued as <task_id>)` on the same line.
- End your response.

Items with confidence below the threshold and no `[y]` marking stay in candidate.md until the human approves them via `/circa --mode review`.

### Step 3 — Execute pending task (queue.md)

Read `.circa/queue.md`. Find the first `[ ]` task.

If found:
1. Identify the agent role from the task's `agent:` field.
2. Invoke the subagent via the **Task tool**:
   - `agent: impl`   → invoke `circa-impl`
   - `agent: test`   → invoke `circa-test`
   - `agent: review` → invoke `circa-review`
   - `agent: search` → invoke `circa-search`
   - `agent: critic` → invoke `circa-critic`

   Pass: task title, scope, acceptance criteria, escalation rule, and this universal rule:
   "Never modify files outside the stated scope. If uncertain, choose the simpler path, note the decision, and continue."

3. Evaluate the subagent result:
   - **SUCCESS**: criteria met → mark task `[x]` in queue.md, append `- [x] task_id: <title> (completed: <timestamp>)` to completed.md.
   - **FAILURE** after retries → mark task `[!]` in queue.md, append to flags.md: `## task_id\n**reason**: <what failed>\n**last output**: <summary>`.
4. End your response.

### Step 4 — Generate new candidates (no other work found)

Steps 1–3 found nothing to do. Invoke the **`circa-critic`** subagent via the Task tool.
The critic reads the codebase and writes 3–5 proposals to `.circa/candidate.md`.

After the critic completes, immediately re-check candidate.md (Step 2) for any newly added auto-approvable proposals and queue the first one found.

End your response.

---

**The Stop hook continues the loop after every response. Never block waiting for human input. If stuck, write to flags.md and end your response — the hook will fire.**

---

## MODE: review

Goal: Interactive session. Review completed work, resolve flags, and approve/reject candidate proposals.

Steps:
1. Show the last run section from `.circa/completed.md`.
2. Read `.circa/flags.md`. For each unresolved flag:
   - Show task ID, reason it was flagged, and the agent's last output.
   - Ask: retry with clarification / skip permanently / human will fix manually.
   - Write the human's resolution back to the flag entry in flags.md.
   - For "human will fix manually": re-add to queue.md with updated criteria.
3. Read `.circa/candidate.md`. Show all `[ ]` proposals (below confidence threshold, awaiting decision):
   - Display: title, confidence score, rationale, risk, scope.
   - Ask for each: approve `[y]` / reject `[n]` / skip for now.
   - Update candidate.md with the human's decision.
4. Run `git log --oneline -10` and display it.
5. Ask: "Want to add a directive to `.circa/feature.md` before resuming the loop?"
   If yes: append `- [ ] <text>` under `## Active Directives` in feature.md.
6. Ask: "Resume the loop? (`/circa --mode run`)"

---

## MODE: config

Goal: Let the user edit `.circa/config.toml` interactively.
Read the file, display current settings, ask what to change, write back.

---

## Fallback

If `--mode` is missing or unrecognized, print:
```
circa commands:
  /circa --mode run      start continuous loop (reads feature.md, runs indefinitely)
  /circa --mode review   interactive review — resolve flags, approve candidates
  /circa --mode config   edit settings

To stop the loop: delete .circa/loop.local.md
To steer the loop: edit .circa/feature.md
To review proposals: /circa --mode review
