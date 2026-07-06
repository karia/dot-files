#!/bin/zsh
# .zshenv is sourced for EVERY zsh invocation (login, interactive, scripts,
# and non-interactive `zsh -c` used by editors, hooks, Claude Code, cron).
# Put PATH and environment settings here so tools resolve even when
# .zshrc (interactive-only) and .zprofile (login-only) are NOT sourced.

# shared helpers -- intentionally duplicated in .zshrc so each file
# works standalone even when the other is missing (e.g. symlink not created)
source_if_exists() { [[ -f "$1" ]] && source "$1"; }
add_path_if_exists() { [[ -d "$1" ]] && export PATH="$1:${PATH}"; }

# Run environment/PATH setup once per process tree to avoid PATH duplication
# and redundant work in nested shells and scripts.
if [[ -z "$__ZSHENV_SETUP_DONE" ]]; then
  export __ZSHENV_SETUP_DONE=1

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

  # mise: shims for non-interactive shells (scripts, hooks, Claude Code, cron).
  # Interactive shells use `mise activate zsh` (function mode) in .zshrc.
  if [[ ! -o interactive ]]; then
    command -v mise >/dev/null 2>&1 && eval "$(mise activate --shims)"
  fi
fi
