---
description: "Circa continuous loop orchestrator — driven by feature.md (human directives) and candidate.md (agent proposals). Runs indefinitely via Stop hook. Usage: /circa --mode <run|review|config|meta-optimize>"
---

# /circa — Circa Continuous Loop

**Raw arguments**: $ARGUMENTS

Parse `$ARGUMENTS` to extract `--mode <value>`. Then follow the matching section below.

---

## MODE: run

Goal: Start the continuous improvement loop. Runs indefinitely — the Stop hook drives each cycle automatically. Each response processes exactly one unit of work.

**CRITICAL — Before doing anything else:**

Initialize loop state by writing JSON to `.circa/loop_state.json`:
```json
{
  "status": "ACTIVE",
  "started": "<ISO timestamp>",
  "cycle": 0,
  "last_cycle": "<ISO timestamp>",
  "current_task": null,
  "completed_count": 0,
  "flagged_count": 0,
  "critic_cycles": 0
}
```
Also write `ACTIVE` to `.circa/loop.local.md` to enable the Stop hook.

**Pre-flight:**
1. Read `.circa/config.toml` → get `approval_mode`, `confidence_threshold`, `cross_model_review`, `cross_model_frequency`, `human_checkpoint`, `compact_mode`, `max_cycles`.
2. Log loop start to `.circa/completed.md`: `## Loop started: <ISO timestamp>`
3. If `meta_logging = true` in config, log event to `.circa/meta/events.jsonl`:
   ```json
   {"timestamp":"<ISO>","event":"loop_start","mode":"run"}
   ```

---

**Each cycle, work through these steps in order. Stop at the FIRST step that produces work, then end your response.**

**At the start of EVERY cycle:**
- Read `.circa/loop_state.json` → increment `cycle` counter, update `last_cycle`.
- If `max_cycles > 0` and `cycle > max_cycles`: write `STOPPED` to loop.local.md, log to completed.md, stop.
- If `human_checkpoint = true`: pause and ask the human: "Continue cycle N? (y to proceed, or add a directive first)"

### Step 1 — Human directives (feature.md)

Read `.circa/feature.md`. Find the first `[ ]` directive (unprocessed, top-to-bottom).

If found:
- Parse the directive text.
- Assess confidence that this directive is clear and actionable (0–100%).
  - **≥ 70%**: Auto-assign a task ID (`task_<YYYYMMDD>_<NNN>`) and append a task entry to `.circa/queue.md`. Mark the directive `[>]` in feature.md with a note: `(queued as <task_id>)`.
  - **< 70%**: Write a clarification request to `.circa/flags.md`. Mark the directive `[?]` in feature.md.
- Log meta event if enabled: `{"event":"directive_processed","confidence":N,"queued":<bool>}`
- End your response.

### Step 2 — Approved and high-confidence candidates (candidate.md)

Read `.circa/candidate.md`. Process BOTH:
- **(a) Human-approved**: items marked `[y]` (regardless of confidence score).
- **(b) Auto-approvable**: items marked `[ ]` with `confidence: N%` where N ≥ `confidence_threshold` from config.toml (default: 80).

For the FIRST such item found:
- Auto-assign a task ID and append a task entry to `.circa/queue.md`.
- Mark the item `[>]` in candidate.md: append `(queued as <task_id>)` on the same line.
- Log meta event if enabled: `{"event":"candidate_queued","id":"<cand_id>","confidence":N}`
- End your response.

Items with confidence below the threshold and no `[y]` marking stay in candidate.md until the human approves them via `/circa --mode review`.

### Step 3 — Execute pending task (queue.md)

Read `.circa/queue.md`. Find the first `[ ]` task.

If found:
1. Update `loop_state.json` → set `current_task` to the task ID.
2. Identify the agent role from the task's `agent:` field.
3. Invoke the subagent via the **Task tool**:
   - `agent: impl`   → invoke `circa-impl`
   - `agent: test`   → invoke `circa-test`
   - `agent: review` → invoke `circa-review`
   - `agent: search` → invoke `circa-search`
   - `agent: critic` → invoke `circa-critic`

   Pass: task title, scope, acceptance criteria, escalation rule, and this universal rule:
   "Never modify files outside the stated scope. If uncertain, choose the simpler path, note the decision, and continue."

4. Evaluate the subagent result:
   - **SUCCESS**: criteria met → mark task `[x]` in queue.md, append `- [x] task_id: <title> (completed: <timestamp>)` to completed.md. Increment `completed_count` in loop_state.json. If `webhook_events` includes `task_complete` and `webhook_url` is set, POST a summary webhook.
   - **FAILURE** after retries → mark task `[!]` in queue.md, append to flags.md: `## task_id\n**reason**: <what failed>\n**last output**: <summary>`. Increment `flagged_count`. If `webhook_events` includes `task_fail` and `webhook_url` is set, POST a failure webhook.
