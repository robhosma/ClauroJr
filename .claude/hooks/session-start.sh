#!/bin/bash
# Atlassian MCP OAuth Token Refresh
# Runs at the start of each Claude Code session (remote only)
# Refreshes the Atlassian OAuth access token using the stored refresh token
#
# Required environment variables (set in Claude Code remote secrets):
#   ATLASSIAN_CLIENT_ID      - OAuth app Client ID from developer.atlassian.com
#   ATLASSIAN_CLIENT_SECRET  - OAuth app Client Secret
#   ATLASSIAN_REFRESH_TOKEN  - Refresh token from initial OAuth authorization
#
# See ATLASSIAN-MCP-SETUP.md for how to obtain these.

set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "Atlassian MCP: refreshing OAuth token..."

# Validate required env vars are present
MISSING=()
[ -z "${ATLASSIAN_CLIENT_ID:-}" ]     && MISSING+=("ATLASSIAN_CLIENT_ID")
[ -z "${ATLASSIAN_CLIENT_SECRET:-}" ] && MISSING+=("ATLASSIAN_CLIENT_SECRET")
[ -z "${ATLASSIAN_REFRESH_TOKEN:-}" ] && MISSING+=("ATLASSIAN_REFRESH_TOKEN")

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "Atlassian MCP: missing required env vars: ${MISSING[*]}"
  echo "See ATLASSIAN-MCP-SETUP.md for setup instructions."
  exit 0
fi

# Request a fresh access token using the stored refresh token
RESPONSE=$(curl -s -X POST "https://auth.atlassian.com/oauth/token" \
  -H "Content-Type: application/json" \
  -d "{
    \"grant_type\":    \"refresh_token\",
    \"client_id\":     \"${ATLASSIAN_CLIENT_ID}\",
    \"client_secret\": \"${ATLASSIAN_CLIENT_SECRET}\",
    \"refresh_token\": \"${ATLASSIAN_REFRESH_TOKEN}\"
  }")

# Extract access token (and optionally the new refresh token)
ACCESS_TOKEN=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'access_token' in data:
    print(data['access_token'])
else:
    print('')
    print('Error:', data.get('error_description', data.get('error', 'unknown')), file=sys.stderr)
" 2>/tmp/atlassian-mcp-error || echo "")

if [ -z "$ACCESS_TOKEN" ]; then
  echo "Atlassian MCP: failed to refresh token."
  [ -f /tmp/atlassian-mcp-error ] && cat /tmp/atlassian-mcp-error
  echo "Check your credentials in the remote environment secrets."
  exit 0
fi

# Write to the Claude session environment file so it persists for this session
echo "export ATLASSIAN_OAUTH_TOKEN=\"${ACCESS_TOKEN}\"" >> "$CLAUDE_ENV_FILE"

echo "Atlassian MCP: OAuth token refreshed successfully."
