# Candidate Experiments

<!--
Written by the circa-critic subagent. Human approves or rejects low-confidence proposals.
High-confidence proposals (≥ confidence_threshold in config.toml) are auto-queued.

Proposal statuses:
  [ ] — awaiting decision (auto-queued if confidence ≥ threshold, else needs human [y]/[n])
  [y] — human-approved → will be queued on the next cycle
  [n] — rejected → archived below
  [>] — queued as a task in queue.md (auto or human-approved)

Use /circa --mode review to batch-approve or reject proposals.

Proposal format (written by circa-critic):
  - [ ] cand_<YYYYMMDD>_<NNN>: <title> (confidence: N%)
    rationale: <why this matters and what evidence was found>
    risk: <what could go wrong>
    scope: <files or directories>
    agent: impl | test | review | search
-->

## Pending Review
<!-- Proposals with confidence < threshold, awaiting human [y] or [n] -->

## Auto-Queued
<!-- Proposals queued automatically (confidence ≥ threshold) -->

## Rejected
<!-- Human marked [n] — kept for reference -->
