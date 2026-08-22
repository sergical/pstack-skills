#!/bin/sh
# Import selected pstack skills from cursor/plugins at a pinned SHA into ./upstream-staging/.
# Mechanical only: copy, rename to pstack-<id>, rewrite unambiguous cross-references,
# add OpenCode user-invoked metadata. Harness-specific porting is done by hand in skills/.
# Usage: scripts/import-upstream.sh <sha>   (then diff upstream-staging/ against skills/)
set -eu
sha=${1:?usage: import-upstream.sh <sha>}
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
manifest="$root/IMPORT_SET"
staging="$root/upstream-staging"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

git clone -q --filter=blob:none --sparse https://github.com/cursor/plugins.git "$work/plugins"
git -C "$work/plugins" sparse-checkout set pstack >/dev/null
git -C "$work/plugins" checkout -q "$sha"
src="$work/plugins/pstack"

rm -rf "$staging"
mkdir -p "$staging/skills" "$staging/agents"
cp "$src/LICENSE" "$staging/LICENSE"

skills=$(grep -E '^skill ' "$manifest" | awk '{print $2}')
agents=$(grep -E '^agent ' "$manifest" | awk '{print $2}')

sed_script="$work/rewrite.sed"
: > "$sed_script"
for id in $skills; do
  # slash form and backtick form are unambiguous for every id
  printf 's#/%s\\b#/pstack-%s#g\n' "$id" "$id" >> "$sed_script"
  printf 's#`%s`#`pstack-%s`#g\n' "$id" "$id" >> "$sed_script"
  # bare hyphenated ids never collide with prose; single words (how, why, teach...) are left for hand review
  case $id in
    *-*) printf 's#\\b%s\\b#pstack-%s#g\n' "$id" "$id" >> "$sed_script" ;;
  esac
done
# undo double prefixing produced by overlapping rules
printf 's#pstack-pstack-#pstack-#g\n' >> "$sed_script"

for id in $skills; do
  from="$src/skills/$id"; to="$staging/skills/pstack-$id"
  [ -d "$from" ] || { echo "missing upstream skill: $id" >&2; exit 1; }
  cp -R "$from" "$to"
  find "$to" -type f \( -name '*.md' -o -name '*.sh' \) | while IFS= read -r f; do
    sed -E -i '' -f "$sed_script" "$f"
  done
  skill_md="$to/SKILL.md"
  awk -v id="pstack-$id" '
    BEGIN{fm=0}
    NR==1 && /^---$/ {fm=1; print; next}
    fm==1 && /^---$/ {
      if (dmi && !meta) { print "metadata:"; print "  opencode/autoinvoke: false"; print "  opencode/slash: true" }
      fm=2; print; next
    }
    fm==1 && /^name: / { print "name: " id; next }
    fm==1 && /^disable-model-invocation: true/ { dmi=1 }
    fm==1 && /^metadata:/ { meta=1 }
    { print }
  ' "$skill_md" > "$skill_md.tmp" && mv "$skill_md.tmp" "$skill_md"
done

for id in $agents; do
  from="$src/agents/$id.md"; to="$staging/agents/pstack-$id.md"
  [ -f "$from" ] || { echo "missing upstream agent: $id" >&2; exit 1; }
  sed -E -f "$sed_script" "$from" > "$to"
  sed -E -i '' "s/^name: .*/name: pstack-$id/" "$to"
done

printf '%s\n' "$sha" > "$staging/UPSTREAM_SHA"
echo "staged $(echo $skills | wc -w | tr -d ' ') skills and $(echo $agents | wc -w | tr -d ' ') agents from cursor/plugins@$sha into $staging"
