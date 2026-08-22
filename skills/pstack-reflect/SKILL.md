---
name: pstack-reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use for /pstack-reflect or when the user says reflect.
disable-model-invocation: true
metadata:
  opencode/autoinvoke: false
  opencode/slash: true
---

# Reflect

Mine the current conversation for durable learnings, then route them into skill edits.

## When to invoke

- The user said "reflect" or "/pstack-reflect".
- A complex task (5+ tool calls) just landed cleanly and the recipe is worth keeping.
- The agent hit dead ends, found the working path, and the path generalizes.
- The user corrected the agent's approach mid-task.
- A non-trivial workflow emerged that isn't captured anywhere.

Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## Process

### 1. Locate the active transcript

The parent finds its own transcript file before fanning out. Look in the harness transcript store: Claude Code `~/.claude/projects/<slug>/*.jsonl` (slug = cwd with `/` replaced by `-`), Codex `~/.codex/sessions/**/*.jsonl`, OpenCode `~/.local/share/opencode/opencode.db` (tables `session_v2`, `message`, `part`; open with `sqlite3 -readonly`), Pi `~/.pi/agent/sessions/<slug>/*.jsonl`. Order by mtime, grep before reading, never read a whole file. Stay in the store directory for the active workspace. Do not glob across other projects. That crosses workspace boundaries and reads private chats from unrelated projects.

```bash
ls -t <transcript-dir>/*.jsonl <transcript-dir>/*/*.jsonl <transcript-dir>/*/subagents/*.jsonl 2>/dev/null | head -10
```

Three transcript layouts: legacy flat (`<id>.jsonl`), current nested (`<id>/<id>.jsonl`), and subagent (`<parent>/subagents/<child>.jsonl`).

For each candidate, read the first JSONL line and check that `message.content[0].text` contains the conversation's opening user prompt. Take the matching path. If no path resolves, write a tight digest of the session and pass that instead.

### 2. Spawn three reviewers in parallel

One message, three reviewers at once. Spawn a subagent with your harness's delegation tool (Claude Code and Pi: the Agent tool; OpenCode: an `@agent` mention; Codex: a configured agent). Use a read-only agent for exploration (Claude Code: `Explore`; OpenCode: `@explore`; Codex: `explorer`; Pi: `explore`) and a writer agent only when the step edits files. Reviewers need MCP access for context lookups (tickets, chat threads, observability traces referenced in the transcript) and a read-only agent can strip MCPs, so spawn writer agents here. The prompt forbids file writes; the parent applies edits.

Run one reviewer per model role configured in your harness (OpenCode: `@review`, `@judgment`, `@independent`; Codex: review, architect, repair; Claude Code and Pi: spawn each reviewer with a different `model`). Model diversity is the point; if only one model is available, say so in the output and run one reviewer.

| Lens | Model role | Prompt template |
|---|---|---|
| Judgment | judgment role | `references/judgment-reviewer.md` |
| Tooling | tooling role, a different model from judgment | `references/tooling-reviewer.md` |
| Divergent | judgment role | `references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in the subagent response body.

### 3. Synthesize

One subagent, on the judgment model role, a writer agent rather than a read-only one. The synthesizer's quality check includes spot-verifying citations, which can require MCP access; a read-only agent can strip MCPs. Use `references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. The synthesizer returns a structured Accepted / Rejected / Backlog list.

### 4. Structural enforcement check

Sanity-check the synthesizer's Accepted list. For any item that would be enforced more reliably by a lint rule, script, metadata flag, or runtime check, move it from Accepted to Backlog. The synthesizer already applies this criterion; this is a final pass before edits land. See the `pstack-principle-encode-lessons-in-structure` skill.

### 5. Apply

Before applying any Accepted edit, present the synthesizer's full Accepted/Rejected/Backlog output to the user and wait for explicit approval. The user picks which subset to apply and may redirect routings. Skill changes affect every future agent in the org; do not auto-apply.

Backlog items file to whatever devex / backlog tracker your team uses automatically. Those are tracker submissions, not skill edits. Only the Accepted list waits for approval.

For each approved Accepted item, follow the Routing field exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): parent does directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): hand to your harness's built-in `create-skill` skill and run its draft / test / iterate loop.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): hand to `create-skill` and run its description-optimization loop.
- `new skill via create-skill: <kebab-name>`: hand creation to `create-skill`. Do not invent the shape ad hoc.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done. Skip this step if it doesn't.

### 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
