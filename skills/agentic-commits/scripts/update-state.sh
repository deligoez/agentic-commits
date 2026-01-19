#!/bin/bash
# Update agentic commit state after a commit

set -e

STATE_FILE=".git/agentic-state.json"
COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "none")
COMMIT_MSG=$(git log -1 --format="%s" 2>/dev/null || echo "")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

# Extract scope from commit message
SCOPE=$(echo "$COMMIT_MSG" | grep -oE '\([^)]+\)' | head -1 | tr -d '()' || echo "general")

# Detect if WIP
if echo "$COMMIT_MSG" | grep -qiE '^wip'; then
    STATUS="in_progress"
else
    STATUS="complete"
fi

# Read existing state or create new
if [ -f "$STATE_FILE" ]; then
    EXISTING_STATE=$(cat "$STATE_FILE")
    SESSION_COUNT=$(echo "$EXISTING_STATE" | jq '.session.commits_this_session // 0')
    SESSION_COUNT=$((SESSION_COUNT + 1))
    FEATURE_START=$(echo "$EXISTING_STATE" | jq -r '.current_feature.started_at // ""')

    # If scope changed, this might be a new feature
    PREV_SCOPE=$(echo "$EXISTING_STATE" | jq -r '.current_feature.scope // ""')
    if [ "$SCOPE" != "$PREV_SCOPE" ] && [ -n "$SCOPE" ]; then
        FEATURE_START="$COMMIT_HASH"
    fi
else
    SESSION_COUNT=1
    FEATURE_START="$COMMIT_HASH"
fi

# If feature start is empty, use current commit
if [ -z "$FEATURE_START" ]; then
    FEATURE_START="$COMMIT_HASH"
fi

# Create new state
cat > "$STATE_FILE" << EOF
{
  "last_commit": "$COMMIT_HASH",
  "last_examined": "$COMMIT_HASH",
  "branch": "$BRANCH",
  "current_feature": {
    "scope": "$SCOPE",
    "started_at": "$FEATURE_START",
    "status": "$STATUS",
    "last_commit_msg": "$COMMIT_MSG"
  },
  "session": {
    "started_at": "$TIMESTAMP",
    "commits_this_session": $SESSION_COUNT
  },
  "updated_at": "$TIMESTAMP"
}
EOF

echo "State updated: $STATE_FILE"
cat "$STATE_FILE"
