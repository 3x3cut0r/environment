#!/usr/bin/env bash

# Exit if tmux not installed
if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is required to run this script." >&2
  exit 1
fi

SESSION_NAME="tmux example"

# Start new session detached
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  tmux new-session -d -s "$SESSION_NAME" -n shell1
else
  echo "Session '$SESSION_NAME' already exists." >&2
  exit 1
fi

# Configure shell1 window: split horizontally into two panes
# Initial window created as shell1 (pane 0)
tmux split-window -h -t "$SESSION_NAME:0"

tmux select-layout -t "$SESSION_NAME:0" even-horizontal

# Create shell2 window and split vertically into two panes
tmux new-window -t "$SESSION_NAME" -n shell2
# tmux split-window splits current window horizontally by default, so use -v for vertical split
tmux split-window -v -t "$SESSION_NAME:1"

tmux select-layout -t "$SESSION_NAME:1" even-vertical

# Create shell3 window without splits
tmux new-window -t "$SESSION_NAME" -n shell3

# Select first window when attaching
tmux select-window -t "$SESSION_NAME:0"

# Attach to the session
tmux attach-session -t "$SESSION_NAME"
