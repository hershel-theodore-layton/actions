#!/bin/sh
# actions is MIT licensed, see /LICENSE.
set -eu

ENGINE="${1:-}"
echo "::group::Typecheck ($ENGINE)"
trap 'echo "::endgroup::"' EXIT

if [ "$ENGINE" = "hh_client" ]; then
(
  set -x
  hh_client
)
elif [ "$ENGINE" = "hh_server" ]; then
(
  set -x
  hh_server --check .
)
elif [ "$ENGINE" = "strict" ]; then
(
  action_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  checker_status=0
  result=$(hh_server --check --json .) || checker_status=$?

  # hh_server can return success with warnings, or fail with useful JSON.
  # HHVM is already required by the action; jq is not installed in all images.
  report_status=0
  printf '%s\n' "$result" | hhvm "$action_dir/check-typecheck-result.hack" || report_status=$?
  if [ "$checker_status" -ne 0 ]; then
    printf 'hh_server exited with status %s.\n' "$checker_status" >&2
    exit "$checker_status"
  fi
  exit "$report_status"
)
else
  echo "Invalid typecheck_engine value: $ENGINE"
  exit 1
fi
