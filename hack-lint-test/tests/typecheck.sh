#!/bin/sh
# actions is MIT licensed, see /LICENSE.
# Requires HHVM; integration checks also require hh_server.
set -eu

action_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
mkdir "$work_dir/bin" "$work_dir/project"
export TYPECHECK_TEST_RESPONSE="$work_dir/response"
export TYPECHECK_TEST_ARGS="$work_dir/args"
export TYPECHECK_TEST_STATUS=0

cat > "$work_dir/bin/hh_server" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" > "$TYPECHECK_TEST_ARGS"
cat "$TYPECHECK_TEST_RESPONSE"
echo 'checker stderr fixture' >&2
exit "$TYPECHECK_TEST_STATUS"
STUB
cat > "$work_dir/bin/hh_client" <<'STUB'
#!/bin/sh
echo 'client fixture'
exit "$TYPECHECK_TEST_STATUS"
STUB
cat > "$work_dir/bin/jq" <<'STUB'
#!/bin/sh
echo 'jq must not be required' >&2
exit 127
STUB
chmod +x "$work_dir/bin/"*

expect_status() {
  expected=$1
  shift
  status=0
  "$@" > "$work_dir/output" 2>&1 || status=$?
  if [ "$status" -ne "$expected" ]; then
    cat "$work_dir/output"
    printf 'Expected status %s, got %s: %s\n' "$expected" "$status" "$*" >&2
    exit 1
  fi
  grep -q '^::endgroup::$' "$work_dir/output"
}

mock_check() {
  PATH="$work_dir/bin:$PATH" sh "$action_dir/typecheck.sh" "$@"
}

printf '%s' '{"passed":true,"errors":[]}' > "$TYPECHECK_TEST_RESPONSE"
expect_status 0 mock_check strict
grep -q 'no diagnostics' "$work_dir/output"
test "$(cat "$TYPECHECK_TEST_ARGS")" = '--check --json .'

# Warnings fail even when hh_server itself succeeds, including older JSON
# diagnostics that do not carry a severity field.
for diagnostic in '{"severity":"warning","message":[{"descr":"Redundant assertion","code":12011}]}' '{"message":[{"descr":"Legacy warning"}]}'; do
  printf '{"passed":true,"errors":[%s]}' "$diagnostic" > "$TYPECHECK_TEST_RESPONSE"
  expect_status 1 mock_check strict
  grep -q 'reported diagnostics' "$work_dir/output"
done

printf '%s' '{"passed":false,"errors":[{"message":[{"descr":"Incompatible return type"}]}]}' > "$TYPECHECK_TEST_RESPONSE"
export TYPECHECK_TEST_STATUS=2
expect_status 2 mock_check strict
grep -q 'Incompatible return type' "$work_dir/output"
grep -q 'checker stderr fixture' "$work_dir/output"

printf '%s' '{"passed":true,"errors":[]}' > "$TYPECHECK_TEST_RESPONSE"
export TYPECHECK_TEST_STATUS=7
expect_status 7 mock_check strict
export TYPECHECK_TEST_STATUS=0

for invalid in '' 'not JSON' 'null' '[]' '{}' '{"passed":true}' '{"errors":[]}' '{"passed":"true","errors":[]}' '{"passed":true,"errors":null}' '{"passed":true,"errors":{}}' '{"passed":false,"errors":[]}'; do
  printf '%s' "$invalid" > "$TYPECHECK_TEST_RESPONSE"
  expect_status 1 mock_check strict
done

# Non-strict modes continue to use the checker's own status.
printf '%s' '{"passed":true,"errors":[{"message":[]}]}' > "$TYPECHECK_TEST_RESPONSE"
expect_status 0 mock_check hh_server
test "$(cat "$TYPECHECK_TEST_ARGS")" = '--check .'
expect_status 0 mock_check hh_client
export TYPECHECK_TEST_STATUS=3
expect_status 3 mock_check hh_server
expect_status 3 mock_check hh_client
export TYPECHECK_TEST_STATUS=0
expect_status 1 mock_check unknown
expect_status 1 mock_check
echo 'Typecheck contract checks passed.'

if [ "${1:-}" != '--integration' ]; then
  exit 0
fi

cd "$work_dir/project"
: > .hhconfig
cat > example.hack <<'HACK'
function example(int $value)[]: int {
  return $value;
}
HACK
expect_status 0 sh "$action_dir/typecheck.sh" strict

# HHVM 4.x does not report this redundant-assertion warning.
if [ "${2:-}" = '--warnings' ]; then
cat > example.hack <<'HACK'
function example(int $value)[]: int {
  return $value as int;
}
HACK
expect_status 0 sh "$action_dir/typecheck.sh" hh_server
expect_status 1 sh "$action_dir/typecheck.sh" strict
grep -qi 'redundant\|always succeed' "$work_dir/output"

fi

cat > example.hack <<'HACK'
function example()[]: int {
  return 'not an int';
}
HACK
status=0
sh "$action_dir/typecheck.sh" strict > "$work_dir/output" 2>&1 || status=$?
test "$status" -ne 0
grep -q 'reported diagnostics' "$work_dir/output"
grep -q 'example.hack' "$work_dir/output"
echo 'Real typechecker checks passed.'
