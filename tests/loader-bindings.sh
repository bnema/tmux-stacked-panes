#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"
setup_test_server loader-bindings

key="$($TMUX_BIN show-options -gvq @stacked-panes-key)"
[ "$key" = "S" ] || {
  echo "expected @stacked-panes-key to default to S, got '$key'" >&2
  exit 1
}

binding="$($TMUX_BIN list-keys -T prefix S 2>/dev/null || true)"
printf '%s\n' "$binding" | grep -F "new-stacked-pane.sh" >/dev/null || {
  echo "expected prefix S binding to run new-stacked-pane.sh, got: $binding" >&2
  exit 1
}

hook="$($TMUX_BIN show-hooks -g after-select-pane 2>/dev/null || true)"
printf '%s\n' "$hook" | grep -F "on-select-pane.sh" >/dev/null || {
  echo "expected after-select-pane hook to run on-select-pane.sh, got: $hook" >&2
  exit 1
}
