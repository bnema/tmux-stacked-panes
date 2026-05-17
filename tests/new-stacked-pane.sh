#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"
setup_test_server new-stacked-pane

initial_pane="$($TMUX_BIN display-message -p -t test:0 '#{pane_id}')"
TMUX_BIN="$TMUX_BIN" bash "$ROOT_DIR/scripts/new-stacked-pane.sh" "$initial_pane" /tmp

pane_count="$($TMUX_BIN display-message -p -t test:0 '#{window_panes}')"
[ "$pane_count" = "2" ] || { echo "expected 2 panes, got $pane_count" >&2; exit 1; }

active_pane="$(active_pane_id)"
[ "$active_pane" != "$initial_pane" ] || { echo "expected new pane to become active" >&2; exit 1; }

initial_stack="$($TMUX_BIN show-options -p -t "$initial_pane" -vq @stacked-panes-id)"
active_stack="$($TMUX_BIN show-options -p -t "$active_pane" -vq @stacked-panes-id)"
[ -n "$initial_stack" ] || { echo "expected initial pane to have stack id" >&2; exit 1; }
[ "$initial_stack" = "$active_stack" ] || { echo "expected matching stack ids, got $initial_stack and $active_stack" >&2; exit 1; }

active_flag="$($TMUX_BIN show-options -p -t "$active_pane" -vq @stacked-panes-active)"
[ "$active_flag" = "1" ] || { echo "expected active pane flag 1, got $active_flag" >&2; exit 1; }

initial_visible="$($TMUX_BIN list-panes -t test:0 -F '#{pane_id}' | grep -Fx "$initial_pane" || true)"
[ -z "$initial_visible" ] || { echo "expected initial real pane hidden" >&2; exit 1; }
placeholder="$(placeholder_pane_id)"
placeholder_height="$($TMUX_BIN display-message -p -t "$placeholder" '#{pane_height}')"
active_height="$($TMUX_BIN display-message -p -t "$active_pane" '#{pane_height}')"
[ "$placeholder_height" = "1" ] || { echo "expected placeholder collapsed to height 1, got $placeholder_height" >&2; exit 1; }
[ "$active_height" -gt 1 ] || { echo "expected active pane expanded, got height $active_height" >&2; exit 1; }
