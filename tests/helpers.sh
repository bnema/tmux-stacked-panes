#!/usr/bin/env bash
# Shared helpers for tmux-stacked-panes integration tests.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
REAL_TMUX_BIN="${TMUX_BIN:-tmux}"

setup_test_server() {
  local name="$1" load_plugin="${2:-yes}"
  SOCKET="tmux-stacked-panes-${name}-$$"
  WRAPPER_DIR="$(mktemp -d)"
  WRAPPED_TMUX_BIN="$WRAPPER_DIR/tmux-test"
  cat >"$WRAPPED_TMUX_BIN" <<EOF
#!/usr/bin/env bash
exec "$REAL_TMUX_BIN" -L "$SOCKET" "\$@"
EOF
  chmod +x "$WRAPPED_TMUX_BIN"
  trap cleanup_test_server EXIT
  "$REAL_TMUX_BIN" -L "$SOCKET" -f /dev/null new-session -d -s test -x 120 -y 40
  TMUX_BIN="$WRAPPED_TMUX_BIN"
  if [ "$load_plugin" = "yes" ]; then
    TMUX_BIN="$WRAPPED_TMUX_BIN" bash "$ROOT_DIR/tmux-stacked-panes.tmux"
  fi
}

cleanup_test_server() {
  "$REAL_TMUX_BIN" -L "${SOCKET:-}" kill-server >/dev/null 2>&1 || true
  rm -rf "${WRAPPER_DIR:-}"
}

active_pane_id() {
  local target="${1:-test:0}"
  "$TMUX_BIN" list-panes -t "$target" -F '#{pane_id} #{pane_active}' | awk '$2 == 1 { print $1; exit }'
}

inactive_pane_id() {
  local target="${1:-test:0}"
  "$TMUX_BIN" list-panes -t "$target" -F '#{pane_id} #{pane_active}' | awk '$2 == 0 { print $1; exit }'
}

placeholder_pane_id() {
  local target="${1:-test:0}"
  "$TMUX_BIN" list-panes -t "$target" -F '#{pane_id} #{@stacked-panes-role}' | awk '$2 == "placeholder" { print $1; exit }'
}
