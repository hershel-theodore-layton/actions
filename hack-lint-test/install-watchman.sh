#!/bin/sh
#
# Copyright (c) Meta Platforms, Inc. and its affiliates.
#
# These large parts of these installation instructions were taken from:
# https://github.com/facebook/watchman/blob/5f995979d5a5f42f2151247d06a1ac83969e5d1d/website/docs/install.md#prebuilt-binaries-2
# The full license text is repoduced here:
#
# ---
# MIT License
# 
# Copyright (c) Meta Platforms, Inc. and its affiliates.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# ---

set -ex

ls -al

# mkdir -p .var/tmp-directory-delete-me
# cp watchman.zip .var/tmp-directory-delete-me/watchman.zip

# cd .var/tmp-directory-delete-me
# unzip watchman.zip
# rm watchman.zip
# mv watchman* watchman-unzipped
# cat << EOF > watchman-unzipped/install-watchman.sh
# mkdir -p /usr/local/{bin,lib} /usr/local/var/run/watchman
# cp bin/* /usr/local/bin
# cp lib/* /usr/local/lib
# chmod 755 /usr/local/bin/watchman
# chmod 2777 /usr/local/var/run/watchman