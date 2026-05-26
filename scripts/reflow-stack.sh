#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/tmux.sh"

active_pane="${1:-}"
[ -n "$active_pane" ] || {
  echo 'tmux-stacked-panes: missing active pane id' >&2
  exit 1
}

stack_id="$(stacked_panes_get_pane_option "$active_pane" @stacked-panes-id '')"
[ -n "$stack_id" ] || exit 0
window_id="$("$TMUX_BIN" display-message -p -t "$active_pane" '#{window_id}')"

pane_ids=()
pane_heights=()
total_height=0

while IFS=$'\t' read -r pane_id _pane_top pane_height pane_stack_id; do
  [ "$pane_stack_id" = "$stack_id" ] || continue
  pane_ids+=("$pane_id")
  pane_heights+=("$pane_height")
  total_height=$((total_height + pane_height))
done < <("$TMUX_BIN" list-panes -t "$window_id" -F '#{pane_id}	#{pane_top}	#{pane_height}	#{@stacked-panes-id}' | sort -t $'\t' -k2,2n)

pane_count="${#pane_ids[@]}"
[ "$pane_count" -gt 0 ] || exit 0

if [ "$total_height" -lt "$pane_count" ]; then
  "$TMUX_BIN" display-message "tmux-stacked-panes: not enough room to reflow stack $stack_id" 2>/dev/null || true
  exit 0
fi

active_height=$((total_height - pane_count + 1))
[ "$active_height" -ge 1 ] || active_height=1

for pane_id in "${pane_ids[@]}"; do
  if [ "$pane_id" = "$active_pane" ]; then
    stacked_panes_set_pane_option "$pane_id" @stacked-panes-active 1
  else
    stacked_panes_unset_pane_option "$pane_id" @stacked-panes-active || true
    "$TMUX_BIN" resize-pane -t "$pane_id" -y 1 2>/dev/null || true
  fi
done

"$TMUX_BIN" resize-pane -t "$active_pane" -y "$active_height" 2>/dev/null || true
