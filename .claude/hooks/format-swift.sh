#!/usr/bin/env bash
# PostToolUse hook: format a Swift file right after Claude edits or writes it.
# Never fails the tool call – formatting is best-effort.
set -u

FILE_PATH=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)

case "$FILE_PATH" in
  *.swift) ;;
  *) exit 0 ;;
esac

[ -f "$FILE_PATH" ] || exit 0

if command -v swiftformat >/dev/null 2>&1; then
  swiftformat --quiet --config "${CLAUDE_PROJECT_DIR:-.}/.swiftformat" "$FILE_PATH" >/dev/null 2>&1 || true
fi

exit 0
