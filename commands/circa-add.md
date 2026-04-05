---
description: "Add a human directive to .circa/feature.md to steer the continuous loop. Usage: /circa-add \"directive text\""
---

# /circa-add — Add a directive to the circa loop

**Directive**: $ARGUMENTS

1. Parse `$ARGUMENTS` as the directive text.
2. Read `.circa/feature.md`.
3. Append under `## Active Directives`:
   `- [ ] <directive text>`
4. Confirm: "Directive added to feature.md. The loop will pick it up on the next cycle."
   If `.circa/loop.local.md` does not exist, also say: "Loop is not running — start it with `/circa --mode run`."
