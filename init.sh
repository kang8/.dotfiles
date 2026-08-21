#!/usr/bin/env bash
set -Eeuo pipefail

# setup
mkdir -p ~/.config/lazygit || true
mkdir -p ~/.local/bin || true
# Ensure ~/.codex exists so `stow codex` folds into it (links individual files)
# instead of turning the whole dir into a symlink and polluting the repo with
# codex runtime data (sqlite, sessions, logs).
mkdir -p ~/.codex || true
# Same folding trick for ~/.agents/skills: third-party skills live here as real
# directories (restored from the Skillfile), ours arrive as stow symlinks.
mkdir -p ~/.agents/skills || true
cp .env.example .env

########
# stow
########
echo "stow beginning!!!"

stow_exclude=('~/' 'ibus-rime/' 'sublime-text/' 'wakatime/' 'gnupg/' 'raycast-script/' 'tampermonkey-scripts')

for i in `ls -d */`; do
    printf "%s\n" "${stow_exclude[@]}" | grep -x -q "$i" ||
        ( echo "  stow $i" && stow $i )
done

# Seed codex's config on a fresh machine only. config.toml is stow-ignored (see
# codex/.stow-local-ignore) because Codex owns/rewrites it in place; `-n` never
# clobbers an existing live file, so re-runs are safe.
cp -n codex/.codex/config.toml ~/.codex/config.toml || true

# Third-party skills are git-ignored (see .gitignore); rebuild them from the
# lock file. Skipped when they are already present, since it hits the network.
if [[ ! -d ~/.agents/skills || -z "$(ls -A ~/.agents/skills 2>/dev/null)" ]]; then
    echo "restoring third-party skills..."
    ~/.agents/restore-skills.sh || true
fi

