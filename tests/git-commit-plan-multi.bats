#!/usr/bin/env bats
# Tests for git-commit-plan multi-file and directory support

load helpers/git-test-helper

setup() {
    setup_git_env
    init_repo
    create_service_file
}

# --- Multiple File Arguments ---

@test "multi: two plan files executed in order" {
    add_two_changes_to_service

    cat > "${REPO}/Config.php" << 'EOF'
<?php
class Config { public int $timeout = 30; }
EOF

    # Plan 1: Service changes
    cat > "${BATS_TEST_TMPDIR}/plan1.json" << 'PLAN'
{
  "commits": [
    {"message": "feat(Service): add validation and sanitize (improvements)", "files": [{"path": "Service.php"}]}
  ]
}
PLAN

    # Plan 2: Config changes
    cat > "${BATS_TEST_TMPDIR}/plan2.json" << 'PLAN'
{
  "commits": [
    {"message": "feat(Config): add config class (configuration)", "files": [{"path": "Config.php"}]}
  ]
}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan1.json" "${BATS_TEST_TMPDIR}/plan2.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 committed"* ]]

    # Verify order: plan1 first (Service), plan2 second (Config)
    assert_commit_message_contains 1 "Service"
    assert_commit_message_contains 0 "Config"
}

@test "multi: three plan files all execute" {
    add_two_changes_to_service

    cat > "${REPO}/Config.php" << 'EOF'
<?php
class Config { public int $timeout = 30; }
EOF

    cat > "${REPO}/Helper.php" << 'EOF'
<?php
class Helper { public function help(): string { return "help"; } }
EOF

    cat > "${BATS_TEST_TMPDIR}/p1.json" << 'PLAN'
{"commits":[{"message":"feat(Service): update (changes)","files":[{"path":"Service.php"}]}]}
PLAN
    cat > "${BATS_TEST_TMPDIR}/p2.json" << 'PLAN'
{"commits":[{"message":"feat(Config): add config (init)","files":[{"path":"Config.php"}]}]}
PLAN
    cat > "${BATS_TEST_TMPDIR}/p3.json" << 'PLAN'
{"commits":[{"message":"feat(Helper): add helper (util)","files":[{"path":"Helper.php"}]}]}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/p1.json" "${BATS_TEST_TMPDIR}/p2.json" "${BATS_TEST_TMPDIR}/p3.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 committed"* ]]
    assert_commit_count 3
}

# --- Directory Support ---

@test "multi: directory of plan files → all processed" {
    add_two_changes_to_service

    cat > "${REPO}/Config.php" << 'EOF'
<?php
class Config { public int $timeout = 30; }
EOF

    local plan_dir="${BATS_TEST_TMPDIR}/plans"
    mkdir -p "$plan_dir"

    cat > "${plan_dir}/001.json" << 'PLAN'
{"commits":[{"message":"feat(Service): update (changes)","files":[{"path":"Service.php"}]}]}
PLAN
    cat > "${plan_dir}/002.json" << 'PLAN'
{"commits":[{"message":"feat(Config): add config (init)","files":[{"path":"Config.php"}]}]}
PLAN

    run "$GIT_COMMIT_PLAN" "$plan_dir"
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 committed"* ]]
    assert_commit_count 2
}

@test "multi: directory alphabetical ordering → 001 before 002" {
    add_two_changes_to_service

    cat > "${REPO}/Config.php" << 'EOF'
<?php
class Config { public int $timeout = 30; }
EOF

    local plan_dir="${BATS_TEST_TMPDIR}/plans"
    mkdir -p "$plan_dir"

    # 001 has Service, 002 has Config
    cat > "${plan_dir}/001.json" << 'PLAN'
{"commits":[{"message":"feat(Service): update (changes)","files":[{"path":"Service.php"}]}]}
PLAN
    cat > "${plan_dir}/002.json" << 'PLAN'
{"commits":[{"message":"feat(Config): add config (init)","files":[{"path":"Config.php"}]}]}
PLAN

    run "$GIT_COMMIT_PLAN" "$plan_dir"
    [ "$status" -eq 0 ]

    # Service committed first (older), Config second (newer)
    assert_commit_message_contains 1 "Service"
    assert_commit_message_contains 0 "Config"
}

@test "multi: empty directory → error" {
    local plan_dir="${BATS_TEST_TMPDIR}/empty_plans"
    mkdir -p "$plan_dir"

    run "$GIT_COMMIT_PLAN" "$plan_dir"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no JSON files found"* ]]
}

@test "multi: non-json files in directory → ignored" {
    add_two_changes_to_service

    local plan_dir="${BATS_TEST_TMPDIR}/plans"
    mkdir -p "$plan_dir"

    cat > "${plan_dir}/001.json" << 'PLAN'
{"commits":[{"message":"feat(Service): update (changes)","files":[{"path":"Service.php"}]}]}
PLAN
    echo "not a plan" > "${plan_dir}/readme.txt"
    echo "also not a plan" > "${plan_dir}/notes.md"

    run "$GIT_COMMIT_PLAN" "$plan_dir"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 committed"* ]]
}

# --- Accumulated Counts ---

@test "multi: accumulated counts across plans" {
    add_two_changes_to_service

    cat > "${REPO}/Config.php" << 'EOF'
<?php
class Config { public int $timeout = 30; }
EOF

    cat > "${REPO}/Helper.php" << 'EOF'
<?php
class Helper {}
EOF

    # Plan 1: 1 commit
    cat > "${BATS_TEST_TMPDIR}/p1.json" << 'PLAN'
{"commits":[{"message":"feat(Service): update (changes)","files":[{"path":"Service.php"}]}]}
PLAN

    # Plan 2: 2 commits
    cat > "${BATS_TEST_TMPDIR}/p2.json" << 'PLAN'
{"commits":[
    {"message":"feat(Config): add config (init)","files":[{"path":"Config.php"}]},
    {"message":"feat(Helper): add helper (util)","files":[{"path":"Helper.php"}]}
]}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/p1.json" "${BATS_TEST_TMPDIR}/p2.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 committed"* ]]
    assert_commit_count 3
}

# --- Mixed Success/Failure ---

@test "multi: invalid plan skipped, valid plan continues → exit 1" {
    add_two_changes_to_service

    # Invalid plan (missing message)
    cat > "${BATS_TEST_TMPDIR}/bad.json" << 'PLAN'
{"commits":[{"files":[{"path":"x"}]}]}
PLAN

    # Valid plan
    cat > "${BATS_TEST_TMPDIR}/good.json" << 'PLAN'
{"commits":[{"message":"feat(Service): update (changes)","files":[{"path":"Service.php"}]}]}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/bad.json" "${BATS_TEST_TMPDIR}/good.json"
    [ "$status" -eq 1 ]
    # Valid plan still executed
    [[ "$output" == *"1 committed"* ]]
    # Bad plan was skipped
    [[ "$output" == *"Skipping invalid plan"* ]]
}

@test "multi: single file argument still works (backward compat)" {
    add_two_changes_to_service

    cat > "${BATS_TEST_TMPDIR}/plan.json" << 'PLAN'
{"commits":[{"message":"feat(Service): update (changes)","files":[{"path":"Service.php"}]}]}
PLAN

    run "$GIT_COMMIT_PLAN" "${BATS_TEST_TMPDIR}/plan.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 committed"* ]]
}
