#!/usr/bin/env bats
# Tests for git-commit-plan input parsing, validation, and error handling

load helpers/git-test-helper

setup() {
    setup_git_env
    init_repo
}

# --- Argument Parsing ---

@test "exits with error when no arguments provided" {
    run "$GIT_COMMIT_PLAN"
    [ "$status" -eq 1 ]
    [[ "$output" == *"usage"* ]]
}

@test "exits with error when plan file does not exist" {
    run "$GIT_COMMIT_PLAN" "/nonexistent/plan.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "reads plan from file argument" {
    create_service_file
    cat > "${REPO}/Service.php" << 'EOF'
<?php
class Service
{
    public function validate(string $input): bool
    {
        return true;
    }
}
EOF

    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{
  "commits": [
    {"message": "refactor(Service): simplify validate (cleanup)", "files": [{"path": "Service.php"}]}
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 commits"* ]]
}

@test "reads plan from stdin with --stdin flag" {
    create_service_file
    cat > "${REPO}/Service.php" << 'EOF'
<?php
class Service
{
    public function validate(string $input): bool
    {
        return true;
    }
}
EOF

    local plan='{"commits":[{"message":"refactor(Service): simplify (cleanup)","files":[{"path":"Service.php"}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 committed"* ]]
}

# --- JSON Validation ---

@test "exits with error on invalid JSON" {
    run bash -c "echo 'not json' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid JSON"* ]]
}

@test "exits with error when commits array is empty" {
    run bash -c 'echo "{\"commits\":[]}" | '"$GIT_COMMIT_PLAN"' --stdin'
    [ "$status" -eq 1 ]
    [[ "$output" == *"no commits"* ]]
}

# --- Environment ---

@test "exits with error when not in git repository" {
    cd "$BATS_TEST_TMPDIR"
    mkdir -p notgit
    cd notgit

    local plan='{"commits":[{"message":"test","files":[{"path":"x"}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not inside a git repository"* ]]
}
