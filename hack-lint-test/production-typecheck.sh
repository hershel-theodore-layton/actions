#!/bin/bash
# actions is MIT licensed, see /LICENSE.
set -euo pipefail

action_dir=$(cd "$(dirname "$0")" && pwd)
project_dir=$(pwd)
read -r -a hhvm_flags <<< "${2:-}"
# Older container Git versions honor safe.directory only in global/system config.
git config --global --add safe.directory "$project_dir"
if [ "$(git rev-parse --show-toplevel)" != "$project_dir" ]; then
  echo 'Run the production check from the repository root.' >&2
  exit 1
fi
tools_dir=$(mktemp -d)
echo '::group::Typecheck production package'
cleanup() {
  if [ "${1:-}" = hh_client ]; then
    hh_client stop "$project_dir" >/dev/null 2>&1 || true
  fi
  rm -rf "$tools_dir"
  echo '::endgroup::'
}
trap 'cleanup "${1:-}"' EXIT

# Keep the checker helpers and Composer available even for self-hosted action CI.
cp "$action_dir/typecheck.sh" "$action_dir/check-typecheck-result.hack" "$tools_dir/"
cp "$action_dir/autoload.hhi.in" "$tools_dir/autoload.hhi"
composer_binary=$(realpath "$(command -v "${COMPOSER_BINARY:-composer}")")
case "$composer_binary" in
  "$project_dir"/*)
    cp -p "$composer_binary" "$tools_dir/composer"
    composer_binary="$tools_dir/composer"
    ;;
esac
# Git applies export-ignore, including directory and nested attribute rules.
git archive HEAD > "$tools_dir/package.tar"
# Typechecker configuration is often deliberately excluded from distributions.
cp .hhconfig "$tools_dir/.hhconfig"
hh_client stop "$project_dir" >/dev/null 2>&1 || true
# Replace the checkout with its published files, retaining Git metadata.
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf -- {} +
tar -x -f "$tools_dir/package.tar"
cp "$tools_dir/.hhconfig" .hhconfig
# Never reuse development manifests, dependency installs, or lockfiles.
rm -rf vendor composer.lock
# --no-dev skips installation, but fresh resolution still considers require-dev.
hhvm_version=$(hhvm "${hhvm_flags[@]}" --version | sed -n 's/^HipHop VM \([^ ]*\).*$/\1/p')
test -n "$hhvm_version"
php -r '
  $manifest = json_decode(file_get_contents("composer.json"), false, 512, JSON_THROW_ON_ERROR);
  unset($manifest->{"require-dev"});
  if (!isset($manifest->config)) $manifest->config = new stdClass();
  if (!isset($manifest->config->platform)) $manifest->config->platform = new stdClass();
  $manifest->config->platform->hhvm = $argv[1];
  file_put_contents("composer.json", json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR)."\n");
' "$hhvm_version"
# Composer runs under PHP; the installed Hack checker verifies HHVM source.
# Skip root scripts and Composer's PHP autoloader for this Hack typecheck.
COMPOSER=composer.json "$composer_binary" install \
  --no-dev --no-scripts --no-autoloader --no-interaction
# Supply generated declarations without executing the autoload generator.
if [ -d vendor/hhvm/hhvm-autoload ]; then
  rm -f vendor/autoload.hack
  cp "$tools_dir/autoload.hhi" vendor/autoload.hhi
fi
bash "$tools_dir/typecheck.sh" "${1:-}"
