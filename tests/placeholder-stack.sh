#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"
setup_test_server placeholder-stack

first="$($TMUX_BIN display-message -p '#{pane_id}')"
TMUX_BIN="$TMUX_BIN" bash "$ROOT_DIR/scripts/new-stacked-pane.sh" "$first" /tmp
sleep 0.5
active="$(active_pane_id)"
placeholder="$(inactive_pane_id)"

role="$($TMUX_BIN show-options -p -t "$placeholder" -vq @stacked-panes-role)"
real="$($TMUX_BIN show-options -p -t "$placeholder" -vq @stacked-panes-real)"
active_role="$($TMUX_BIN show-options -p -t "$active" -vq @stacked-panes-role)"
[ "$role" = "placeholder" ] || { echo "expected placeholder role, got $role" >&2; exit 1; }
[ "$real" = "$first" ] || { echo "expected placeholder backed by $first, got $real" >&2; exit 1; }
[ "$active_role" = "real" ] || { echo "expected active role real, got $active_role" >&2; exit 1; }

first_visible="$($TMUX_BIN list-panes -t test:0 -F '#{pane_id}' | grep -Fx "$first" || true)"
[ -z "$first_visible" ] || { echo "expected original real pane hidden, but it is still visible" >&2; exit 1; }

placeholder_line="$($TMUX_BIN capture-pane -p -t "$placeholder" -S 0 -E 0 | head -1)"
printf '%s\n' "$placeholder_line" | grep -F '○ stack' >/dev/null || {
  echo "expected clean placeholder label, got: $placeholder_line" >&2
  exit 1
}
if printf '%s\n' "$placeholder_line" | grep -F ' fish' >/dev/null; then
  echo "placeholder label should show path instead of shell command: $placeholder_line" >&2
  exit 1
fi
if printf '%s\n' "$placeholder_line" | grep -F '❯' >/dev/null; then
  echo "placeholder label leaked shell prompt: $placeholder_line" >&2
  exit 1
fi
