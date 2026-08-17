#!/usr/bin/env bash
# Reinstall every third-party skill recorded in .skill-lock.json.
#
# Only skills written here are versioned; third-party ones are a cache that this
# script rebuilds, so a fresh machine needs `stow agents` and then this.
set -Eeuo pipefail

LOCK="${HOME}/.agents/.skill-lock.json"
SKILLS="${HOME}/.agents/skills"

[[ -f $LOCK ]] || { echo "no lock file at $LOCK - run \`stow agents\` first" >&2; exit 1; }

rows=$(mktemp)
trap 'rm -f "$rows"' EXIT

# One npx call per source repo rather than per skill.
python3 - "$LOCK" >"$rows" <<'PY'
import collections, json, sys

lock = json.load(open(sys.argv[1]))
by_source = collections.defaultdict(list)
for name, entry in lock.get("skills", {}).items():
    by_source[entry["source"]].append(name)
for source, names in sorted(by_source.items()):
    print(f"{source}\t{' '.join(sorted(names))}")
PY

while IFS=$'\t' read -r source names; do
    echo "restoring ${source}"
    # -s takes one skill per flag; a comma- or space-joined list is read as a
    # single name and silently matches nothing.
    args=()
    for name in $names; do args+=(-s "$name"); done
    # -a claude-code only: init.sh fans ~/.agents/skills out to every harness.
    npx -y skills@latest add "$source" -g "${args[@]}" -a claude-code -y </dev/null
done <"$rows"

# A skill that is neither locked nor committed exists on this machine only. That
# is fine for a scratch skill and a silent loss for one meant to be versioned.
echo
locked=$(python3 -c 'import json,sys;print("\n".join(json.load(open(sys.argv[1]))["skills"]))' "$LOCK")
for dir in "$SKILLS"/*/; do
    name=$(basename "$dir")
    grep -qxF "$name" <<<"$locked" && continue
    git -C "${HOME}/.dotfiles" ls-files --error-unmatch \
        "agents/.agents/skills/${name}" >/dev/null 2>&1 && continue
    echo "  untracked: ${name} - not in the lock file and not committed"
done
