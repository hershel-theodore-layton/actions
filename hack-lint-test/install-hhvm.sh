#!/bin/sh
#
# Copyright (c) 2017-present, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

echo "::group::Install HHVM"

set -ex

OS=$(uname -s)

if [ "$OS" = "Linux" ]; then
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update
  sudo apt-get install -y software-properties-common apt-transport-https
  sudo apt-key add "$(dirname "$0")/hhvm.gpg.key"
  if [ "$1" = "nightly" ]; then
    sudo add-apt-repository https://dl.hhvm.com/ubuntu
    sudo apt-get install -y hhvm-nightly
  elif [ "$1" = "latest" ]; then
    sudo add-apt-repository https://dl.hhvm.com/ubuntu
    sudo apt-get install -y hhvm
  else
    HHVM_VERSION=`hhvm --php -r "echo HHVM_VERSION_MAJOR . '.' . HHVM_VERSION_MINOR;"`
    if [ "$HHVM_VERSION" != "$1" ]; then
      DISTRO=$(lsb_release --codename --short)
      sudo add-apt-repository \
        "deb https://dl.hhvm.com/ubuntu ${DISTRO}-$1 main"
      sudo apt-get remove hhvm || true
      sudo apt-get install -y hhvm
    fi
  fi

else
  echo "Unknown OS: $OS"
  echo "::endgroup::"
  return 1
fi

echo "::endgroup::"
