# cron hands this a bare PATH and glab lives under the Homebrew prefix.
eval "$($HOME/.local/bin/brew-shellenv)"

protected_branches="main|master|develop"

# Empty when glab is not configured, which skips the merge request pass.
gitlab_host=$(glab config get host 2>/dev/null)

paths=(
  "$HOME/Projects"
)

for element in "${paths[@]}"; do
    echo "Expand $element directory"

    # Just get the first level directories
    directories=($(find "$element" -maxdepth 1 -type d))

    for dir in "${directories[@]}"; do
        if [ ! -d "$dir/.git" ]; then
            continue
        fi

        cd $dir

        # git only calls a branch merged when it is an ancestor, so squashed and
        # rebased merge requests slip through. Ask GitLab about those first.
        if [ ! -z "$gitlab_host" ] && git remote --verbose | command grep -q "$gitlab_host"; then
            branches_before=$(git branch --no-color --format='%(refname:short)')
            glab repo prune --yes --exclude "$(echo "$protected_branches" | command tr '|' ',')" > /dev/null 2>&1
            branches_after=$(git branch --no-color --format='%(refname:short)')
            pruned=$(echo "$branches_before" | command grep -vxF "$branches_after")

            if [ ! -z "$pruned" ]; then
                echo ""
                pwd
                echo "$pruned"
            fi
        fi

        branches_to_delete=$(git branch --no-color --merged | command grep -vE "^([+*]|\s*(${protected_branches})\s*$)")

        # Only print directory and delete branches if there are branches to delete
        if [ ! -z "$branches_to_delete" ]; then
            # pretty print
            echo ""
            pwd
            echo "$branches_to_delete" | command xargs git branch --delete 2>/dev/null
        fi
    done
done
