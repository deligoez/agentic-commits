#!/usr/bin/env bats
# Tests for git-commit-plan "hash-object" strategy

load helpers/git-test-helper

setup() {
    setup_git_env
    init_repo
    create_service_file
}

@test "hash-object: stages intermediate file without touching working tree" {
    add_two_changes_to_service

    # Create intermediate file with only validation change
    cat > "${BATS_TEST_TMPDIR}/intermediate_v1.php" << 'EOF'
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
}
EOF

    cat > "${BATS_TEST_TMPDIR}/plan.json" << PLAN
{
  "commits": [
    {
      "message": "fix(Service): add empty input validation (crash prevention)",
      "files": [{"path": "Service.php", "intermediate": "${BATS_TEST_TMPDIR}/intermediate_v1.php"}]
    },
    {
      "message": "feat(Service): add sanitize method (XSS protection)",
      "files": [{"path": "Service.php"}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 committed"* ]]

    # Verify commit count
    assert_commit_count 2

    # Verify first commit has only validation
    assert_commit_diff_contains 1 "InvalidArgumentException"
    local fix_diff
    fix_diff=$(git show HEAD~1 --format="")
    [[ "$fix_diff" != *"sanitize"* ]]

    # Verify second commit has sanitize
    assert_commit_diff_contains 0 "sanitize"
    assert_commit_diff_contains 0 "htmlspecialchars"

    # Both should be one file each
    assert_one_file_per_commit 0
    assert_one_file_per_commit 1

    # Working tree should be clean
    assert_clean_working_tree
}

@test "hash-object: fails when intermediate file does not exist" {
    add_two_changes_to_service

    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {
      "message": "fix(Service): test (test)",
      "files": [{"path": "Service.php", "intermediate": "/nonexistent/file.php"}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [[ "$output" == *"failed"* ]] || [[ "$output" == *"Skipping"* ]]
}

@test "hash-object: preserves working tree state" {
    add_two_changes_to_service

    # Save working tree content
    local working_tree_before
    working_tree_before=$(cat "${REPO}/Service.php")

    # Create intermediate (partial change)
    cat > "${BATS_TEST_TMPDIR}/intermediate_v1.php" << 'EOF'
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
}
EOF

    cat > "${BATS_TEST_TMPDIR}/plan.json" << PLAN
{
  "commits": [
    {
      "message": "fix(Service): add validation (crash prevention)",
      "files": [{"path": "Service.php", "intermediate": "${BATS_TEST_TMPDIR}/intermediate_v1.php"}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]

    # Working tree should still have ALL original changes (including sanitize)
    local working_tree_after
    working_tree_after=$(cat "${REPO}/Service.php")
    [ "$working_tree_before" = "$working_tree_after" ]
}

@test "hash-object: three-way split with two intermediates" {
    # File with 3 changes
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
        return strtoupper(trim($input));
    }

    public function sanitize(string $input): string
    {
        return htmlspecialchars($input, ENT_QUOTES, 'UTF-8');
    }
}
EOF

    # Intermediate 1: only validation
    cat > "${BATS_TEST_TMPDIR}/v1.php" << 'EOF'
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
}
EOF

    # Intermediate 2: validation + process change
    cat > "${BATS_TEST_TMPDIR}/v2.php" << 'EOF'
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
        return strtoupper(trim($input));
    }
}
EOF

    cat > "${BATS_TEST_TMPDIR}/plan.json" << PLAN
{
  "commits": [
    {
      "message": "fix(Service): add validation (crash prevention)",
      "files": [{"path": "Service.php", "intermediate": "${BATS_TEST_TMPDIR}/v1.php"}]
    },
    {
      "message": "refactor(Service): trim input in process (cleanup)",
      "files": [{"path": "Service.php", "intermediate": "${BATS_TEST_TMPDIR}/v2.php"}]
    },
    {
      "message": "feat(Service): add sanitize method (XSS protection)",
      "files": [{"path": "Service.php"}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 committed"* ]]
    assert_commit_count 3

    # Commit 1 (oldest): validation only
    assert_commit_diff_contains 2 "InvalidArgumentException"
    # Commit 2: trim added
    assert_commit_diff_contains 1 "trim"
    # Commit 3 (newest): sanitize
    assert_commit_diff_contains 0 "sanitize"

    assert_clean_working_tree
}
