#!/bin/bash
# actions is MIT licensed, see /LICENSE.
set -e

FLAGS="$1"
ARGS="$2"
# Match the argument splitting used by the direct pha invocation.
set -- $ARGS
ACTION="${1:-lint-all}"
FORMAT="${2:-text}"
DIRECTORIES="${3:-src,tests}"
if [ "$#" -gt 3 ] || [ "$ACTION" != "lint-all" ] ||
   { [ "$FORMAT" != "text" ] && [ "$FORMAT" != "vscode-json" ]; }; then
  echo 'pha-server lint_args must be: lint-all [text|vscode-json] [directories]'
  exit 1
fi

WORK_DIR=$(mktemp -d)
# The embedded launcher invokes hhvm for both compilation and serving.
# Forward the action's HHVM flags to both invocations.
export PHA_HHVM_BINARY="$(command -v hhvm)"
export PHA_HHVM_FLAGS="$FLAGS"
mkdir "$WORK_DIR/bin"
cat > "$WORK_DIR/bin/hhvm" <<'SH'
#!/bin/bash
if [ "${1:-}" = --hphp ]; then
  shift
  exec "$PHA_HHVM_BINARY" --hphp $PHA_HHVM_FLAGS "$@"
fi
exec "$PHA_HHVM_BINARY" $PHA_HHVM_FLAGS "$@"
SH
chmod +x "$WORK_DIR/bin/hhvm"

# Daemon mode returns only after the server is ready for its first request.
# The runner owns the daemon and temporary files after this step.
if ! PATH="$WORK_DIR/bin:$PATH" vendor/bin/pha-linters-server.sh -e -d \
  > "$WORK_DIR/server.log" 2>&1; then
  cat "$WORK_DIR/server.log"
  echo 'Linter server failed to start.'
  exit 1
fi

curl --noproxy '*' --fail --silent --show-error --get \
  --data-urlencode "action=$ACTION" --data-urlencode "format=$FORMAT" \
  --data-urlencode "directories=$DIRECTORIES" "http://127.0.0.1:10641/" \
  > "$WORK_DIR/result"
cat "$WORK_DIR/result"
# HHVM's HTTP response does not expose the entrypoint's exit status.
RESULT=$(cat "$WORK_DIR/result")
if [ "$FORMAT" = text ]; then
  [ "$RESULT" = 'No errors!' ]
else
  [ "$RESULT" = '[]' ]
fi
