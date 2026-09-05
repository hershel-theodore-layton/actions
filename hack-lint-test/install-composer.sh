#!/bin/sh
# actions is MIT licensed, see /LICENSE.

set -eu

if [ "$#" -ne 2 ]; then
  echo 'Usage: install-composer.sh VERSION INSTALL_DIR' >&2
  exit 1
fi

selector="$1"
install_dir="$2"
script_dir=$(cd "$(dirname "$0")" && pwd)
requested_version=$(hhvm "$script_dir/resolve-composer-version.hack" "$selector")
echo "Composer selector $selector resolved to $requested_version."

echo '::group::Set up Composer'
setup_dir=''
trap 'if [ -n "$setup_dir" ]; then rm -rf "$setup_dir"; fi; echo "::endgroup::"' EXIT

read_version() {
  version_output=$("$composer_binary" --no-plugins --no-scripts --no-ansi --version) || return 1
  parsed_version=$(printf '%s\n' "$version_output" |
    sed -nE 's/^Composer (version )?([0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?)( .*|$)/\2/p')
  if [ -z "$parsed_version" ]; then
    echo 'Unable to determine installed Composer version.' >&2
    return 1
  fi
  printf '%s\n' "$parsed_version"
}

install_composer() {
  mkdir -p "$install_dir"
  install_dir=$(cd "$install_dir" && pwd)
  setup_dir=$(mktemp -d)
  # Verify the installer following Composer's programmatic installation guide.
  expected_checksum=$(wget -q -O - https://composer.github.io/installer.sig)
  wget -q -O "$setup_dir/composer-setup.php" https://getcomposer.org/installer
  actual_checksum=$(sha384sum "$setup_dir/composer-setup.php")
  actual_checksum=${actual_checksum%% *}
  if [ "$expected_checksum" != "$actual_checksum" ]; then
    echo 'ERROR: Invalid installer checksum' >&2
    exit 1
  fi
  php "$setup_dir/composer-setup.php" --version="$requested_version" --install-dir="$install_dir" --filename=composer.phar
  composer_binary="$install_dir/composer.phar"
}

composer_binary=''
if [ -f "$install_dir/composer.phar" ]; then
  composer_binary="$(cd "$install_dir" && pwd)/composer.phar"
elif command -v composer >/dev/null 2>&1; then
  composer_binary=$(command -v composer)
fi

if [ -z "$composer_binary" ]; then
  install_composer
else
  installed_version=$(read_version)
  if [ "$installed_version" != "$requested_version" ]; then
    echo "Updating Composer $installed_version to $requested_version."
    if ! "$composer_binary" --no-plugins --no-scripts --no-interaction self-update "$requested_version"; then
      echo 'Self-update failed; installing the requested version for this action.'
      install_composer
    fi
  fi
fi

installed_version=$(read_version)
if [ "$installed_version" != "$requested_version" ]; then
  echo "Composer $installed_version does not match requested version $requested_version." >&2
  exit 1
fi
echo "Using Composer $installed_version at $composer_binary."
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  printf 'binary=%s\n' "$composer_binary" >> "$GITHUB_OUTPUT"
fi
