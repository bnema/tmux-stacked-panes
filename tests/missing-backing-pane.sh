#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"
setup_test_server missing-backing-pane

first="$($TMUX_BIN display-message -p -t test:0 '#{pane_id}')"
TMUX_BIN="$TMUX_BIN" bash "$ROOT_DIR/scripts/new-stacked-pane.sh" "$first" /tmp
placeholder="$(placeholder_pane_id)"
backing="$($TMUX_BIN show-options -p -t "$placeholder" -vq @stacked-panes-real)"

$TMUX_BIN kill-pane -t "$backing"
TMUX_BIN="$TMUX_BIN" bash "$ROOT_DIR/scripts/on-select-pane.sh" "$placeholder"

still_visible="$($TMUX_BIN list-panes -t test:0 -F '#{pane_id}' | grep -Fx "$placeholder" || true)"
[ "$still_visible" = "$placeholder" ] || { echo "expected placeholder preserved when backing pane is missing" >&2; exit 1; }
