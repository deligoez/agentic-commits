#!/bin/bash
# Analyze git commit chain for patterns and feature boundaries

set -e

# Get recent commits with full message
echo "=== Recent Commits ==="
git log --oneline -20 2>/dev/null || echo "No commits yet"

echo ""
echo "=== Commit Details (last 5) ==="
git log -5 --format="--- %h ---%n%s%n%b" 2>/dev/null || echo "No commits yet"

echo ""
echo "=== Current State ==="
if [ -f .git/agentic-state.json ]; then
    cat .git/agentic-state.json
else
    echo '{"commits_examined": [], "current_feature": null}'
fi

echo ""
echo "=== Staged Changes ==="
git diff --no-ext-diff --cached --stat 2>/dev/null || echo "No staged changes"

echo ""
echo "=== Staged Diff ==="
git diff --no-ext-diff --cached 2>/dev/null || echo "No staged changes"

echo ""
echo "=== Working Directory Status ==="
git status --short 2>/dev/null || echo "Not a git repository"

echo ""
echo "=== Branch Info ==="
git branch --show-current 2>/dev/null || echo "Unknown branch"
