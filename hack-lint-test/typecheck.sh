set -e

ENGINE="$1"

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
  set -x
  RESULT=`hh_server --check --json .`
  if [ "$(printf '%s' "$RESULT" | jq '.errors | length')" -gt 0 ]; then
    printf '%s\n' "$RESULT" | jq '.errors'
    exit 1
  fi
)
else
  echo "Invalid typecheck_engine value: $ENGINE"
  exit 1
fi

echo "::endgroup::"
