protected_branches="main|master|develop"

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
