#!/usr/bin/env bash
set -euo pipefail

DIRNAME_BIN="$(command -v dirname 2>/dev/null || true)"
PWD_BIN="$(command -v pwd 2>/dev/null || true)"
TMUX_BIN="${TMUX_BIN:-$(command -v tmux 2>/dev/null || true)}"
GREP_BIN="$(command -v grep 2>/dev/null || true)"
[ -n "$DIRNAME_BIN" ] || { echo 'tmux-stacked-panes: dirname not found' >&2; exit 1; }
[ -n "$PWD_BIN" ] || { echo 'tmux-stacked-panes: pwd not found' >&2; exit 1; }
[ -n "$TMUX_BIN" ] || { echo 'tmux-stacked-panes: tmux not found' >&2; exit 1; }
[ -n "$GREP_BIN" ] || { echo 'tmux-stacked-panes: grep not found' >&2; exit 1; }

PLUGIN_DIR="$(cd "$($DIRNAME_BIN "${BASH_SOURCE[0]}")" && "$PWD_BIN")" || exit 1
SCRIPTS_DIR="$PLUGIN_DIR/scripts"
NEW_STACKED_PANE_SCRIPT="$SCRIPTS_DIR/new-stacked-pane.sh"
ON_SELECT_PANE_SCRIPT="$SCRIPTS_DIR/on-select-pane.sh"
# High hook index avoids clobbering ordinary user hooks and matches the style of
# the author's other tmux plugins.
HOOK_INDEX=9705

set_default() {
  local option="$1" default_value="$2"
  if [ -z "$("$TMUX_BIN" show-options -gvq "$option" 2>/dev/null)" ]; then
    "$TMUX_BIN" set-option -gq "$option" "$default_value"
  fi
}

binding_belongs_to_plugin() {
  local key="$1" binding
  [ -n "$key" ] || return 1
  binding="$("$TMUX_BIN" list-keys -T prefix "$key" 2>/dev/null || true)"
  [ -n "$binding" ] && printf '%s\n' "$binding" | "$GREP_BIN" -Fq "$NEW_STACKED_PANE_SCRIPT"
}

unbind_plugin_binding() {
  local key="$1"
  [ -n "$key" ] || return 0
  if binding_belongs_to_plugin "$key"; then
    "$TMUX_BIN" unbind-key -T prefix "$key" 2>/dev/null || true
  fi
}

main() {
  set_default @stacked-panes-key S
  set_default @stacked-panes-next-id 1

  local stacked_key previous_key quoted_new_script quoted_on_select_script
  stacked_key="$("$TMUX_BIN" show-options -gvq @stacked-panes-key)"
  previous_key="$("$TMUX_BIN" show-options -gvq @stacked-panes-bound-key 2>/dev/null || true)"
  printf -v quoted_new_script '%q' "$NEW_STACKED_PANE_SCRIPT"
  printf -v quoted_on_select_script '%q' "$ON_SELECT_PANE_SCRIPT"

  if [ -n "$previous_key" ] && [ "$previous_key" != "$stacked_key" ]; then
    unbind_plugin_binding "$previous_key"
  fi

  "$TMUX_BIN" bind-key -T prefix "$stacked_key" \
    run-shell "$quoted_new_script #{q:pane_id} #{q:pane_current_path}"
  "$TMUX_BIN" set-option -gq @stacked-panes-bound-key "$stacked_key"

  "$TMUX_BIN" set-hook -g "after-select-pane[$HOOK_INDEX]" \
    "run-shell -b \"$quoted_on_select_script #{q:pane_id}\""
}

main "$@"
