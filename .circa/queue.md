# Circa Task Queue

<!--
Task format:
- [ ] task_id: title
  scope: files/dirs in scope (agents must not touch others)
  criteria: what "done" looks like
  escalate_if: condition → action
  agent: impl | test | review | search | critic

Tasks are added automatically by the loop from:
  - feature.md directives  (human → loop queues them)
  - candidate.md proposals (critic → auto-queued if confidence ≥ threshold, or human-approved)
  - /circa-add "directive" (writes to feature.md, loop picks it up)
-->

## Pending
<!-- Tasks queued for execution -->

## Blocked
<!-- Tasks marked [!] by agents — resolve with /circa --mode review -->

## Completed
<!-- Tasks marked [x] — archived automatically -->
