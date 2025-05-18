#!/bin/bash
#
# Copyright (c) 2017-present, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

set -e

SKIP="$1"
FLAGS="$2"
$ENGINE="$3"

if [ "$SKIP" = "true" ]; then
  echo "Tests skipped."
  exit 0
fi

if [ "$SKIP" != "false" ]; then
  echo "Invalid skip_tests value: $SKIP"
  exit 1
fi

if [ "$ENGINE" = "hacktest" ]; then
(
  set -x
  hhvm $FLAGS vendor/hhvm/hhast/bin/hacktest tests/
)
elif [ "$ENGINE" = "test-chain" ]; then
(
  set -x
  hhvm $FLAGS vendor/hershel-theodore-layton/test-chain/bin/test-chain --ci
)
else
  echo "Invalid test_engine value: $ENGINE"
  exit 1
fi

echo "::endgroup::"
