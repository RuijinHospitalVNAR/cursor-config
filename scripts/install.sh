#!/bin/bash
# cursor-config install script for macOS/Linux
# Usage: ./install.sh [--git-repo-path /path/to/repo] [--python-path python3]

set -e

CURSOR_HOME="${HOME}/.cursor"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PYTHON_PATH="python3"
GIT_REPO_PATH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --git-repo-path)
      GIT_REPO_PATH="$2"
      shift 2
      ;;
    --python-path)
      PYTHON_PATH="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

mkdir -p "$CURSOR_HOME/rules"
mkdir -p "$CURSOR_HOME/skills-cursor"

# Copy rules
cp -r "$REPO_ROOT/rules/"* "$CURSOR_HOME/rules/"
echo "Rules installed to $CURSOR_HOME/rules"

# Copy skills
for dir in "$REPO_ROOT/skills/"*/; do
  name=$(basename "$dir")
  rm -rf "$CURSOR_HOME/skills-cursor/$name"
  cp -r "$dir" "$CURSOR_HOME/skills-cursor/"
done
echo "Skills installed to $CURSOR_HOME/skills-cursor"

# Process mcp.json
USER_HOME_ESC=$(echo "$HOME" | sed 's/[\/&]/\\&/g')
MCP_CONTENT=$(cat "$REPO_ROOT/mcp/mcp.json")
MCP_CONTENT=$(echo "$MCP_CONTENT" | sed "s|{{USER_HOME}}|$HOME|g")
MCP_CONTENT=$(echo "$MCP_CONTENT" | sed "s|{{PYTHON_PATH}}|$PYTHON_PATH|g")

if [ -n "$GIT_REPO_PATH" ]; then
  GIT_ESC=$(echo "$GIT_REPO_PATH" | sed 's/[\/&]/\\&/g')
  MCP_CONTENT=$(echo "$MCP_CONTENT" | sed "s|{{GIT_REPO_PATH}}|$GIT_REPO_PATH|g")
else
  echo "WARNING: --git-repo-path not set. Edit $CURSOR_HOME/mcp.json and replace {{GIT_REPO_PATH}}."
fi

echo "$MCP_CONTENT" > "$CURSOR_HOME/mcp.json"
echo "MCP config installed to $CURSOR_HOME/mcp.json"

echo ""
echo "Done! Set FIRECRAWL_API_KEY env var if you use firecrawl-mcp."
echo "Restart Cursor to apply changes."
