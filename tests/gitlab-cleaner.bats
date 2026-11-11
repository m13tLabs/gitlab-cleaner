#!/usr/bin/env bats
# Runs gitlab-cleaner against a stub `glab` that serves fixture JSON and logs every call.
# Nothing here talks to a real GitLab instance.

setup() {
  CLEANER="${CLEANER:-$BATS_TEST_DIRNAME/../gitlab-cleaner}"
  STUB_DIR="$(mktemp -d)"
  export GLAB_CALLS="$STUB_DIR/calls.log"
  export HOME="$STUB_DIR"
  unset GITLAB_HOST CI_SERVER_URL
  for v in $(env | grep -o '^CLEANER_[A-Z_]*'); do unset "$v"; done

  old="$(date -u -d @$(( $(date +%s) - 200 * 86400 )) +%Y-%m-%dT%H:%M:%S.000+02:00 2>/dev/null \
    || date -u -r $(( $(date +%s) - 200 * 86400 )) +%Y-%m-%dT%H:%M:%S.000+02:00)"
  recent="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"

  cat >"$STUB_DIR/glab" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"\$GLAB_CALLS"
case "\$*" in
  "api user") echo '{"username":"bot"}' ;;
  "api --paginate projects?"*)
    # two pages, like the real --paginate output
    echo '[{"id":1,"path_with_namespace":"grp/app"}]'
    echo '[{"id":2,"path_with_namespace":"grp/no-repo"}]' ;;
  "api --paginate projects/1/repository/branches?per_page=100")
    echo '[{"name":"main","default":true,"protected":true,"merged":false,"commit":{"committed_date":"$old","author_name":"a"}},
           {"name":"release/1","default":false,"protected":true,"merged":false,"commit":{"committed_date":"$old","author_name":"a"}},
           {"name":"feature/old","default":false,"protected":false,"merged":true,"commit":{"committed_date":"$old","author_name":"a"}}]'
    echo '[{"name":"feature/with-mr","default":false,"protected":false,"merged":false,"commit":{"committed_date":"$old","author_name":"b"}},
           {"name":"keep/me","default":false,"protected":false,"merged":false,"commit":{"committed_date":"$old","author_name":"c"}},
           {"name":"feature/new","default":false,"protected":false,"merged":false,"commit":{"committed_date":"$recent","author_name":"d"}}]' ;;
  "api --paginate projects/2/repository/branches?per_page=100")
    echo '404 Project Not Found' >&2; exit 1 ;;
  "api --paginate projects/1/merge_requests?state=opened&per_page=100")
    echo '[{"source_project_id":1,"source_branch":"feature/with-mr"},{"source_project_id":9,"source_branch":"keep/me"}]' ;;
  "api -X DELETE projects/1/repository/branches/"*) ;;
  *) echo "unexpected glab call: \$*" >&2; exit 3 ;;
esac
EOF
  chmod +x "$STUB_DIR/glab"
  export PATH="$STUB_DIR:$PATH"
}

teardown() {
  rm -rf "$STUB_DIR"
}

@test "dry run lists only stale, unprotected branches without open MRs and deletes nothing" {
  run "$CLEANER" --inactivity 90d --report "$STUB_DIR/report.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would-delete grp/app  feature/old"* ]]
  [[ "$output" == *"would-delete grp/app  keep/me"* ]]
  [[ "$output" != *"feature/with-mr"* ]]
  [[ "$output" != *"feature/new"* ]]
  [[ "$output" != *"release/1"* ]]
  [[ "$output" == *"WARN  grp/no-repo"* ]]
  ! grep -q DELETE "$GLAB_CALLS"
  [ "$(jq '.would_delete' "$STUB_DIR/report.json")" -eq 2 ]
  [ "$(jq '.project_errors' "$STUB_DIR/report.json")" -eq 1 ]
}

@test "execute deletes the stale branches with URL-encoded names" {
  run "$CLEANER" --inactivity 90d --execute
  [ "$status" -eq 0 ]
  grep -qx 'api -X DELETE projects/1/repository/branches/feature%2Fold' "$GLAB_CALLS"
  grep -qx 'api -X DELETE projects/1/repository/branches/keep%2Fme' "$GLAB_CALLS"
  [ "$(grep -c DELETE "$GLAB_CALLS")" -eq 2 ]
}

@test "CLEANER_DRY_RUN=false from the environment enables deletion" {
  CLEANER_DRY_RUN=false run "$CLEANER"
  [ "$status" -eq 0 ]
  [ "$(grep -c DELETE "$GLAB_CALLS")" -eq 2 ]
}

@test "a longer inactivity period keeps everything" {
  run "$CLEANER" --inactivity 1y
  [ "$status" -eq 0 ]
  [[ "$output" != *"would-delete"* ]]
}

@test "branch exclude regex and include-open-mr are honoured" {
  run "$CLEANER" --exclude-branches '^keep/' --include-open-mr
  [ "$status" -eq 0 ]
  [[ "$output" == *"feature/with-mr"* ]]
  [[ "$output" != *"keep/me"* ]]
  ! grep -q merge_requests "$GLAB_CALLS"
}

@test "project filter skips non-matching projects" {
  run "$CLEANER" --projects '^grp/app$'
  [ "$status" -eq 0 ]
  [[ "$output" != *"no-repo"* ]]
}

@test "invalid input is rejected before any API call" {
  run "$CLEANER" --inactivity 0d
  [ "$status" -eq 2 ]
  run "$CLEANER" --dry-run=yes
  [ "$status" -eq 2 ]
  [ ! -f "$GLAB_CALLS" ]
}
