#!/bin/bash
#
# Copyright (c) 2017-2022, Facebook, Inc.
# Copyright (c) 2024,      Hershel Theodore Layton
# All rights reserved.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

set -e

HHVM="$1"
SKIP="$2"
FLAGS="$3"
ENGINE="$4"
ARGS="$5"

if [ "$SKIP" = "true" ]; then
  echo "Lint skipped."
  exit 0
fi

if [ "$SKIP" != "false" ]; then
  echo "Invalid skip_lint value: $SKIP"
  exit 1
fi

if [ "$HHVM" = "nightly" ]; then
  echo "Lint skipped on nightly HHVM build."
  exit 0
fi

echo "::group::Lint"

if [ "$ENGINE" = "hhast" ]; then
(
  set -x
  hhvm $FLAGS vendor/hhvm/hhast/bin/hhast-lint $ARGS
)
elif [ "$ENGINE" = "pha" ]; then
(
  set -x
  hhvm $FLAGS vendor/hershel-theodore-layton/portable-hack-ast-linters-server/bin/portable-hack-ast-linters-server-bundled.resource $ARGS
)
else
  echo "Invalid lint_engine value: $ENGINE"
  exit 1
fi

echo "::endgroup::"
