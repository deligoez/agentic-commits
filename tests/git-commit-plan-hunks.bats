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
