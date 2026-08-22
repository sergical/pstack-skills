# pstack-skills

A curated, harness-neutral subset of [poteto's pstack](https://github.com/cursor/plugins/tree/main/pstack),
renamed to `pstack-*` so the source is visible in every harness and so the ids never collide with other
installed skills (`bro`, `teach`, `tdd`).

Upstream: `cursor/plugins` at the commit recorded in `UPSTREAM_SHA`. License: MIT (see `LICENSE`).

## What is here

- `skills/pstack-<id>/` for every `skill <id>` line in `IMPORT_SET`.
- `agents/pstack-comment-sicko.md`, the read-only comment auditor that `pstack-no-comments` spawns.

## Local changes against upstream

1. Directory and frontmatter `name` carry the `pstack-` prefix. Cross-references between imported skills use the
   prefix. `/bro` is left as is because the same skill is already installed under that id.
2. Explicit skills (`disable-model-invocation: true`) also declare `metadata.opencode/autoinvoke: false` and
   `metadata.opencode/slash: true` so OpenCode treats them as slash-only.
3. Cursor-only primitives are replaced with harness-neutral wording: Task/`subagent_type` becomes "spawn a subagent"
   with the Claude Code / OpenCode / Codex / Pi agent names, `pstack-models.mdc` roles become "one reviewer per model
   role configured in your harness", `AskQuestion` becomes the harness question tool, Cursor transcript paths become
   the Claude Code, Codex, OpenCode and Pi transcript stores, `~/.cursor/skills` becomes `~/.agents/skills`.
4. References to pstack skills that are not imported (`poteto-mode`, `automate-me`, `swarm`, ...) are removed or
   turned into plain prose.

## Update from upstream

```sh
scripts/import-upstream.sh <new-sha>      # stages a mechanical re-import under upstream-staging/
diff -r upstream-staging/skills skills     # review; fold upstream changes into skills/ by hand
scripts/check.sh                          # no Cursor primitives, no unprefixed cross-refs
```

Then update `UPSTREAM_SHA`, commit, push, and bump the pinned `ref` in the dotfiles `agents.toml`.

## Install

Declared in the dotfiles `dot_agents/agents.toml` as a wildcard pack:

```toml
[[skills]]
name = "*"
source = "sergical/pstack-skills"
ref = "<commit sha>"
path = "skills"
```
