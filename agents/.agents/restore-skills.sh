#!/usr/bin/env bash
# Reinstall every third-party skill listed in the Skillfile.
#
# Only skills written here are versioned; third-party ones are a cache that this
# script rebuilds, so a fresh machine needs `stow agents` and then this.
set -Eeuo pipefail

SKILLFILE="${HOME}/.agents/Skillfile"
SKILLS="${HOME}/.agents/skills"

[[ -f $SKILLFILE ]] || { echo "no Skillfile at $SKILLFILE - run \`stow agents\` first" >&2; exit 1; }

# Strip comments and blanks once; "*" means every skill from that source.
entries=$(awk 'NF && $1 !~ /^#/ { print $1, $2 }' "$SKILLFILE")

# One npx call per source repo rather than per skill.
while read -r source; do
    echo "restoring ${source}"
    # -s takes one skill per flag; the CLI treats "*" as all skills from the
    # source. A comma- or space-joined list is read as one name and matches none.
    args=()
    while read -r name; do args+=(-s "$name"); done \
        < <(awk -v s="$source" '$1 == s { print $2 }' <<<"$entries" | LC_ALL=C sort)
    # -a claude-code only: init.sh fans ~/.agents/skills out to every harness.
    npx -y skills@latest add "$source" -g "${args[@]}" -a claude-code -y </dev/null
done < <(awk '{ print $1 }' <<<"$entries" | LC_ALL=C sort -u)

# The CLI copies into the agent directory and replaces any symlink there, so
# without this the harnesses drift apart: Claude Code reads its fresh copy while
# Codex still reads the older one under ~/.agents. Move each locked copy back to
# ~/.agents and re-link. A real directory that is *not* locked is a deliberate
# harness-local skill, so leave it. Expand wildcard sources from the lock file
# the successful install just refreshed, so newly added upstream skills count.
locked=$(
    awk '$2 != "*" { print $2 }' <<<"$entries"
    while read -r source; do
        jq -r --arg source "$source" \
            '.skills | to_entries[] | select(.value.source == $source) | .key' \
            "${HOME}/.agents/.skill-lock.json"
    done < <(awk '$2 == "*" { print $1 }' <<<"$entries")
)
locked=$(LC_ALL=C sort -u <<<"$locked")

# The lock file only grows: installing never drops the entry for a skill the
# Skillfile stopped asking for, so an upstream rename or regroup leaves a stale
# copy behind forever. Whatever the lock knows and $locked does not is exactly
# that. Safe to delete unprompted: only CLI installs reach the lock, so a
# hand-written or scratch skill can never land in here.
orphans=$(comm -23 \
    <(jq -r '.skills | keys[]' "${HOME}/.agents/.skill-lock.json" | LC_ALL=C sort -u) \
    <(cat <<<"$locked"))
if [[ -n $orphans ]]; then
    echo "removing $(wc -l <<<"$orphans" | tr -d ' ') skill(s) dropped from the Skillfile"
    # Unquoted: one argument per name. remove clears the lock entry, the copy
    # under ~/.agents and every harness link, so nothing is left to relink below.
    # shellcheck disable=SC2086
    npx -y skills@latest remove $orphans -g -y </dev/null
fi

for harness in "${HOME}/.claude/skills" "${HOME}/.codex/skills"; do
    [[ -d $harness ]] || continue
    for dir in "$harness"/*/; do
        name=$(basename "$dir")
        if [[ -L ${dir%/} ]]; then
            :
        elif grep -qxF "$name" <<<"$locked"; then
            rm -rf "${SKILLS:?}/${name}"
            mv "${dir%/}" "${SKILLS}/${name}"
        fi
    done
done

# Fan back out. if/else, not `[[ … ]] && continue`: on a real directory ln -sfn
# puts the link *inside* it, silently nesting <name>/<name>. Link target is
# absolute because a relative one hardcodes the harness's depth below $HOME.
for harness in "${HOME}/.claude/skills" "${HOME}/.codex/skills"; do
    mkdir -p "$harness"
    for dir in "$SKILLS"/*/; do
        name=$(basename "$dir")
        if [[ -d "$harness/$name" && ! -L "$harness/$name" ]]; then
            :
        else
            ln -sfn "${SKILLS}/${name}" "$harness/$name"
        fi
    done
done

# A skill in neither the Skillfile nor git exists on this machine only. That
# is fine for a scratch skill and a silent loss for one meant to be versioned.
echo
for dir in "$SKILLS"/*/; do
    name=$(basename "$dir")
    grep -qxF "$name" <<<"$locked" && continue
    git -C "${HOME}/.dotfiles" ls-files --error-unmatch \
        "agents/.agents/skills/${name}" >/dev/null 2>&1 && continue
    echo "  untracked: ${name} - not in the Skillfile and not committed"
done
