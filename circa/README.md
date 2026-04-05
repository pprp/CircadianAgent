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
