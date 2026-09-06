#!/bin/sh
# Herdr tab bar right status. Prints one metric, or nothing when unavailable.
set -u

case "${1:-}" in
mem)
	if [ -r /proc/meminfo ]; then
		awk '/^MemTotal:/ {t = $2} /^MemAvailable:/ {a = $2}
			END {printf "%.1f/%.1fG", (t - a) / 1048576, t / 1048576}' /proc/meminfo
	elif command -v vm_stat >/dev/null 2>&1; then
		vm_stat | awk -v total="$(sysctl -n hw.memsize)" '
			/page size of/ {for (i = 1; i <= NF; i++) if ($i == "of") ps = $(i + 1)}
			/^Pages active:/ {sub(/\./, "", $NF); a = $NF}
			/^Pages wired down:/ {sub(/\./, "", $NF); w = $NF}
			/^Pages occupied by compressor:/ {sub(/\./, "", $NF); c = $NF}
			END {printf "%.1f/%.1fG", (a + w + c) * ps / 1073741824, total / 1073741824}'
	fi
	;;
uptime)
	if [ -r /proc/uptime ]; then
		secs=$(cut -d. -f1 /proc/uptime)
	elif boot=$(sysctl -n kern.boottime 2>/dev/null); then
		boot=${boot#*sec = }
		secs=$(($(date +%s) - ${boot%%,*}))
	else
		exit 0
	fi
	awk -v s="$secs" 'BEGIN {
		d = int(s / 86400); h = int(s % 86400 / 3600); m = int(s % 3600 / 60)
		if (d >= 7) printf "%dw %dd", int(d / 7), d % 7
		else if (d > 0) printf "%dd %dh", d, h
		else if (h > 0) printf "%dh %dm", h, m
		else printf "%dm", m
	}'
	;;
esac
