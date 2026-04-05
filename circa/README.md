# circa ⚙️🌙

> **English** | [中文](#中文说明)

---

**circa** is a continuous agentic improvement loop for Claude Code.

Claude Code acts as the **orchestrator** — reading your intent from plain Markdown files, dispatching tasks to specialized subagents, and driving itself forward via a Claude Code Stop hook. When idle, it invokes a critic to generate the next batch of improvements automatically.

Codex (GPT) acts as the **adversarial reviewer** — a second model that reviews the codebase from a different perspective, catching what a self-reviewing model cannot see.

> Inspired by [ARIS ⚔️🌙](https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep) — circa adopts ARIS's cross-model adversarial review architecture and meta-optimization harness, applying them to general software engineering workflows.

---

## Table of Contents

- [Architecture](#architecture)
- [Install](#install)
- [Quick Start](#quick-start)
- [How the Loop Works](#how-the-loop-works)
- [Steering the Loop](#steering-the-loop)
- [Commands](#commands)
- [Agents](#agents)
- [Config Reference](#config-reference)
- [Meta-Optimization](#meta-optimization)
- [Directory Structure](#directory-structure)
- [Requirements](#requirements)
- [中文说明](#中文说明)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        circa loop                                │
│                                                                  │
│   Human intent                                                   │
│   feature.md ──────────────────────────┐                        │
│                                        │                        │
│                                        ▼                        │
│                              ┌──────────────────┐               │
│                              │   Orchestrator   │               │
│                              │  /circa --mode   │               │
│                              │       run        │               │
│                              └────────┬─────────┘               │
│                                       │                         │
│              ┌────────────────────────┼──────────────────┐      │
│              │                        │                  │      │
│              ▼                        ▼                  ▼      │
│      ┌──────────────┐       ┌──────────────────┐  ┌──────────┐ │
│      │   Subagents  │       │  Cross-Model     │  │   Self   │ │
│      │              │       │  Critic (GPT)    │  │  Critic  │ │
│      │ impl  / test │       │  Codex MCP       │  │          │ │
│      │ review/search│       │  adversarial     │  │ fallback │ │
│      └──────┬───────┘       └────────┬─────────┘  └────┬─────┘ │
│             │                        │                  │      │
│             ▼                        ▼                  ▼      │
│      queue.md / flags.md        candidate.md        candidate.md│
│      completed.md               (gpt proposals)    (self props) │
│                                                                  │
│   Stop hook fires after every response → loop continues         │
│   PostToolUse hook → events.jsonl (passive meta-logging)        │
└─────────────────────────────────────────────────────────────────┘
```

**Why two models?**

A single model reviewing its own code creates self-play blind spots — the same patterns that caused a bug are the same patterns the model uses to verify it. This is the stochastic bandit problem: predictable reward noise, easy to game.

Cross-model review is adversarial: GPT actively probes weaknesses that Claude didn't anticipate. The biggest quality gain is going from 1 model → 2. Adding more reviewers beyond that gives diminishing returns.

- **Claude Code** — fast, fluid execution. Writes code, runs tests, fixes bugs.
- **GPT via Codex MCP** — deliberate, adversarial critique. Reviews from a different angle.

---

## Install

```bash
# 1. Clone circa
git clone https://github.com/yourname/circa
cd your-project

# 2. Install into your project
bash circa/install.sh

# 3. (Optional but recommended) Set up Codex MCP for cross-model review
npm install -g @openai/codex
codex setup          # set model to gpt-5.4 when prompted
claude mcp add codex -s user -- codex mcp-server
```

The install script:
- Copies commands to `.claude/commands/`
- Copies subagent definitions to `.claude/agents/`
- Copies shell scripts to `.claude/scripts/`
- Creates `.circa/` state files (skips existing ones)
- Creates `.circa/meta/` for event logs
- Registers the **Stop hook** and **PostToolUse hook** in `.claude/settings.json`

---

## Quick Start

```bash
# Start the continuous loop — runs until you stop it
/circa --mode run

# Add a directive (human intent) — loop picks it up automatically
/circa-add "Add rate limiting to /api/chat — max 60 req/min per IP"

# Check what's running, pending, or flagged
/circa-status

# After sleeping — review what happened, resolve flags, approve candidates
/circa --mode review

# After 20+ cycles — let the loop improve its own agent prompts
/circa --mode meta-optimize

# Stop the loop at any time
rm .circa/loop.local.md
```

---

## How the Loop Works

The loop is driven by a **Claude Code Stop hook** — a shell script that fires after every Claude response and injects a continuation prompt. This means the loop never busy-waits; Claude ends its response, the hook fires, and Claude picks up exactly where it left off.

### Each cycle follows this priority order:

**Step 1 — Human directives (highest priority)**

The loop reads `.circa/feature.md` top-to-bottom, finds the first `[ ]` directive, and assesses it:
- **Confidence ≥ 70%**: directive is clear → auto-create a task in `queue.md`, mark directive `[>]`
- **Confidence < 70%**: directive is ambiguous → write a clarification request to `flags.md`, mark directive `[?]`

**Step 2 — Approved candidates**

The loop reads `.circa/candidate.md` and processes:
- Items marked `[y]` by the human (approved regardless of confidence)
- Items where `confidence ≥ threshold` (default: 80) — auto-queued without human input

Items below threshold sit in `candidate.md` until reviewed with `/circa --mode review`.

**Step 3 — Execute a pending task**

The loop reads `queue.md`, finds the first `[ ]` task, and invokes the appropriate subagent:

| Task `agent:` field | Subagent invoked |
|---------------------|-----------------|
| `impl` | `circa-impl` — write and edit code |
| `test` | `circa-test` — run and fix tests |
| `review` | `circa-review` — check diff quality |
| `search` | `circa-search` — research information |
| `critic` | `circa-critic` — generate proposals |

**Success** → mark `[x]`, append to `completed.md`  
**Failure** after 3 attempts → mark `[!]`, write to `flags.md`

**Step 4 — Generate new candidates (when idle)**

Steps 1–3 found nothing to do. The loop invokes the critic:
- If `cross_model_review = true` (default): invoke `circa-cross-critic` → GPT reviews via Codex MCP
- Otherwise: invoke `circa-critic` → self-review

The critic writes 3–5 proposals to `candidate.md`. The loop immediately re-checks for auto-approvable proposals and queues the first one.

### Loop state

The loop writes live state to `.circa/loop_state.json`:

```json
{
  "status": "ACTIVE",
  "started": "2026-04-05T22:00:00Z",
  "cycle": 47,
  "last_cycle": "2026-04-05T23:14:22Z",
  "current_task": "task_20260405_003",
  "completed_count": 12,
  "flagged_count": 1,
  "critic_cycles": 8
}
```

---

## Steering the Loop

The loop is steered entirely through files — no commands needed while it runs.

| File | Who writes | Purpose |
|------|-----------|---------|
| `.circa/feature.md` | **You** | Human directives — processed first, highest priority |
| `.circa/candidate.md` | **Critics** | Improvement proposals with confidence scores |
| `.circa/queue.md` | **Orchestrator** | Tasks queued for execution |
| `.circa/flags.md` | **Agents** | Escalations — tasks that need human resolution |
| `.circa/completed.md` | **Orchestrator** | Append-only audit log of all completed tasks |
| `.circa/loop_state.json` | **Orchestrator** | Live loop state and statistics |
| `.circa/meta/events.jsonl` | **Hook** | Passive tool-use log for meta-optimization |

**Directive format** (in `feature.md`):
```markdown
## Active Directives
- [ ] Add pagination to the /api/posts endpoint — max 20 items per page
- [ ] Write unit tests for src/auth/jwt.py — cover edge cases and expiry
```

**Candidate format** (written by critic, reviewed by you):
```markdown
- [ ] cand_20260405_001: Add type annotations to core modules (confidence: 85%)
  rationale: 3 modules in src/core/ have no type hints — mypy finds 12 errors
  risk: type annotations may be incorrect if behavior is undocumented
  scope: src/core/parser.py, src/core/router.py, src/core/cache.py
  agent: impl
  reviewer: gpt (cross-model)
```

To approve: change `[ ]` to `[y]`. The loop queues it on the next cycle.

---

## Commands

### `/circa --mode run`

Start the continuous loop. Writes `ACTIVE` to `.circa/loop.local.md` and initializes `loop_state.json`. The Stop hook fires after each response to continue the loop.

### `/circa --mode review`

Interactive session for morning review:
1. Show loop statistics from `loop_state.json`
2. List recent completions from `completed.md`
3. Walk through each flag in `flags.md` — offer retry / skip / manual fix
4. Show candidates below confidence threshold — approve `[y]` / reject `[n]` / skip
5. Show recent git log
6. If 20+ cycles accumulated: suggest `/circa --mode meta-optimize`
7. Ask if you want to add new directives to `feature.md`

### `/circa --mode meta-optimize`

Analyze accumulated usage data and improve the loop itself:
1. Read `.circa/meta/events.jsonl` — requires ≥ 10 events
2. Identify patterns: which agents fail most, which confidence scores are miscalibrated, which directives triggered clarification most often
3. Call GPT via Codex MCP to propose minimal improvements to agent prompts and config defaults
4. Present each proposal with evidence — you approve or reject
5. Apply approved changes directly to the relevant files
6. Archive the analyzed log

### `/circa --mode config`

Interactive config editor — reads `.circa/config.toml`, shows current values, asks what to change, writes back.

### `/circa-add "directive text"`

Quick-add a directive. Appends `- [ ] <text>` to `.circa/feature.md`. The loop picks it up automatically on the next cycle.

### `/circa-status`

Show a full status table:
- Task counts: pending / completed / flagged / candidates
- Loop state: active, cycle count, started time, current task
- Config summary: approval mode, confidence threshold, cross-model review toggle
- Codex MCP availability check

---

## Agents

All agents follow the **exhaust-before-surrender** rule: make 3 genuine attempts with different strategies before writing to `flags.md`. Do not give up after one error.

### `circa-impl` — Implementation

Writes and edits code within the task's `scope` field. Never touches files outside scope.

- Reads files outside scope for context, never writes them
- Runs tests after implementing to verify correctness
- On failure: attempt 1 (read error → fix), attempt 2 (different approach), attempt 3 (scope re-evaluation) → escalate with exact error + 3 approaches tried
- Does not introduce new dependencies without noting them

### `circa-test` — Testing

Runs the test suite, diagnoses failures, and fixes them.

- Establishes a baseline count before any changes
- Auto-diagnoses failure types: OOM, import error, path error, assertion, timeout — applies standard fix for each
- Never changes test assertions to make tests pass — fixes the implementation
- Flags tests that require out-of-scope design changes

### `circa-review` — Code Review

Reviews git diffs for quality and security issues.

Full checklist: logic errors, unhandled edge cases, missing error handling, OWASP Top 10 security (injection, broken auth, sensitive data exposure, insecure deserialization), style violations, missing tests, dead code.

- `BLOCKER`: applies fix directly, verifies no regressions
- `WARNING` / `NOTE`: logs in output, does not modify
- Must try 2 solution paths for each BLOCKER before conceding to human

### `circa-search` — Research

Researches questions via web search and codebase reading.

- Writes findings to `.circa/research/<task_id>.md` in structured format
- Cross-checks ambiguous results with a second source
- Runs a completeness gate before finishing: "Did I answer every part of the acceptance criteria?"

### `circa-critic` — Self-Critic

Reads the codebase and generates 3–5 improvement proposals (read-only, never writes source files).

Assigns confidence scores:
- **≥ 80%**: clear, low-risk — auto-queued by orchestrator
- **50–79%**: trade-offs involved — awaits human approval
- **< 50%**: speculative — flagged for human review

### `circa-cross-critic` — Adversarial Critic (GPT)

The cross-model critic. Gathers codebase context, calls GPT via Codex MCP with an adversarial review prompt, synthesizes the response into circa candidate proposals tagged with `reviewer: gpt (cross-model)`.

Falls back to self-review if Codex MCP is unavailable, tagging proposals with `reviewer: self (fallback)`.

---

## Config Reference

```toml
[circa]
version = "0.3.0"

[loop]
approval_mode = "full-auto"    # full-auto | auto-edit | suggest
max_retries = 3                # attempts before escalating to flags.md
parallelism = 1                # parallel tasks (1 = sequential, safe default)
confidence_threshold = 80      # auto-queue proposals above this score (0-100)
human_checkpoint = false       # pause each cycle for human approval
compact_mode = false           # generate compact summaries every 10 tasks
max_cycles = 0                 # stop after N cycles (0 = unlimited)

[review]
cross_model_review = true      # use GPT adversarial critic (requires Codex MCP)
reviewer_model = "gpt-5.4"    # model for Codex MCP reviewer
cross_model_frequency = 1     # every N critic cycles use cross-model (1 = always)

[agents]
default_role = "impl"

[escalation]
default_rule = "If uncertain, pick the simpler path, log the decision, continue."

[notifications]
webhook_url = ""               # Slack / Discord / Feishu / custom HTTP
webhook_events = ["task_fail", "flag_created", "loop_stop"]
include_summary = true

[meta]
meta_logging = true            # log events to .circa/meta/events.jsonl
meta_optimize_reminder_cycles = 20
```

---

## Meta-Optimization

circa can improve its own agent prompts and configuration defaults using accumulated usage data. Inspired by the [ARIS meta-harness](https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep).

**Setup** (happens automatically during install):
- A `PostToolUse` hook silently logs every tool call to `.circa/meta/events.jsonl`
- Zero user effort — logging is passive

**After 20+ loop cycles**:
```
/circa --mode meta-optimize
```

What it analyzes:
- Which agents fail most often? (bias toward flawed escalation rules)
- Which confidence scores were wrong? (auto-queued tasks that then failed)
- Which directives triggered clarification most often? (ambiguous phrasing patterns)
- What is the average cycle time? (step bottlenecks)

GPT reviews the analysis data and proposes minimal diffs to `SKILL.md`-style agent files. You approve each proposal before it's applied. All changes are logged and reversible.

---

## Directory Structure

```
circa/
├── install.sh                    ← install script
├── README.md                     ← this file
│
├── commands/                     ← slash command definitions
│   ├── circa.md                  ← /circa --mode run|review|meta-optimize|config
│   ├── circa-add.md              ← /circa-add "directive"
│   └── circa-status.md           ← /circa-status
│
├── agents/                       ← subagent definitions
│   ├── impl.md                   ← circa-impl: write & edit code
│   ├── test.md                   ← circa-test: run & fix tests
│   ├── review.md                 ← circa-review: diff quality + security
│   ├── search.md                 ← circa-search: research & docs
│   ├── critic.md                 ← circa-critic: self-review proposals
│   └── cross-critic.md           ← circa-cross-critic: GPT adversarial review ✨
│
├── scripts/
│   ├── night-loop-check.sh       ← Stop hook: drives the loop
│   └── meta-log.sh               ← PostToolUse hook: passive event logging ✨
│
├── hooks/
│   └── hooks.json                ← hook registration (Stop + PostToolUse) ✨
│
└── .circa/                       ← state files (copied to project on install)
    ├── config.toml               ← user-editable settings
    ├── feature.md                ← human directives
    ├── candidate.md              ← critic proposals
    ├── queue.md                  ← task execution queue
    ├── flags.md                  ← escalation log
    ├── completed.md              ← audit log
    └── meta/                     ← meta-optimization data ✨
        └── events.jsonl          ← passive tool-use log
```

---

## Requirements

| Requirement | Purpose | Optional? |
|------------|---------|-----------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Orchestrator and executor | Required |
| [Codex CLI](https://github.com/openai/codex) | Cross-model adversarial critic via MCP | Optional — falls back to self-review |
| `OPENAI_API_KEY` | Required by Codex CLI | Optional (with fallback) |
| Node.js | Used by install.sh for settings.json | Required for install |

---

---

# 中文说明

> [English](#circa-️) | **中文**

---

**circa** 是一个用于 Claude Code 的**持续自主改进循环**框架。

- **Claude Code** 担任编排者（Orchestrator）：读取你写在 Markdown 文件里的意图，将任务派发给专属子 Agent，并通过 Stop Hook 自动驱动下一轮执行。
- **Codex（GPT）** 担任对抗性评审者（Adversarial Reviewer）：以另一个模型的视角批评代码库，发现自我审查模型看不到的问题。

> 灵感来源：[ARIS ⚔️🌙](https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep)。circa 将 ARIS 的跨模型对抗评审架构和元优化 Harness 移植到通用软件工程工作流中。

---

## 核心理念

**为什么需要两个模型？**

单模型自我审查存在**自博弈盲区**：写出 Bug 的模式，和验证代码的模式往往是同一套思维定势，模型很难发现自己写的问题。这类似于随机赌博机问题——奖励噪声可预测，容易被"作弊"。

跨模型审查是**对抗性**的：GPT 主动探测 Claude 没有预料到的弱点。从 1 个模型到 2 个模型的质量跃升最大，增加到 3 个以上收益递减。

- **Claude Code**：执行速度快，流畅实现代码、运行测试、修复 Bug。
- **GPT（通过 Codex MCP）**：审查更审慎，以不同视角进行对抗性批评。

---

## 架构图

```
Human intent（用户意图）
feature.md ─────────────────────────────────────────┐
                                                    │
                                                    ▼
                                      ┌─────────────────────────┐
                                      │       编排器            │
                                      │  /circa --mode run      │
                                      └──────────┬──────────────┘
                                                 │
              ┌──────────────────────────────────┼──────────────────────┐
              │                                  │                      │
              ▼                                  ▼                      ▼
    ┌─────────────────┐              ┌──────────────────┐    ┌──────────────────┐
    │    子 Agent      │              │  跨模型批评者     │    │  自我批评者      │
    │                 │              │  circa-cross-    │    │  circa-critic    │
    │ impl  写代码     │              │  critic          │    │  (自审 fallback) │
    │ test  跑测试     │              │  (GPT, 对抗性)   │    │                  │
    │ review 代码审查  │              └────────┬─────────┘    └────────┬─────────┘
    │ search 文档搜索  │                       │                       │
    └────────┬────────┘                       ▼                       ▼
             │                         candidate.md (GPT提案)  candidate.md (自审提案)
             ▼
    queue.md / flags.md
    completed.md

Stop Hook 在每次 Claude 响应后触发 → 驱动循环继续
PostToolUse Hook → events.jsonl（被动元日志）
```

---

## 快速安装

```bash
# 1. 克隆 circa
git clone https://github.com/yourname/circa
cd your-project

# 2. 安装到你的项目
bash circa/install.sh

# 3. （可选但推荐）配置 Codex MCP，启用跨模型评审
npm install -g @openai/codex
codex setup              # 提示时选择 gpt-5.4 作为模型
claude mcp add codex -s user -- codex mcp-server
```

安装脚本会自动完成：
- 将命令文件复制到 `.claude/commands/`
- 将子 Agent 定义复制到 `.claude/agents/`
- 将脚本复制到 `.claude/scripts/`
- 创建 `.circa/` 状态目录（已存在的文件不覆盖）
- 在 `.claude/settings.json` 里注册 **Stop Hook** 和 **PostToolUse Hook**

---

## 快速开始

```bash
# 启动持续循环（直到你手动停止）
/circa --mode run

# 添加人类指令（循环会自动拾取）
/circa-add "给 /api/chat 接口添加频率限制 —— 每 IP 每分钟最多 60 次"

# 查看当前状态：运行中/等待/已标记
/circa-status

# 起床后检查结果、解决标记、审批候选提案
/circa --mode review

# 20+ 轮循环后，让循环改进自身的 Agent 提示词
/circa --mode meta-optimize

# 随时停止循环
rm .circa/loop.local.md
```

---

## 循环工作原理

循环由 **Claude Code Stop Hook** 驱动——每次 Claude 响应结束后，Shell 脚本自动触发并注入下一个继续提示。循环不会忙等；Claude 结束响应，Hook 触发，Claude 从上次中断处继续。

### 每个循环周期按优先级依次执行：

**第 1 步 — 人类指令（最高优先级）**

读取 `.circa/feature.md`，找到第一个 `[ ]` 指令：
- **置信度 ≥ 70%**：指令清晰 → 自动在 `queue.md` 创建任务，将指令标为 `[>]`
- **置信度 < 70%**：指令模糊 → 写入 `flags.md` 请求澄清，将指令标为 `[?]`

**第 2 步 — 审批候选提案**

读取 `.circa/candidate.md`，处理：
- 人类标记为 `[y]` 的条目（无论置信度）
- 置信度 ≥ 阈值（默认 80）的条目 → 自动入队，无需人工

低于阈值的提案留在 `candidate.md`，等待通过 `/circa --mode review` 审批。

**第 3 步 — 执行待处理任务**

读取 `queue.md`，找到第一个 `[ ]` 任务，调用对应子 Agent：

| 任务 `agent:` 字段 | 调用的子 Agent |
|------------------|--------------|
| `impl` | `circa-impl` 写代码编辑 |
| `test` | `circa-test` 跑测试修 Bug |
| `review` | `circa-review` 代码质量审查 |
| `search` | `circa-search` 研究和文档搜索 |

**成功** → 标为 `[x]`，追加到 `completed.md`  
**3 次尝试后失败** → 标为 `[!]`，写入 `flags.md`

**第 4 步 — 空闲时生成新提案**

1-3 步均无工作时，调用批评者 Agent：
- `cross_model_review = true`（默认）→ `circa-cross-critic`（GPT 对抗性审查）
- 否则 → `circa-critic`（自审）

批评者向 `candidate.md` 写入 3-5 个提案，循环立即检查是否有可自动入队的提案。

---

## 状态文件说明

| 文件 | 谁来写 | 用途 |
|------|-------|------|
| `.circa/feature.md` | **你** | 人类指令，最高优先级 |
| `.circa/candidate.md` | **批评者 Agent** | 改进提案（含置信度评分） |
| `.circa/queue.md` | **编排器** | 等待执行的任务队列 |
| `.circa/flags.md` | **子 Agent** | 升级标记——需要人工处理 |
| `.circa/completed.md` | **编排器** | 只追加的审计日志 |
| `.circa/loop_state.json` | **编排器** | 实时循环状态和统计 |
| `.circa/meta/events.jsonl` | **Hook** | 被动工具调用日志，用于元优化 |

---

## 命令详解

| 命令 | 作用 |
|------|------|
| `/circa --mode run` | 启动持续循环 |
| `/circa --mode review` | 交互式晨间审查：查看完成情况、解决 Flag、审批候选提案 |
| `/circa --mode meta-optimize` | 分析使用数据，改进 Agent 提示词和配置默认值 |
| `/circa --mode config` | 交互式编辑 `.circa/config.toml` |
| `/circa-add "指令"` | 快速向 `feature.md` 添加指令 |
| `/circa-status` | 显示完整状态表 |

---

## 子 Agent 说明

所有 Agent 遵循**穷尽再放弃**原则：用 3 种不同策略尝试后才写入 `flags.md`。

| Agent | 职责 |
|-------|------|
| `circa-impl` | 在 `scope` 范围内编写和修改代码 |
| `circa-test` | 运行测试，诊断失败，在 scope 内修复 |
| `circa-review` | 检查 diff 质量，修复 BLOCKER（含 OWASP Top 10 安全检查） |
| `circa-search` | 网络和代码库研究，将结果写入 `.circa/research/` |
| `circa-critic` | 自审批评者：生成改进提案（只读） |
| `circa-cross-critic` | **GPT 对抗性批评者**，通过 Codex MCP 调用，标注 `reviewer: gpt (cross-model)` ✨ |

---

## 配置参考

```toml
[loop]
approval_mode = "full-auto"    # full-auto（全自动）| auto-edit | suggest
confidence_threshold = 80      # 超过此分值的提案自动入队（0-100）
human_checkpoint = false       # 每轮暂停等待人工确认
max_cycles = 0                 # 最大循环次数（0 = 不限）

[review]
cross_model_review = true      # 启用 GPT 对抗性批评者（需要 Codex MCP）
reviewer_model = "gpt-5.4"    # 评审模型
cross_model_frequency = 1     # 每 N 个批评周期使用跨模型（1 = 始终）

[notifications]
webhook_url = ""               # Slack/Discord/飞书/自定义 HTTP
webhook_events = ["task_fail", "flag_created", "loop_stop"]

[meta]
meta_logging = true            # 记录工具调用到 events.jsonl
meta_optimize_reminder_cycles = 20   # 每 N 轮提示运行 meta-optimize
```

---

## 元优化（Meta-Optimization）

circa 能够利用积累的使用数据**改进自身的 Agent 提示词和配置默认值**，灵感来自 [ARIS 元优化 Harness](https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep)。

**原理：**
1. `PostToolUse` Hook 在每次工具调用后静默记录事件到 `.circa/meta/events.jsonl`（零用户感知）
2. 累积 20+ 轮循环后运行 `/circa --mode meta-optimize`
3. 分析模式：
   - 哪些 Agent 失败最频繁？（缺陷的升级规则）
   - 哪些置信度评分出错？（自动入队但最终失败）
   - 哪些指令最常触发澄清请求？（模糊表达模式）
4. GPT 审查分析数据，提出最小化改进方案（精确到文件和行级别的修改）
5. 你确认后自动应用，所有变更均记录且可回滚

---

## 系统要求

| 依赖 | 用途 | 是否必需 |
|------|------|---------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | 编排器和执行器 | 必需 |
| [Codex CLI](https://github.com/openai/codex) | 跨模型对抗批评者（通过 MCP） | 可选（降级为自审） |
| `OPENAI_API_KEY` | Codex CLI 需要 | 可选（有降级方案） |
| Node.js | install.sh 用于修改 settings.json | 安装时需要 |


