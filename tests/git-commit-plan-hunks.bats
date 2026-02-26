#!/usr/bin/env bats
# Tests for git-commit-plan "hunk-select" strategy

load helpers/git-test-helper

setup() {
    setup_git_env
    init_repo
    create_service_file
}

@test "hunk-select: splits first hunk into separate commit" {
    add_two_changes_to_service

    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {
      "message": "fix(Service): add empty input validation (crash prevention)",
      "files": [{"path": "Service.php", "hunks": [0]}]
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

    # Verify first commit (fix) only has validation changes
    assert_commit_diff_contains 1 "InvalidArgumentException"
    # First commit should NOT contain sanitize
    local fix_diff
    fix_diff=$(git show HEAD~1 --format="")
    [[ "$fix_diff" != *"sanitize"* ]]

    # Verify second commit (feat) has sanitize changes
    assert_commit_diff_contains 0 "sanitize"
    assert_commit_diff_contains 0 "htmlspecialchars"

    # Both should be one file each
    assert_one_file_per_commit 0
    assert_one_file_per_commit 1

    # Working tree should be clean
    assert_clean_working_tree
}

@test "hunk-select: second hunk into separate commit" {
    add_two_changes_to_service

    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {
      "message": "feat(Service): add sanitize method (XSS protection)",
      "files": [{"path": "Service.php", "hunks": [1]}]
    },
    {
      "message": "fix(Service): add empty input validation (crash prevention)",
      "files": [{"path": "Service.php"}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 committed"* ]]

    # Verify first commit (feat) has sanitize only
    assert_commit_diff_contains 1 "sanitize"
    local feat_diff
    feat_diff=$(git show HEAD~1 --format="")
    [[ "$feat_diff" != *"InvalidArgumentException"* ]]

    # Verify second commit (fix) has validation
    assert_commit_diff_contains 0 "InvalidArgumentException"
}

@test "hunk-select: re-indexes hunks when same file split across two hunk-select commits" {
    add_two_changes_to_service

    # Both commits use hunk-select (the bug scenario)
    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {
      "message": "fix(Service): add empty input validation (crash prevention)",
      "files": [{"path": "Service.php", "hunks": [0]}]
    },
    {
      "message": "feat(Service): add sanitize method (XSS protection)",
      "files": [{"path": "Service.php", "hunks": [1]}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 committed"* ]]

    assert_commit_count 2

    # First commit has validation only
    assert_commit_diff_contains 1 "InvalidArgumentException"
    local fix_diff
    fix_diff=$(git show HEAD~1 --format="")
    [[ "$fix_diff" != *"sanitize"* ]]

    # Second commit has sanitize only
    assert_commit_diff_contains 0 "sanitize"
    assert_commit_diff_contains 0 "htmlspecialchars"
    local feat_diff
    feat_diff=$(git show HEAD --format="")
    [[ "$feat_diff" != *"InvalidArgumentException"* ]]

    assert_one_file_per_commit 0
    assert_one_file_per_commit 1
    assert_clean_working_tree
}

@test "hunk-select: three-way split on same file using hunk-select for all commits" {
    add_three_changes_to_service

    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {
      "message": "fix(Service): add empty input validation (crash prevention)",
      "files": [{"path": "Service.php", "hunks": [0]}]
    },
    {
      "message": "feat(Service): add process logging (observability)",
      "files": [{"path": "Service.php", "hunks": [1]}]
    },
    {
      "message": "feat(Service): add sanitize method (XSS protection)",
      "files": [{"path": "Service.php", "hunks": [2]}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 committed"* ]]

    assert_commit_count 3

    # First commit: validation
    assert_commit_diff_contains 2 "InvalidArgumentException"
    # Second commit: logging
    assert_commit_diff_contains 1 "error_log"
    # Third commit: sanitize
    assert_commit_diff_contains 0 "htmlspecialchars"

    assert_clean_working_tree
}

@test "hunk-select: non-contiguous hunk indices re-index correctly" {
    add_three_changes_to_service

    # Commit hunks [0, 2] first, then [1]
    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {
      "message": "fix(Service): validation and sanitize (safety)",
      "files": [{"path": "Service.php", "hunks": [0, 2]}]
    },
    {
      "message": "feat(Service): add process logging (observability)",
      "files": [{"path": "Service.php", "hunks": [1]}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 committed"* ]]

    assert_commit_count 2

    # First commit has validation + sanitize
    assert_commit_diff_contains 1 "InvalidArgumentException"
    assert_commit_diff_contains 1 "htmlspecialchars"

    # Second commit has logging only
    assert_commit_diff_contains 0 "error_log"
    local log_diff
    log_diff=$(git show HEAD --format="")
    [[ "$log_diff" != *"InvalidArgumentException"* ]]
    [[ "$log_diff" != *"htmlspecialchars"* ]]

    assert_clean_working_tree
}

@test "hunk-select: last hunk only from three-hunk file (skips all preceding)" {
    add_three_changes_to_service

    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {
      "message": "feat(Service): add sanitize method (XSS protection)",
      "files": [{"path": "Service.php", "hunks": [2]}]
    },
    {
      "message": "fix(Service): validation and logging (observability + safety)",
      "files": [{"path": "Service.php"}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 committed"* ]]

    assert_commit_count 2

    # First commit has sanitize only
    assert_commit_diff_contains 1 "htmlspecialchars"
    local sanitize_diff
    sanitize_diff=$(git show HEAD~1 --format="")
    [[ "$sanitize_diff" != *"InvalidArgumentException"* ]]
    [[ "$sanitize_diff" != *"error_log"* ]]

    # Second commit has validation + logging
    assert_commit_diff_contains 0 "InvalidArgumentException"
    assert_commit_diff_contains 0 "error_log"

    assert_clean_working_tree
}

@test "hunk-select: four-hunk split with non-contiguous selections across two commits" {
    add_four_changes_to_service

    # Commit 1: hunks [0, 3] (cache property + sanitize method, skip validation + logging)
    # Commit 2: hunks [1, 2] (validation + logging)
    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {
      "message": "feat(Service): add cache and sanitize (performance + security)",
      "files": [{"path": "Service.php", "hunks": [0, 3]}]
    },
    {
      "message": "fix(Service): add validation and logging (safety + observability)",
      "files": [{"path": "Service.php", "hunks": [1, 2]}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 committed"* ]]

    assert_commit_count 2

    # First commit: cache + sanitize
    assert_commit_diff_contains 1 "cache"
    assert_commit_diff_contains 1 "htmlspecialchars"
    local first_diff
    first_diff=$(git show HEAD~1 --format="")
    [[ "$first_diff" != *"InvalidArgumentException"* ]]
    [[ "$first_diff" != *"error_log"* ]]

    # Second commit: validation + logging
    assert_commit_diff_contains 0 "InvalidArgumentException"
    assert_commit_diff_contains 0 "error_log"
    local second_diff
    second_diff=$(git show HEAD --format="")
    [[ "$second_diff" != *"cache"* ]]
    [[ "$second_diff" != *"htmlspecialchars"* ]]

    assert_clean_working_tree
}

@test "hunk-select: deletion hunk skipping adjusts line numbers correctly" {
    add_changes_with_deletion

    # Skip hunk 0 (deletion, net -1), select hunk 1 (logging) and hunk 2 (sanitize)
    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {
      "message": "feat(Service): add logging and sanitize (observability + security)",
      "files": [{"path": "Service.php", "hunks": [1, 2]}]
    },
    {
      "message": "refactor(Service): remove validate body (cleanup)",
      "files": [{"path": "Service.php"}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 committed"* ]]

    assert_commit_count 2

    # First commit: logging + sanitize (NOT the deletion)
    assert_commit_diff_contains 1 "error_log"
    assert_commit_diff_contains 1 "htmlspecialchars"

    # Second commit: the deletion (removed return line)
    local del_diff
    del_diff=$(git show HEAD --format="")
    [[ "$del_diff" == *"-        return strlen"* ]]

    assert_clean_working_tree
}

@test "hunk-select: reverse order commit (last hunk first, first hunk second)" {
    add_three_changes_to_service

    # Commit hunks in reverse: [2] first, then [1], then [0]
    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {
      "message": "feat(Service): add sanitize method (XSS protection)",
      "files": [{"path": "Service.php", "hunks": [2]}]
    },
    {
      "message": "feat(Service): add process logging (observability)",
      "files": [{"path": "Service.php", "hunks": [1]}]
    },
    {
      "message": "fix(Service): add empty input validation (crash prevention)",
      "files": [{"path": "Service.php", "hunks": [0]}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 committed"* ]]

    assert_commit_count 3

    # First commit: sanitize
    assert_commit_diff_contains 2 "htmlspecialchars"
    # Second commit: logging
    assert_commit_diff_contains 1 "error_log"
    # Third commit: validation
    assert_commit_diff_contains 0 "InvalidArgumentException"

    assert_clean_working_tree
}

@test "hunk-select: fails gracefully on invalid hunk index" {
    add_two_changes_to_service

    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {
      "message": "fix(Service): bad hunk (test)",
      "files": [{"path": "Service.php", "hunks": [99]}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    # Should either fail or skip (nothing to stage from hunk 99)
    [[ "$output" == *"failed"* ]] || [[ "$output" == *"Nothing staged"* ]] || [[ "$output" == *"Skipping"* ]]
}

@test "hunk-select: works with file that has no diff" {
    # Service.php has no changes
    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {
      "message": "fix(Service): noop (test)",
      "files": [{"path": "Service.php", "hunks": [0]}]
    }
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    # Should handle missing diff gracefully
    [[ "$output" == *"failed"* ]] || [[ "$output" == *"Skipping"* ]]
}