5. Update `loop_state.json` → set `current_task` to null.
6. Log meta event: `{"event":"task_complete|task_fail","task_id":"...","agent":"...","duration_s":N}`
7. If `compact_mode = true` and completed_count is a multiple of 10: generate a compact summary file `.circa/compact_<cycle>.md` summarizing recent completions and flags.
8. End your response.

### Step 4 — Generate new candidates (no other work found)

Steps 1–3 found nothing to do. Increment `critic_cycles` in loop_state.json.

**Choose the critic type based on config:**
- If `cross_model_review = true` AND `critic_cycles % cross_model_frequency == 0`: invoke **`circa-cross-critic`** via the Task tool. (Uses Codex MCP for adversarial review.)
- Otherwise: invoke **`circa-critic`** via the Task tool. (Standard self-review.)

The critic writes 3–5 proposals to `.circa/candidate.md`.

After the critic completes, immediately re-check candidate.md (Step 2) for any newly added auto-approvable proposals and queue the first one found.

Log meta event: `{"event":"critic_invoked","type":"cross-model|self","proposals_added":N}`

End your response.

---

**The Stop hook continues the loop after every response. Never block waiting for human input. If stuck, write to flags.md and end your response — the hook will fire.**

---

## MODE: review

Goal: Interactive session. Review completed work, resolve flags, and approve/reject candidate proposals.

Steps:
1. Read `.circa/loop_state.json` and show loop statistics: cycles run, tasks completed, tasks flagged, started time.
2. Show the last run section from `.circa/completed.md`.
3. Read `.circa/flags.md`. For each unresolved flag:
   - Show task ID, reason it was flagged, and the agent's last output.
   - Ask: retry with clarification / skip permanently / human will fix manually.
   - Write the human's resolution back to the flag entry in flags.md.
   - For "human will fix manually": re-add to queue.md with updated criteria.
   - Send webhook if `flag_created` in webhook_events and webhook_url is set.
4. Read `.circa/candidate.md`. Show all `[ ]` proposals (below confidence threshold, awaiting decision):
   - Display: title, confidence score, reviewer (gpt/self), rationale, risk, scope.
   - Ask for each: approve `[y]` / reject `[n]` / skip for now.
   - Update candidate.md with the human's decision.
5. Run `git log --oneline -10` and display it.
6. If `.circa/meta/events.jsonl` exists and has ≥ 20 events: suggest running `/circa --mode meta-optimize` to improve the loop based on accumulated data.
7. Ask: "Want to add a directive to `.circa/feature.md` before resuming the loop?"
   If yes: append `- [ ] <text>` under `## Active Directives` in feature.md.
8. Ask: "Resume the loop? (`/circa --mode run`)"

---

## MODE: meta-optimize

Goal: Analyze accumulated usage logs and propose improvements to agent prompts and config defaults. Inspired by the ARIS meta-harness pattern.

Steps:
1. Check `.circa/meta/events.jsonl` exists and has enough data (≥ 10 events). If not: "Not enough data yet — run more loop cycles first."
2. Read all events from events.jsonl and analyze:
   - Which agents fail most often? (task_fail events by agent type)
   - Which candidate confidence scores are most often wrong? (auto-queued but then failed)
   - What directives triggered clarification requests most often? (low-confidence directive_processed events)
   - Are there patterns in the timing of failures? (consecutive failures = systemic problem)
   - What is the average cycle time? Are any steps taking much longer than others?
3. Call Codex MCP with the usage analysis and ask:
   "Given these circa loop usage patterns, propose 3–5 specific, minimal improvements to:
    (a) agent prompts (impl.md, test.md, review.md, critic.md, cross-critic.md)
    (b) config.toml default values
    (c) orchestrator logic (circa.md)
    Each proposal must include: what to change, why (citing specific data), and the exact text change."
4. Present each proposal to the human: show the evidence, the recommended change, the risk.
5. For each approved proposal:
   - Apply the change directly to the relevant file.
   - Log: `{"event":"meta_optimize_applied","target_file":"...","summary":"..."}`
6. Archive the analyzed events: move events.jsonl to `events_<YYYYMMDD>.jsonl.bak`.
7. Print summary: N proposals generated, M applied.

---

## MODE: config

Goal: Let the user edit `.circa/config.toml` interactively.
Read the file, display current settings, ask what to change, write back.

---

## Fallback

If `--mode` is missing or unrecognized, print:
```
circa commands:
  /circa --mode run           start continuous loop (reads feature.md, runs indefinitely)
  /circa --mode review        interactive review — resolve flags, approve candidates
  /circa --mode meta-optimize analyze usage logs and improve agent prompts
  /circa --mode config        edit settings

To stop the loop: delete .circa/loop.local.md
To steer the loop: edit .circa/feature.md
To review proposals: /circa --mode review
To improve the loop itself: /circa --mode meta-optimize (after 20+ cycles)
