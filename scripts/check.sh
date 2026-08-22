#!/bin/sh
# Fail when a skill still carries Cursor-only primitives, an unprefixed pstack cross-reference,
# or a frontmatter name that does not match its directory.
set -u
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ids=$(grep -E '^skill ' "$root/IMPORT_SET" | awk '{print $2}')
out=$(mktemp); trap 'rm -f "$out"' EXIT HUP INT TERM
report() { echo "$1" >> "$out"; }

for dir in "$root"/skills/*/; do
  id=$(basename "$dir")
  name=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^name: /{sub(/^name: /,"");print;exit}' "$dir/SKILL.md")
  [ "$name" = "$id" ] || report "name mismatch: $id has name: $name"
done

prims='subagent_type|generalPurpose|AskQuestion|~/\.cursor|\.cursor/|agent-transcripts|pstack-models|environment: *"?cloud|Cursor'
grep -rnE "$prims" "$root/skills" "$root/agents" | while IFS= read -r line; do report "cursor primitive: $line"; done

for id in $ids; do
  grep -rnE "(^|[^a-z-])/$id\b|\`$id\`" "$root/skills" "$root/agents" | grep -v "pstack-$id" | while IFS= read -r line; do report "unprefixed ref to $id: $line"; done
done

others='automate-me|poteto-mode|figure-it-out|swarm|setup-pstack|create-verification-skill|maintain-verification-skill|principle-[a-z-]+'
grep -rnoE "(/|\`|\b)($others)\b" "$root/skills" "$root/agents" | grep -vE 'pstack-' | grep -vE "$(echo $ids | sed 's/ /|/g')" | while IFS= read -r line; do report "ref to non-imported skill: $line"; done

if [ -s "$out" ]; then cat "$out"; exit 1; fi
echo "pstack-skills check: OK"
