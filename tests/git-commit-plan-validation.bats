#!/usr/bin/env bats
# Tests for git-commit-plan validate_plan() — structural validation

load helpers/git-test-helper

setup() {
    setup_git_env
    init_repo
}

# --- Missing / Empty Fields ---

@test "validation: missing message field → error" {
    local plan='{"commits":[{"files":[{"path":"x"}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing or empty message"* ]]
}

@test "validation: empty message string → error" {
    local plan='{"commits":[{"message":"","files":[{"path":"x"}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing or empty message"* ]]
}

@test "validation: empty files array → error" {
    local plan='{"commits":[{"message":"feat(X): test (test)","files":[]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing or empty files"* ]]
}

@test "validation: missing files field → error" {
    local plan='{"commits":[{"message":"feat(X): test (test)"}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing or empty files"* ]]
}

@test "validation: missing path in file entry → error" {
    local plan='{"commits":[{"message":"feat(X): test (test)","files":[{"hunks":[0]}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing or empty path"* ]]
}

@test "validation: empty path string → error" {
    local plan='{"commits":[{"message":"feat(X): test (test)","files":[{"path":""}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing or empty path"* ]]
}

# --- Strategy Conflicts ---

@test "validation: both hunks and intermediate → error" {
    local plan='{"commits":[{"message":"feat(X): test (test)","files":[{"path":"x","hunks":[0],"intermediate":"/tmp/y"}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 1 ]
    [[ "$output" == *"cannot have both hunks and intermediate"* ]]
}

# --- Hunk Value Validation ---

@test "validation: negative hunk index → error" {
    local plan='{"commits":[{"message":"feat(X): test (test)","files":[{"path":"x","hunks":[-1]}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 1 ]
    [[ "$output" == *"non-negative integer"* ]]
}

@test "validation: non-integer hunk value → error" {
    local plan='{"commits":[{"message":"feat(X): test (test)","files":[{"path":"x","hunks":[1.5]}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 1 ]
    [[ "$output" == *"non-negative integer"* ]]
}

@test "validation: string in hunks array → error" {
    local plan='{"commits":[{"message":"feat(X): test (test)","files":[{"path":"x","hunks":["abc"]}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 1 ]
    [[ "$output" == *"non-negative integer"* ]]
}

# --- Message Format Warning ---

@test "validation: non-standard message format → warning but exit 0" {
    create_service_file
    # Modify file so there's something to commit
    echo "// change" >> "${REPO}/Service.php"

    local plan='{"commits":[{"message":"updated stuff","files":[{"path":"Service.php"}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 0 ]
    [[ "$output" == *"does not match format"* ]]
}

@test "validation: standard message format → no warning" {
    create_service_file
    echo "// change" >> "${REPO}/Service.php"

    local plan='{"commits":[{"message":"feat(Service): add feature (reason)","files":[{"path":"Service.php"}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 0 ]
    [[ "$output" != *"does not match format"* ]]
}

# --- Version Field ---

@test "validation: plan with version field → accepted" {
    create_service_file
    echo "// change" >> "${REPO}/Service.php"

    local plan='{"version":1,"commits":[{"message":"feat(Service): test (test)","files":[{"path":"Service.php"}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 committed"* ]]
}

@test "validation: plan without version field → accepted (backward compat)" {
    create_service_file
    echo "// change" >> "${REPO}/Service.php"

    local plan='{"commits":[{"message":"feat(Service): test (test)","files":[{"path":"Service.php"}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 committed"* ]]
}

# --- Multiple Errors ---

@test "validation: reports all errors in plan" {
    local plan='{"commits":[{"message":"","files":[]},{"files":[{"hunks":[0]}]}]}'
    run bash -c "echo '$plan' | $GIT_COMMIT_PLAN --stdin"
    [ "$status" -eq 1 ]
    # Should report errors from both commits
    [[ "$output" == *"commit[0]"* ]]
    [[ "$output" == *"commit[1]"* ]]
}
