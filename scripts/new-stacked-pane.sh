#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/tmux.sh"

current_pane="${1:-}"
start_path="${2:-}"
[ -n "$current_pane" ] || current_pane="$("$TMUX_BIN" display-message -p '#{pane_id}')"
[ -n "$start_path" ] || start_path="$("$TMUX_BIN" display-message -p -t "$current_pane" '#{pane_current_path}')"

stack_id="$(stacked_panes_get_pane_option "$current_pane" @stacked-panes-id '')"
if [ -z "$stack_id" ]; then
  stack_id="$(stacked_panes_allocate_stack_id)"
  stacked_panes_set_pane_option "$current_pane" @stacked-panes-id "$stack_id"
fi
stacked_panes_set_pane_option "$current_pane" @stacked-panes-role real

new_pane="$("$TMUX_BIN" split-window -v -c "$start_path" -t "$current_pane" -P -F '#{pane_id}')"
stacked_panes_set_pane_option "$new_pane" @stacked-panes-id "$stack_id"
stacked_panes_set_pane_option "$new_pane" @stacked-panes-role real
stacked_panes_set_pane_option "$new_pane" @stacked-panes-active 1

stacked_panes_hide_real_as_placeholder "$current_pane" "$stack_id" >/dev/null

stacked_panes_reflow "$new_pane"
"$TMUX_BIN" select-pane -t "$new_pane" 2>/dev/null || true
