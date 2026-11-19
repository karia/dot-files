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

limits=$(printf '%s' "$input" | jq -r '
  def pct(name; w; fmt):
    w.used_percentage as $p | select($p != null)
    | (if $p >= 90 then "\u001b[31m" elif $p >= 80 then "\u001b[33m" else "\u001b[32m" end)
      + "\(name) \($p | round)%\u001b[0m"
      + (w.resets_at | if . then " (~\(strflocaltime(fmt)))" else "" end);
  [
    pct("5h"; .rate_limits.five_hour // {}; "%H:%M"),
    pct("7d"; .rate_limits.seven_day // {}; "%m/%d %H:%M")
  ] | join(" ")
' 2>/dev/null)
[ -n "$limits" ] && second="${second:+${second} | }${limits}"

if [ -n "$second" ]; then
  printf '%s\n%s' "$line" "$second"
else
  printf '%s' "$line"
fi
