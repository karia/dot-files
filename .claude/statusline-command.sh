#!/bin/bash
input=$(cat)
user=$(whoami)
host=$(hostname -s)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

line="${user}@${host} ${cwd}"
[ -n "$model" ] && line="${line} | ${model}"
[ -n "$used" ] && line="${line} [context: $(printf '%.0f' "$used")%]"

printf '%s' "$line"
