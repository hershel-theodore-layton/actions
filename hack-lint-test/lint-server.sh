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
DAEMON_PID=
cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill -TERM -- "-$SERVER_PID" 2>/dev/null || true
  fi
  # The HHVM wrapper records the detached daemon before exec, including when
  # startup is interrupted before the launcher can report readiness.
  if [ -f "$WORK_DIR/daemon.pid" ]; then
    DAEMON_PID=$(cat "$WORK_DIR/daemon.pid")
    kill -INT "$DAEMON_PID" 2>/dev/null || true
    for attempt in {1..50}; do
      # An exited daemon may remain a zombie until the container's init reaps it.
      if ! kill -0 "$DAEMON_PID" 2>/dev/null ||
         [ "$(cut -d ' ' -f 3 "/proc/$DAEMON_PID/stat" 2>/dev/null)" = Z ]; then
        DAEMON_PID=
        break
      fi
      sleep 0.1
    done
    [ -z "$DAEMON_PID" ] || kill -KILL "$DAEMON_PID" 2>/dev/null || true
  fi
  if [ -n "$SERVER_PID" ]; then
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
export PHA_PID_FILE="$WORK_DIR/daemon.pid"
mkdir "$WORK_DIR/bin"
cat > "$WORK_DIR/bin/hhvm" <<'SH'
#!/bin/bash
if [ "${1:-}" = --hphp ]; then
  shift
  exec "$PHA_HHVM_BINARY" --hphp $PHA_HHVM_FLAGS "$@"
fi
previous=
for argument in "$@"; do
  if [ "$previous" = -m ] && [ "$argument" = server ]; then
    printf '%s\n' "$$" > "$PHA_PID_FILE"
    break
  fi
  previous=$argument
done
exec "$PHA_HHVM_BINARY" $PHA_HHVM_FLAGS "$@"
SH
chmod +x "$WORK_DIR/bin/hhvm"

# Avoid the launcher's replacement of an existing development server.
for attempt in {1..20}; do
  PORT=$((20000 + RANDOM % 10000))
  probe_status=0
  curl --noproxy '*' --silent --max-time 1 "http://127.0.0.1:$PORT/" > /dev/null || probe_status=$?
  [ "$probe_status" = 7 ] && break
done
if [ "$probe_status" != 7 ]; then
  echo 'Could not find an unused linter server port.'
  exit 1
fi

setsid env PATH="$WORK_DIR/bin:$PATH" \
  vendor/hershel-theodore-layton/portable-hack-ast-linters-server/bin/pha-linters-server.sh \
  -e -d -p "$PORT" > "$WORK_DIR/server.log" 2>&1 &
SERVER_PID=$!

# Daemon mode returns only after the server is ready. Bound startup while
# retaining process-group cleanup if compilation is interrupted.
for attempt in {1..600}; do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    break
  fi
  sleep 0.1
done
if kill -0 "$SERVER_PID" 2>/dev/null; then
  cat "$WORK_DIR/server.log"
  echo 'Timed out waiting for the linter server.'
  exit 1
fi
if ! wait "$SERVER_PID"; then
  cat "$WORK_DIR/server.log"
  echo 'Linter server failed to start.'
  exit 1
fi
SERVER_PID=
if [ ! -s "$WORK_DIR/daemon.pid" ]; then
  echo 'Linter launcher did not start an HHVM daemon.'
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