# Fan ~/.agents/skills out to each harness. Claude Code hardcodes its scan roots
# to .claude/skills and ~/.claude/skills and never looks at ~/.agents, so every
# skill needs its own link rather than one directory link. Real directories are
# left alone: that is how a harness keeps a local-only skill out of the repo.
for harness in ~/.claude/skills ~/.codex/skills; do
    [[ -L "$harness" ]] && rm "$harness"
    mkdir -p "$harness"
    # drop links to skills that no longer exist upstream
    find "$harness" -maxdepth 1 -type l ! -exec test -e {} \; -delete
    for skill in ~/.agents/skills/*/; do
        name=$(basename "$skill")
        # if/else, not `[[ … ]] && continue`: on a real directory ln -sfn puts the
        # link *inside* it, so a skipped guard silently nests <name>/<name>.
        # Absolute, not ../../: the relative form hardcodes a depth of two and
        # would silently dangle for a harness nested any deeper. These links are
        # regenerated per machine, so there is nothing to gain by keeping them
        # relocatable.
        if [[ -d "$harness/$name" && ! -L "$harness/$name" ]]; then
            :
        else
            ln -sfn "${HOME}/.agents/skills/$name" "$harness/$name"
        fi
    done
done

# Restore Yazi's plugins at the revisions locked in yazi/.config/yazi/package.toml.
# The plugins/ directory is git-ignored, so this is what a fresh machine needs
# (it replaces the ranger_devicons submodule the old ranger config carried).
# Must run after stow, since `ya` reads ~/.config/yazi.
if command -v ya &> /dev/null; then
    echo "restoring yazi plugins..."
    ya pkg install || true
fi

zsh ~/.zshrc

########
# ZSH
########
ZSH="${HOME}/.config/zsh/.oh-my-zsh"

if [[ -d ${ZSH} ]]; then
    echo "oh-my-zsh is already installed."
else
    echo "Install oh-my-zsh..."
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ${ZSH}
fi

install_zsh_plugin() {
    local name=$1 repo=$2
    local dest="${ZSH}/custom/plugins/${name}"
    if [[ -d "$dest" ]]; then
        echo "${name} is already installed."
    else
        echo "Install zsh plug: ${name}..."
        git clone --depth=1 "$repo" "$dest"
    fi
}

install_zsh_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
install_zsh_plugin fzf-tab https://github.com/Aloxaf/fzf-tab.git
install_zsh_plugin z.lua https://github.com/skywind3000/z.lua.git
install_zsh_plugin zsh-autopair https://github.com/hlissner/zsh-autopair
install_zsh_plugin you-should-use https://github.com/MichaelAquilina/zsh-you-should-use.git
install_zsh_plugin fast-syntax-highlighting https://github.com/zdharma-continuum/fast-syntax-highlighting.git
install_zsh_plugin zsh-completions https://github.com/zsh-users/zsh-completions.git

######## neovim ########
echo "\n"
echo "neovim beginning!!!"
echo "\n"
if [[ -d ~/.config/nvim ]];then
    echo "~/.config/nvim is already installed."
else
    git clone --depth=1 git@github.com:kang8/.vimrc.git ~/.config/nvim
fi

########
# gpg
########
echo "\n"
echo "gpg beginning!!!"
echo "\n"

# create ~/.gnupg/
gpg -k

if [[ -d ~/kang/gpg-key-ring ]]; then
    echo "~/kang/gpg-key-ring is already installed."
else
    git clone --depth=1 git@github.com:kang8/gpg-key-ring.git ~/kang/gpg-key-ring
fi

stow gnupg

# Create symlink for pinentry-mac to support both Apple Silicon and Intel
ln -sf "$(brew --prefix pinentry-mac)/bin/pinentry-mac" ~/.local/bin/pinentry-mac

# Shadow GNUPGHOME used by Claude Code's sandbox (see claude/.claude/settings.json).
# Sandboxed gpg reaches gpg-agent only through its *restricted* socket, which
# refuses EXPORT_KEY, so sandboxed code can sign but cannot exfiltrate the private
# key. gpg's lock/random_seed/trustdb writes land here instead of in ~/.gnupg.
#
# This directory deliberately contains NO symlinks. A socket bind unlinks its path
# first, so a symlink to a real ~/.gnupg socket would let any daemon accidentally
# started against this home hijack the real socket with an empty keyring, breaking
# GPG system-wide. Instead:
#   - S.gpg-agent is bound here directly by the real agent (see gnupg/.gnupg/gpg-agent.conf)
#   - the public keyring is a static local copy, so no keyboxd socket is needed
#
# HAZARD: never run gpgconf/gpg from inside Claude Code without setting
# GNUPGHOME=$HOME/.gnupg explicitly. Claude Code exports GNUPGHOME=~/.gnupg-sandbox
# for every subprocess, including ones run outside the sandbox.
mkdir -p ~/.gnupg-sandbox
chmod 700 ~/.gnupg-sandbox
# no-autostart: never let a sandboxed gpg spawn its own agent; a sandboxed agent
# cannot launch pinentry-mac (Apple Events are blocked) and would break signing.
printf 'keyid-format long\nno-autostart\n' > ~/.gnupg-sandbox/gpg.conf
# Static public keyring. Note this is a snapshot: keys imported into ~/.gnupg
# later are not visible to Claude Code until this runs again.
GNUPGHOME=~/.gnupg gpg --batch --export | GNUPGHOME=~/.gnupg-sandbox gpg --batch --import
# ownertrust lives in GNUPGHOME/trustdb.gpg, so without this the shadow home
# treats your own key as unknown and git reports signatures as U, not G.
GNUPGHOME=~/.gnupg gpg --batch --export-ownertrust > ~/.gnupg-sandbox/ownertrust.txt
GNUPGHOME=~/.gnupg-sandbox gpg --batch --import-ownertrust ~/.gnupg-sandbox/ownertrust.txt
# The agent must be (re)started so it binds extra-socket into the shadow home.
GNUPGHOME=~/.gnupg gpgconf --kill gpg-agent
GNUPGHOME=~/.gnupg gpgconf --launch gpg-agent

########
# MacOS setting
########
# Disable the .DS file creation
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Show the path bar in the Finder
defaults write com.apple.finder "ShowPathbar" -bool "true" && killall Finder

# Show hidden files in the Finder
defaults write com.apple.finder "AppleShowAllFiles" -bool "true" && killall Finder

########
# Miscellaneous items
########

# Make these files immutable to prevent external programs from modifying them
chflags uimmutable ~/.zprofile
chflags -h uimmutable ~/.zshrc # Use `-h` flag for symbolic links to change the link's flags rather than the target file
# `chflags nouimmutable ~/.zprofile` If you want to modify them
