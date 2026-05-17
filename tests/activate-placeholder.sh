#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"
setup_test_server activate-placeholder

first="$($TMUX_BIN display-message -p '#{pane_id}')"
TMUX_BIN="$TMUX_BIN" bash "$ROOT_DIR/scripts/new-stacked-pane.sh" "$first" /tmp
second="$(active_pane_id)"
placeholder="$(inactive_pane_id)"

$TMUX_BIN select-pane -t "$placeholder"
TMUX_BIN="$TMUX_BIN" bash "$ROOT_DIR/scripts/on-select-pane.sh" "$placeholder"
sleep 0.2

selected="$(active_pane_id)"
[ "$selected" = "$first" ] || { echo "expected hidden real $first activated, got selected $selected" >&2; exit 1; }

second_visible="$($TMUX_BIN list-panes -t test:0 -F '#{pane_id}' | grep -Fx "$second" || true)"
[ -z "$second_visible" ] || { echo "expected previous active real $second hidden" >&2; exit 1; }

new_placeholder="$(placeholder_pane_id)"
backing="$($TMUX_BIN show-options -p -t "$new_placeholder" -vq @stacked-panes-real)"
[ "$backing" = "$second" ] || { echo "expected new placeholder to back $second, got $backing" >&2; exit 1; }

selected_height="$($TMUX_BIN display-message -p -t "$selected" '#{pane_height}')"
placeholder_height="$($TMUX_BIN display-message -p -t "$new_placeholder" '#{pane_height}')"
[ "$selected_height" -gt 1 ] || { echo "expected selected real expanded, got $selected_height" >&2; exit 1; }
[ "$placeholder_height" = "1" ] || { echo "expected placeholder collapsed, got $placeholder_height" >&2; exit 1; }
