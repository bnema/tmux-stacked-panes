# tmux-stacked-panes

A tmux plugin for stacked panes with clean collapsed rows.

It keeps the active pane full size. Inactive panes are preserved in a hidden tmux session and shown as one-line placeholders, so you see useful labels instead of shell prompts.

GitHub: <https://github.com/bnema/tmux-stacked-panes>

## Install with TPM

Add this before the final TPM `run` line in your tmux config:

```tmux
set -g @plugin 'bnema/tmux-stacked-panes'
```

Reload tmux, then install plugins:

```text
prefix + I
```

## Usage

Create or add a stacked pane:

```text
prefix + S
```

Move with your normal tmux pane navigation. When focus lands on a placeholder, the real pane is swapped back into view.

## Options

```tmux
# Key for creating or adding a stacked pane.
set -g @stacked-panes-key S

# Hidden session used to preserve inactive panes.
set -g @stacked-panes-hold-session '__tmux_stacked_panes'
```

## How it works

The plugin stores stack state in tmux pane options:

- `@stacked-panes-id`
- `@stacked-panes-active`
- `@stacked-panes-role`
- `@stacked-panes-real`

Inactive panes live in the hidden session and are represented by placeholder panes such as:

```text
○ stack 1:0 ~/projects/app
```

The plugin uses an `after-select-pane` hook to activate placeholders without replacing your existing navigation bindings.

## Current limits

- Vertical stacks only.
- No automatic stacking on resize.
- No detach command yet.
- Manual `break-pane`, `join-pane`, or unusual layout changes can confuse a stack.

## Development

```sh
make test
```

## License

MIT
