# mise: shims activation for non-interactive sessions (Claude Code, scripts, cron, etc.)
# Interactive sessions use PATH-based activation via `mise activate zsh` in .zshrc
if [[ ! -o interactive ]]; then
  command -v mise >/dev/null 2>&1 && eval "$(mise activate --shims)"
fi
