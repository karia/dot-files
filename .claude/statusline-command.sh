#!/bin/bash
input=$(cat)
user=$(whoami)
host=$(hostname -s)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

line="${user}@${host} ${cwd}"

if command -v ccusage >/dev/null 2>&1; then
  usage=$(printf '%s' "$input" | ccusage statusline 2>/dev/null)
else
  usage=$(printf '%s' "$input" | npx -y ccusage statusline 2>/dev/null)
fi

if [ -n "$usage" ]; then
  second="${usage}"
else
  model=$(echo "$input" | jq -r '.model.display_name // empty')
  used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
  [ -n "$model" ] && second="${model}"
  [ -n "$used" ] && second="${second} [context: $(printf '%.0f' "$used")%]"
fi

if [ -n "$second" ]; then
  printf '%s\n%s' "$line" "$second"
else
  printf '%s' "$line"
fi
