#!/bin/bash
# actions is MIT licensed, see /LICENSE.
set -e

ARGS="$1"
set -- $ARGS
ACTION="${1:-lint-all}"
FORMAT="${2:-text}"
DIRECTORIES="${3:-src,tests}"
if [ "$#" -gt 3 ] || [ "$ACTION" != "lint-all" ] ||
   { [ "$FORMAT" != "text" ] && [ "$FORMAT" != "vscode-json" ]; }; then
  echo 'pha-server lint_args must be: lint-all [text|vscode-json] [directories]'
  exit 1
fi

vendor/bin/pha-linters-server.sh -e -d

RESULT=$(curl --noproxy '*' --fail --silent --show-error --get \
  --data-urlencode "action=$ACTION" --data-urlencode "format=$FORMAT" \
  --data-urlencode "directories=$DIRECTORIES" "http://127.0.0.1:10641/")
printf '%s\n' "$RESULT"
if [ "$FORMAT" = text ]; then
  [ "$RESULT" = 'No errors!' ]
else
  [ "$RESULT" = '[]' ]
fi
