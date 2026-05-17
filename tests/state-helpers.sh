#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"
setup_test_server state-helpers no

# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/lib/tmux.sh"

pane_id="$($TMUX_BIN display-message -p '#{pane_id}')"

first="$(stacked_panes_allocate_stack_id)"
second="$(stacked_panes_allocate_stack_id)"
[ "$first" = "1" ] || { echo "expected first stack id 1, got $first" >&2; exit 1; }
[ "$second" = "2" ] || { echo "expected second stack id 2, got $second" >&2; exit 1; }

stacked_panes_set_pane_option "$pane_id" @stacked-panes-id "$first"
value="$(stacked_panes_get_pane_option "$pane_id" @stacked-panes-id '')"
[ "$value" = "$first" ] || { echo "expected pane option $first, got $value" >&2; exit 1; }

stacked_panes_unset_pane_option "$pane_id" @stacked-panes-id
value="$(stacked_panes_get_pane_option "$pane_id" @stacked-panes-id fallback)"
[ "$value" = "fallback" ] || { echo "expected fallback after unset, got $value" >&2; exit 1; }
