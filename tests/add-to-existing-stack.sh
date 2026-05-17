#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"
setup_test_server add-to-existing-stack

first="$($TMUX_BIN display-message -p -t test:0 '#{pane_id}')"
TMUX_BIN="$TMUX_BIN" bash "$ROOT_DIR/scripts/new-stacked-pane.sh" "$first" /tmp
second="$(active_pane_id)"
TMUX_BIN="$TMUX_BIN" bash "$ROOT_DIR/scripts/new-stacked-pane.sh" "$second" /tmp
third="$(active_pane_id)"

pane_count="$($TMUX_BIN display-message -p -t test:0 '#{window_panes}')"
[ "$pane_count" = "3" ] || { echo "expected 3 panes, got $pane_count" >&2; exit 1; }

stack="$($TMUX_BIN show-options -p -t "$first" -vq @stacked-panes-id)"
for pane in "$second" "$third"; do
  got="$($TMUX_BIN show-options -p -t "$pane" -vq @stacked-panes-id)"
  [ "$got" = "$stack" ] || { echo "expected $pane stack $stack, got $got" >&2; exit 1; }
done

for pane in "$first" "$second"; do
  visible="$($TMUX_BIN list-panes -t test:0 -F '#{pane_id}' | grep -Fx "$pane" || true)"
  [ -z "$visible" ] || { echo "expected real pane $pane hidden" >&2; exit 1; }
done
placeholder_count="$($TMUX_BIN list-panes -t test:0 -F '#{@stacked-panes-role}' | grep -c '^placeholder$')"
[ "$placeholder_count" = "2" ] || { echo "expected 2 placeholders, got $placeholder_count" >&2; exit 1; }
third_height="$($TMUX_BIN display-message -p -t "$third" '#{pane_height}')"
[ "$third_height" -gt 1 ] || { echo "expected third pane expanded, got $third_height" >&2; exit 1; }
