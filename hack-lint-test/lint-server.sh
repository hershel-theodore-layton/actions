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
SERVER_PID=
cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill -TERM "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

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

# Avoid the launcher's replacement of an existing development server.
for attempt in {1..20}; do
  PORT=$((20000 + RANDOM))
  probe_status=0
  curl --noproxy '*' --silent --max-time 1 "http://127.0.0.1:$PORT/" > /dev/null || probe_status=$?
  [ "$probe_status" = 7 ] && break
done
if [ "$probe_status" != 7 ]; then
  echo 'Could not find an unused linter server port.'
  exit 1
fi

PATH="$WORK_DIR/bin:$PATH" \
  vendor/hershel-theodore-layton/portable-hack-ast-linters-server/bin/pha-linters-server.sh \
  -e -p "$PORT" > "$WORK_DIR/server.log" 2>&1 &
SERVER_PID=$!

ready=false
for attempt in {1..600}; do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    cat "$WORK_DIR/server.log"
    echo 'Linter server exited before becoming ready.'
    exit 1
  fi
  if identity=$(curl --noproxy '*' --fail --silent --max-time 1 \
    --get --data-urlencode 'action=identify-yourself' "http://127.0.0.1:$PORT/") &&
    [ "$identity" = 'HTL\PhaLintersServer' ]; then
    ready=true
    break
  fi
  sleep 0.1
done
if [ "$ready" != true ]; then
  cat "$WORK_DIR/server.log"
  echo 'Timed out waiting for the linter server.'
  exit 1
fi

curl --noproxy '*' --fail --silent --show-error --get \
  --data-urlencode "action=$ACTION" --data-urlencode "format=$FORMAT" \
  --data-urlencode "directories=$DIRECTORIES" "http://127.0.0.1:$PORT/" \
  > "$WORK_DIR/result"
cat "$WORK_DIR/result"
# HHVM's HTTP response does not expose the entrypoint's exit status.
RESULT=$(cat "$WORK_DIR/result")
if [ "$FORMAT" = text ]; then
  [ "$RESULT" = 'No errors!' ]
else
  [ "$RESULT" = '[]' ]
fi
