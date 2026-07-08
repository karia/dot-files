#!/bin/zsh
# .zshenv is sourced for EVERY zsh invocation (login, interactive, scripts,
# and non-interactive `zsh -c` used by editors, hooks, Claude Code, cron).
# Put PATH and environment settings here so tools resolve even when
# .zshrc (interactive-only) and .zprofile (login-only) are NOT sourced.

# shared helpers -- intentionally duplicated in .zshrc so each file
# works standalone even when the other is missing (e.g. symlink not created)
source_if_exists() { [[ -f "$1" ]] && source "$1"; }
add_path_if_exists() {
  [[ -d "$1" ]] || return
  case ":$PATH:" in
    *":$1:"*) ;;                    # already on PATH -- do nothing (idempotent)
    *) export PATH="$1:${PATH}" ;;
  esac
}

# No once-per-process-tree guard: every add below is idempotent (add_path_if_exists
# skips dirs already on PATH; brew/mise evals are gated on their target being absent),
# so re-sourcing in nested shells is cheap and edits take effect on a new shell.

export EDITOR='vim'

# Homebrew: login shells also set this in .zprofile (to survive macOS
# /etc/zprofile path_helper reordering), but non-login shells only source
# .zshenv -- and mise itself lives in Homebrew's bin, so run this before mise.
if [[ -x /opt/homebrew/bin/brew ]] && [[ ":$PATH:" != *":/opt/homebrew/bin:"* ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

add_path_if_exists "${HOME}/.local/bin"

# Go
if [[ -d "${HOME}/go" ]]; then
  export GOPATH="${HOME}/go"
  add_path_if_exists "${GOPATH}/bin"
fi

case ${OSTYPE} in
  darwin*)
    # mysql-client 8.4 (HOMEBREW_PREFIX is set by brew shellenv above)
    add_path_if_exists "$HOMEBREW_PREFIX/opt/mysql-client@8.4/bin"
    ;;
  linux*)
    # Linuxbrew
    [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    # snap
    add_path_if_exists "/snap/bin"
    ;;
esac

# Google Cloud SDK PATH (completion stays in .zshrc -- interactive only)
source_if_exists "${HOME}/projects/others/google-cloud-sdk/path.zsh.inc"

# pnpm: global bin for CLIs installed via `pnpm add -g` / `pnpm link --global`.
# `pnpm setup` writes this to .zshrc, but keep it here so non-interactive
# shells (Claude Code, hooks) also resolve globally-installed commands.
# Only set it where the global bin actually exists (same shape as Go above).
if [[ -d "${HOME}/Library/pnpm/bin" ]]; then
  export PNPM_HOME="${HOME}/Library/pnpm"
  add_path_if_exists "$PNPM_HOME/bin"
fi

# mise: shims for non-interactive shells (scripts, hooks, Claude Code, cron).
# Interactive shells use `mise activate zsh` (function mode) in .zshrc.
# Skip the eval when the shims dir is already on PATH so nested shells don't re-run it.
if [[ ! -o interactive ]] && [[ ":$PATH:" != *":${HOME}/.local/share/mise/shims:"* ]]; then
  command -v mise >/dev/null 2>&1 && eval "$(mise activate --shims)"
fi
