#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/tmux.sh"

selected_pane="${1:-}"
[ -n "$selected_pane" ] || selected_pane="$("$TMUX_BIN" display-message -p '#{pane_id}')"

busy="$(stacked_panes_get_option @stacked-panes-busy '')"
[ -z "$busy" ] || exit 0

stack_id="$(stacked_panes_get_pane_option "$selected_pane" @stacked-panes-id '')"
[ -n "$stack_id" ] || exit 0
selected_window="$("$TMUX_BIN" display-message -p -t "$selected_pane" '#{window_id}')"
role="$(stacked_panes_get_pane_option "$selected_pane" @stacked-panes-role real)"

if [ "$role" != "placeholder" ]; then
  stacked_panes_reflow "$selected_pane"
  exit 0
fi

target_real="$(stacked_panes_get_pane_option "$selected_pane" @stacked-panes-real '')"
[ -n "$target_real" ] || exit 0
if ! "$TMUX_BIN" display-message -p -t "$target_real" '#{pane_id}' >/dev/null 2>&1; then
  "$TMUX_BIN" display-message "tmux-stacked-panes: backing pane for placeholder is gone" 2>/dev/null || true
  exit 0
fi

stacked_panes_set_option @stacked-panes-busy 1
cleanup_busy() {
  "$TMUX_BIN" set-option -gqu @stacked-panes-busy >/dev/null 2>&1 || true
}
trap cleanup_busy EXIT

active_real=""
while IFS=$'\t' read -r pane_id pane_stack_id pane_role pane_active; do
  [ "$pane_stack_id" = "$stack_id" ] || continue
  [ "$pane_id" = "$selected_pane" ] && continue
  [ "$pane_role" = "real" ] || continue
  if [ "$pane_active" = "1" ]; then
    active_real="$pane_id"
    break
  fi
done < <("$TMUX_BIN" list-panes -t "$selected_window" -F '#{pane_id}	#{@stacked-panes-id}	#{@stacked-panes-role}	#{@stacked-panes-active}')
if [ -z "$active_real" ]; then
  while IFS=$'\t' read -r pane_id pane_stack_id pane_role; do
    [ "$pane_stack_id" = "$stack_id" ] || continue
    [ "$pane_id" = "$selected_pane" ] && continue
    [ "$pane_role" = "real" ] || continue
    active_real="$pane_id"
    break
  done < <("$TMUX_BIN" list-panes -t "$selected_window" -F '#{pane_id}	#{@stacked-panes-id}	#{@stacked-panes-role}')
fi

stacked_panes_set_pane_option "$target_real" @stacked-panes-id "$stack_id"
stacked_panes_set_pane_option "$target_real" @stacked-panes-role real
stacked_panes_set_pane_option "$target_real" @stacked-panes-active 1
if ! "$TMUX_BIN" swap-pane -d -s "$target_real" -t "$selected_pane" 2>/dev/null; then
  "$TMUX_BIN" display-message "tmux-stacked-panes: failed to activate placeholder" 2>/dev/null || true
  exit 0
fi
"$TMUX_BIN" kill-pane -t "$selected_pane" 2>/dev/null || true

if [ -n "$active_real" ] && [ "$active_real" != "$target_real" ]; then
  stacked_panes_hide_real_as_placeholder "$active_real" "$stack_id" >/dev/null
fi

stacked_panes_reflow "$target_real"
"$TMUX_BIN" select-pane -t "$target_real" 2>/dev/null || true
