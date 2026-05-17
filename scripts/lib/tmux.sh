#!/usr/bin/env bash
# Strict mode is intentionally not enabled here because this file is sourced by
# other scripts and must not silently change the caller's shell options.
# tmux-stacked-panes — shared tmux helpers

_stacked_panes_return_or_exit() {
  local code="${1:-1}"
  if (return 0 2>/dev/null); then
    return "$code"
  fi
  exit "$code"
}

stacked_panes_require_command() {
  local name="$1"
  local resolved=""
  resolved="$(command -v "$name" 2>/dev/null || true)"
  if [ -z "$resolved" ]; then
    echo "tmux-stacked-panes: required command not found: $name" >&2
    return 1
  fi
  printf '%s' "$resolved"
}

if [ -z "${TMUX_BIN:-}" ]; then
  TMUX_BIN="$(stacked_panes_require_command tmux)" || _stacked_panes_return_or_exit 1
fi

STACKED_PANES_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

stacked_panes_get_option() {
  local option="$1" default_value="${2:-}"
  local value
  value="$("$TMUX_BIN" show-options -gvq "$option" 2>/dev/null)" || true
  if [ -n "$value" ]; then
    printf '%s' "$value"
  else
    printf '%s' "$default_value"
  fi
}

stacked_panes_set_option() {
  local option="$1" value="$2"
  "$TMUX_BIN" set-option -gq "$option" "$value"
}

stacked_panes_get_pane_option() {
  local pane_id="$1" option="$2" default_value="${3:-}"
  local value=""
  [ -n "$pane_id" ] || {
    printf '%s' "$default_value"
    return 0
  }
  value="$("$TMUX_BIN" show-options -p -t "$pane_id" -vq "$option" 2>/dev/null)" || true
  if [ -n "$value" ]; then
    printf '%s' "$value"
  else
    printf '%s' "$default_value"
  fi
}

stacked_panes_set_pane_option() {
  local pane_id="$1" option="$2" value="$3"
  [ -n "$pane_id" ] || return 1
  "$TMUX_BIN" set-option -p -q -t "$pane_id" "$option" "$value"
}

stacked_panes_unset_pane_option() {
  local pane_id="$1" option="$2"
  [ -n "$pane_id" ] || return 1
  "$TMUX_BIN" set-option -p -u -q -t "$pane_id" "$option" >/dev/null 2>&1 || true
}

stacked_panes_allocate_stack_id() {
  local raw_id next_id
  raw_id="$(stacked_panes_get_option @stacked-panes-next-id 1)"
  case "$raw_id" in
    ''|*[!0-9]*) raw_id=1 ;;
  esac
  next_id=$((raw_id + 1))
  stacked_panes_set_option @stacked-panes-next-id "$next_id"
  printf '%s' "$raw_id"
}

stacked_panes_hold_session() {
  stacked_panes_get_option @stacked-panes-hold-session '__tmux_stacked_panes'
}

stacked_panes_reflow() {
  TMUX_BIN="$TMUX_BIN" bash "$STACKED_PANES_SCRIPTS_DIR/reflow-stack.sh" "$@"
}

stacked_panes_placeholder_command() {
  local label="$1" quoted_label
  printf -v quoted_label '%q' "$label"
  printf 'printf "\\033[2J\\033[H%%s" %s; exec sleep 100000000' "$quoted_label"
}

stacked_panes_create_placeholder_holder() {
  local label="$1" width="${2:-80}" height="${3:-24}" session command pane_id
  session="$(stacked_panes_hold_session)"
  command="$(stacked_panes_placeholder_command "$label")"
  if "$TMUX_BIN" has-session -t "=$session" 2>/dev/null; then
    pane_id="$("$TMUX_BIN" new-window -d -P -F '#{pane_id}' -t "$session:" "$command")"
  else
    pane_id="$("$TMUX_BIN" new-session -d -P -F '#{pane_id}' -s "$session" -x "$width" -y "$height" "$command")"
    "$TMUX_BIN" set-option -q -t "$session" destroy-unattached off 2>/dev/null || true
  fi
  printf '%s' "$pane_id"
}

stacked_panes_relative_path() {
  local path="$1"
  [ -n "$path" ] || {
    printf '~'
    return 0
  }
  case "$path" in
    "$HOME") printf '~' ;;
    "$HOME"/*) printf '~/%s' "${path#"$HOME"/}" ;;
    *) printf '%s' "$path" ;;
  esac
}

stacked_panes_placeholder_label_for_real() {
  local real_pane="$1" stack_id="$2" pane_index pane_path label_path
  pane_index="$("$TMUX_BIN" display-message -p -t "$real_pane" '#{pane_index}' 2>/dev/null || true)"
  pane_path="$("$TMUX_BIN" display-message -p -t "$real_pane" '#{pane_current_path}' 2>/dev/null || true)"
  label_path="$(stacked_panes_relative_path "$pane_path")"
  printf '○ stack %s:%s %s' "$stack_id" "$pane_index" "$label_path"
}

stacked_panes_hide_real_as_placeholder() {
  local real_pane="$1" stack_id="$2" label width height placeholder
  [ -n "$real_pane" ] || return 1
  [ -n "$stack_id" ] || return 1
  label="$(stacked_panes_placeholder_label_for_real "$real_pane" "$stack_id")"
  width="$("$TMUX_BIN" display-message -p -t "$real_pane" '#{pane_width}' 2>/dev/null || printf '80')"
  height="$("$TMUX_BIN" display-message -p -t "$real_pane" '#{pane_height}' 2>/dev/null || printf '24')"
  placeholder="$(stacked_panes_create_placeholder_holder "$label" "$width" "$height")"
  stacked_panes_set_pane_option "$placeholder" @stacked-panes-id "$stack_id"
  stacked_panes_set_pane_option "$placeholder" @stacked-panes-role placeholder
  stacked_panes_set_pane_option "$placeholder" @stacked-panes-real "$real_pane"
  stacked_panes_set_pane_option "$real_pane" @stacked-panes-id "$stack_id"
  stacked_panes_set_pane_option "$real_pane" @stacked-panes-role real
  stacked_panes_unset_pane_option "$real_pane" @stacked-panes-active
  "$TMUX_BIN" swap-pane -d -s "$real_pane" -t "$placeholder"
  printf '%s' "$placeholder"
}
