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
