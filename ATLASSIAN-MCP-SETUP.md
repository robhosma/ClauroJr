# Atlassian MCP Setup Guide

This guide walks through connecting Clauro Jr. to the Atlassian knowledge base
via the Official Atlassian Remote MCP server. Once complete, Jr. will have
read access to Confluence and Jira in every Claude Code session.

---

## How it works

```
[Session Start]
    → session-start.sh runs
    → Uses ATLASSIAN_REFRESH_TOKEN to request a fresh access token from Atlassian
    → Writes ATLASSIAN_OAUTH_TOKEN to the session environment
    → MCP server connects to https://mcp.atlassian.com/v1/sse with that token
    → Jr. can now read Confluence pages and Jira issues
```

---

## Step 1: Create an Atlassian OAuth 2.0 app

1. Go to https://developer.atlassian.com/console/myapps/
2. Click **Create** → **OAuth 2.0 integration**
3. Name it something like `Clauro Jr. MCP`
4. Under **Permissions**, add:
   - **Confluence API** → `read:confluence-content.all`, `read:confluence-space.summary`, `read:confluence-user`, `write:confluence-content`, `write:confluence-space`, `write:confluence-file`
   - **Jira platform REST API** → `read:jira-work`, `read:jira-user`, `write:jira-work`
5. Under **Authorization**, add a callback URL:
   - `https://localhost:8080/callback` (for the one-time auth flow below)
6. Note down:
   - **Client ID**
   - **Client Secret**

---

## Step 2: Do the initial OAuth authorization (one-time)

This is a one-time step to get your refresh token. Run this script locally:

```bash
# Fill in your values
CLIENT_ID="your-client-id-here"
CLIENT_SECRET="your-client-secret-here"
REDIRECT_URI="https://localhost:8080/callback"

SCOPES="read:confluence-content.all read:confluence-space.summary read:confluence-user write:confluence-content write:confluence-space write:confluence-file read:jira-work read:jira-user write:jira-work offline_access"

# Encode scopes for URL
ENCODED_SCOPES=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SCOPES'))")

# Open this URL in your browser:
echo "https://auth.atlassian.com/authorize?audience=api.atlassian.com&client_id=${CLIENT_ID}&scope=${ENCODED_SCOPES}&redirect_uri=${REDIRECT_URI}&state=clauro-jr&response_type=code&prompt=consent"
```

After authorizing in the browser, Atlassian redirects to your callback URL with
a `code` parameter. Extract that code and exchange it for tokens:

```bash
# Replace YOUR_CODE with the value from the redirect URL's ?code= parameter
CODE="YOUR_CODE"

curl -X POST "https://auth.atlassian.com/oauth/token" \
  -H "Content-Type: application/json" \
  -d "{
    \"grant_type\":    \"authorization_code\",
    \"client_id\":     \"${CLIENT_ID}\",
    \"client_secret\": \"${CLIENT_SECRET}\",
    \"code\":          \"${CODE}\",
    \"redirect_uri\":  \"${REDIRECT_URI}\"
  }"
```

The response JSON contains:
- `access_token` — short-lived (1 hour), used to call the API
- `refresh_token` — long-lived, used to get new access tokens → **save this**

---

## Step 3: Set the environment variables in Claude Code remote

In the Claude Code web interface, set these secrets for this repository:

| Variable | Value |
|----------|-------|
| `ATLASSIAN_CLIENT_ID` | Client ID from Step 1 |
| `ATLASSIAN_CLIENT_SECRET` | Client Secret from Step 1 |
| `ATLASSIAN_REFRESH_TOKEN` | Refresh token from Step 2 |

These are picked up by `.claude/hooks/session-start.sh` at the start of each
session. The hook exchanges the refresh token for a fresh access token and
writes it into the session as `ATLASSIAN_OAUTH_TOKEN`.

---

## Step 4: Verify it's working

Start a new Claude Code session in this repo. Jr. should greet you with:

```
Atlassian MCP: OAuth token refreshed successfully.
```

Then try asking Jr. something like:
- "What Confluence spaces do we have access to?"
- "Search Confluence for [topic from our knowledge base]"
- "List recent Jira issues"

---

## Troubleshooting

**"missing required env vars"** — The secrets weren't set or weren't picked up.
Check your Claude Code remote environment configuration.

**"failed to refresh token"** — The refresh token may have expired or been
revoked. Redo Step 2 to get a new one.

**"access_token not in response"** — Check that `offline_access` scope was
included in Step 1. Without it, Atlassian won't issue refresh tokens.

---

## What Jr. can do once connected

Via the Atlassian MCP, Jr. has access to:

- **Confluence**: search pages, read content, browse spaces, create/update pages and spaces, manage attachments
- **Jira**: search issues, read tickets, browse projects, create/update issues

This mirrors what Sr. accesses through the claude.ai Projects native connector,
but through the MCP protocol from the Claude Code side.
