#!/bin/bash
# Shared test helper for git-commit-plan tests
# Provides isolated git environment and common setup functions

# Path to the script under test
SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../skills/agentic-commits/scripts" && pwd)"
GIT_COMMIT_PLAN="${SCRIPT_DIR}/git-commit-plan"

# --- Git Environment Isolation ---

setup_git_env() {
    # Prevent interference from system/global git config
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_CONFIG_GLOBAL="${BATS_TEST_TMPDIR}/gitconfig"
    export GIT_AUTHOR_NAME="Test"
    export GIT_AUTHOR_EMAIL="test@test.com"
    export GIT_COMMITTER_NAME="Test"
    export GIT_COMMITTER_EMAIL="test@test.com"

    # Suppress git hints
    git config --global init.defaultBranch master
    git config --global advice.detachedHead false
}

# --- Repo Setup ---

# Create a fresh git repo with an initial commit
# Sets $REPO as the working directory
init_repo() {
    REPO="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "$REPO"
    cd "$REPO"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"

    # Create initial file and commit
    echo "initial" > README.md
    git add README.md
    git commit --quiet -m "initial commit"
}

# Create a PHP service file (common test fixture)
create_service_file() {
    cat > "${REPO}/Service.php" << 'EOF'
<?php

class Service
{
    public function validate(string $input): bool
    {
        return strlen($input) > 0;
    }

    public function process(string $input): string
    {
        return strtoupper($input);
    }
}
EOF
    git add Service.php
    git commit --quiet -m "feat(Service): add initial service"
}

# Add two independent changes to Service.php (validation fix + sanitize feature)
add_two_changes_to_service() {
    cat > "${REPO}/Service.php" << 'EOF'
<?php

class Service
{
    public function validate(string $input): bool
    {
        if (empty($input)) {
            throw new \InvalidArgumentException('Input cannot be empty');
        }

        return strlen($input) > 0;
    }

    public function process(string $input): string
    {
        return strtoupper($input);
    }

    public function sanitize(string $input): string
    {
        return htmlspecialchars($input, ENT_QUOTES, 'UTF-8');
    }
}
EOF
}

# Add three independent changes to Service.php (validation fix + logging + sanitize feature)
add_three_changes_to_service() {
    cat > "${REPO}/Service.php" << 'EOF'
<?php

class Service
{
    public function validate(string $input): bool
    {
        if (empty($input)) {
            throw new \InvalidArgumentException('Input cannot be empty');
        }

        return strlen($input) > 0;
    }

    public function process(string $input): string
    {
        error_log("Processing: $input");

        return strtoupper($input);
    }

    public function sanitize(string $input): string
    {
        return htmlspecialchars($input, ENT_QUOTES, 'UTF-8');
    }
}
EOF
}

# Add changes with a deletion hunk (deletion + addition + addition)
# Hunk 0: delete return line in validate (net -1)
# Hunk 1: add error_log in process (net +2)
# Hunk 2: add sanitize method (net +5)
add_changes_with_deletion() {
    cat > "${REPO}/Service.php" << 'EOF'
<?php

class Service
{
    public function validate(string $input): bool
    {
    }

    public function process(string $input): string
    {
        error_log("Processing: $input");

        return strtoupper($input);
    }

    public function sanitize(string $input): string
    {
        return htmlspecialchars($input, ENT_QUOTES, 'UTF-8');
    }
}
EOF
}

# Add four independent changes to Service.php
# Hunk 0: validation check in validate()
# Hunk 1: error_log in process()
# Hunk 2: cache property at class top
# Hunk 3: sanitize method at end
add_four_changes_to_service() {
    cat > "${REPO}/Service.php" << 'EOF'
<?php

class Service
{
    private array $cache = [];

    public function validate(string $input): bool
    {
        if (empty($input)) {
            throw new \InvalidArgumentException('Input cannot be empty');
        }

        return strlen($input) > 0;
    }

    public function process(string $input): string
    {
        error_log("Processing: $input");

        return strtoupper($input);
    }

    public function sanitize(string $input): string
    {
        return htmlspecialchars($input, ENT_QUOTES, 'UTF-8');
    }
}
EOF
}

# --- Assertion Helpers ---

# Assert the number of commits since the initial commit
assert_commit_count() {
    local expected="$1"
    local actual
    actual=$(git log --oneline | wc -l | tr -d ' ')
    # Subtract 2 (initial commit + service commit)
    local new_commits=$((actual - 2))
    if [ "$new_commits" -ne "$expected" ]; then
        echo "Expected $expected new commits, got $new_commits"
        echo "Full log:"
        git log --oneline
        return 1
    fi
}

# Assert the latest commit message contains a string
assert_commit_message_contains() {
    local offset="${1:-0}"
    local expected="$2"
    local actual
    actual=$(git log --format="%s" --skip="$offset" -1)
    if [[ "$actual" != *"$expected"* ]]; then
        echo "Expected commit message to contain: $expected"
        echo "Actual: $actual"
        return 1
    fi
}

# Assert only one file was changed in the latest commit
assert_one_file_per_commit() {
    local offset="${1:-0}"
    local ref="HEAD"
    if [ "$offset" -gt 0 ]; then
        ref="HEAD~${offset}"
    fi
    local files_changed
    files_changed=$(git show --stat "$ref" --format="" | grep '|' | wc -l | tr -d ' ')
    if [ "$files_changed" -ne 1 ]; then
        echo "Expected 1 file changed, got $files_changed"
        git show --stat "$ref" --format=""
        return 1
    fi
}

# Assert a specific string exists in a commit's diff
assert_commit_diff_contains() {
    local offset="${1:-0}"
    local expected="$2"
    local ref="HEAD"
    if [ "$offset" -gt 0 ]; then
        ref="HEAD~${offset}"
    fi
    local diff
    diff=$(git show "$ref" --format="")
    if [[ "$diff" != *"$expected"* ]]; then
        echo "Expected diff at $ref to contain: $expected"
        echo "Actual diff:"
        echo "$diff"
        return 1
    fi
}

# Assert no remaining unstaged changes
assert_clean_working_tree() {
    if ! git diff --quiet; then
        echo "Expected clean working tree but found changes:"
        git diff --stat
        return 1
    fi
}
