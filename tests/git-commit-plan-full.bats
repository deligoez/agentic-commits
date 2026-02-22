#!/usr/bin/env bats
# Tests for git-commit-plan "full" strategy (git add <file>)

load helpers/git-test-helper

setup() {
    setup_git_env
    init_repo
    create_service_file
}

@test "full strategy: commits all changes in a single file" {
    add_two_changes_to_service

    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {"message": "feat(Service): add validation and sanitize (improvements)", "files": [{"path": "Service.php"}]}
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    assert_commit_count 1
    assert_commit_message_contains 0 "add validation and sanitize"
    assert_one_file_per_commit 0
    assert_clean_working_tree
}

@test "full strategy: commits multiple files separately" {
    add_two_changes_to_service

    cat > "${REPO}/Config.php" << 'EOF'
<?php
class Config { public int $timeout = 30; }
EOF

    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {"message": "feat(Service): add validation and sanitize (improvements)", "files": [{"path": "Service.php"}]},
    {"message": "feat(Config): add config class (configuration)", "files": [{"path": "Config.php"}]}
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    assert_commit_count 2
    assert_commit_message_contains 0 "Config"
    assert_commit_message_contains 1 "Service"
    assert_one_file_per_commit 0
    assert_one_file_per_commit 1
    assert_clean_working_tree
}

@test "full strategy: skips commit when nothing to stage" {
    # No changes in working tree
    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {"message": "feat(Service): no changes (nothing)", "files": [{"path": "Service.php"}]}
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing staged"* ]]
    assert_commit_count 0
}

@test "full strategy: preserves commit order (fixes before features)" {
    add_two_changes_to_service

    cat > "${REPO}/Config.php" << 'EOF'
<?php
class Config { public int $timeout = 30; }
EOF

    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {"message": "fix(Service): add validation (crash prevention)", "files": [{"path": "Service.php"}]},
    {"message": "feat(Config): add config class (configuration)", "files": [{"path": "Config.php"}]}
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]

    # First commit (older) should be the fix
    local first_msg
    first_msg=$(git log --format="%s" --skip=1 -1)
    [[ "$first_msg" == *"fix(Service)"* ]]

    # Second commit (newer) should be the feat
    local second_msg
    second_msg=$(git log --format="%s" -1)
    [[ "$second_msg" == *"feat(Config)"* ]]
}
