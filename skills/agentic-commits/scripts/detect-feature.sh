#!/bin/bash
# Detect feature boundaries and completion status

set -e

echo "=== Feature Detection ==="

# Extract scopes from recent commits
echo "Recent scopes:"
git log --oneline -20 --format="%s" 2>/dev/null | grep -oE '\([^)]+\)' | sort | uniq -c | sort -rn || echo "No scopes found"

echo ""

# Check for WIP commits
echo "WIP commits (incomplete work):"
git log --oneline -20 2>/dev/null | grep -iE '^[a-f0-9]+ wip' || echo "No WIP commits"

echo ""

# Check for completed work (feat/fix commits = done)
echo "Completed work (feat/fix = done, no → next):"
git log --oneline -20 2>/dev/null | grep -E '^[a-f0-9]+ (feat|fix)' || echo "No completed work found"

echo ""

# Extract → next from WIP commits (for Resume)
echo "Pending tasks from WIP commits:"
git log --oneline -10 2>/dev/null | grep -oE '→ .*$' || echo "No pending tasks"

echo ""

# Files changed in recent commits (for scope detection)
echo "Recently changed files:"
git log --oneline -5 --name-only --format="" 2>/dev/null | sort | uniq -c | sort -rn | head -10 || echo "No files"

echo ""

# Check test status
echo "=== Test Status ==="
if [ -f package.json ]; then
    echo "Node.js project detected"
    if grep -q '"test"' package.json; then
        echo "Test script available"
    fi
elif [ -f go.mod ]; then
    echo "Go project detected"
elif [ -f Cargo.toml ]; then
    echo "Rust project detected"
elif [ -f requirements.txt ] || [ -f pyproject.toml ]; then
    echo "Python project detected"
else
    echo "Project type unknown"
fi
