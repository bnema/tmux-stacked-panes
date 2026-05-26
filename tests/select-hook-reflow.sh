#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"
setup_test_server select-hook-reflow

first_pane="$($TMUX_BIN display-message -p -t test:0 '#{pane_id}')"
TMUX_BIN="$TMUX_BIN" bash "$ROOT_DIR/scripts/new-stacked-pane.sh" "$first_pane" /tmp
second_pane="$(active_pane_id)"
placeholder="$(placeholder_pane_id)"

$TMUX_BIN select-pane -t "$placeholder"

wait_timeout_seconds=2
wait_interval_seconds=0.05
wait_deadline=$((SECONDS + wait_timeout_seconds))
selected=""
while [ "$SECONDS" -le "$wait_deadline" ]; do
  selected="$(active_pane_id)"
  [ "$selected" = "$first_pane" ] && break
  sleep "$wait_interval_seconds"
done
[ "$selected" = "$first_pane" ] || { echo "expected first pane selected, got $selected" >&2; exit 1; }

first_active="$($TMUX_BIN show-options -p -t "$first_pane" -vq @stacked-panes-active)"
if ! "$TMUX_BIN" display-message -p -t "$second_pane" '#{pane_id}' >/dev/null 2>&1; then
  echo "expected second_pane target to exist before TMUX_BIN show-options query: $second_pane" >&2
  exit 1
fi
second_active="$($TMUX_BIN show-options -p -t "$second_pane" -vq @stacked-panes-active 2>/dev/null || true)"
[ "$first_active" = "1" ] || { echo "expected first pane active after select, got $first_active" >&2; exit 1; }
[ -z "$second_active" ] || { echo "expected second pane inactive after select, got $second_active" >&2; exit 1; }

new_placeholder="$(placeholder_pane_id)"
first_height="$($TMUX_BIN display-message -p -t "$first_pane" '#{pane_height}')"
placeholder_height="$($TMUX_BIN display-message -p -t "$new_placeholder" '#{pane_height}')"
[ "$first_height" -gt 1 ] || { echo "expected first pane expanded, got $first_height" >&2; exit 1; }
[ "$placeholder_height" = "1" ] || { echo "expected placeholder collapsed, got $placeholder_height" >&2; exit 1; }
