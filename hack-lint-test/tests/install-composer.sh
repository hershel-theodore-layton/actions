#!/bin/sh
# actions is MIT licensed, see /LICENSE.
# Integration test; requires HHVM, PHP, wget, and access to getcomposer.org.
set -eu

installer=$(cd "$(dirname "$0")/.." && pwd)/install-composer.sh
export REAL_WGET="$(command -v wget)"
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
mkdir "$work_dir/bin"
# Hide any preinstalled Composer while keeping the installer's prerequisites.
for tool in php hhvm wget mkdir mktemp rm dirname sed sha384sum; do
  ln -s "$(command -v "$tool")" "$work_dir/bin/$tool"
done

run_setup() {
  : > "$work_dir/output"
  PATH="$work_dir/bin" GITHUB_OUTPUT="$work_dir/output" \
    /bin/sh "$installer" "$1" "$work_dir/action directory"
}

version() {
  "$work_dir/action directory/composer.phar" --no-plugins --no-scripts --version --no-ansi
}

run_setup 2.10.2
version | grep 'Composer version 2.10.2 '
test "$(cat "$work_dir/output")" = "binary=$work_dir/action directory/composer.phar"

run_setup 2.10.3
version | grep 'Composer version 2.10.3 '
before=$(sha256sum "$work_dir/action directory/composer.phar")
run_setup 2.10.3
test "$before" = "$(sha256sum "$work_dir/action directory/composer.phar")"
run_setup 2.10.2
version | grep 'Composer version 2.10.2 '
run_setup 2.10.3

# Check all floating selectors against live release metadata.
for selector in 2.10 2 latest; do
  expected=$(hhvm "$(dirname "$installer")/resolve-composer-version.hack" "$selector")
  run_setup "$selector"
  version | grep "Composer version $expected "
done

# A Composer on PATH is reused and is the binary exported to the action.
mv "$work_dir/action directory/composer.phar" "$work_dir/bin/composer"
run_setup 2.10.3
test "$(cat "$work_dir/output")" = "binary=$work_dir/bin/composer"
test ! -f "$work_dir/action directory/composer.phar"

# Invalid versions fail before invoking Composer or downloading anything.
if run_setup '--help'; then
  echo 'Invalid version unexpectedly accepted' >&2
  exit 1
fi
test ! -s "$work_dir/output"

# An installation that cannot self-update is replaced with an action-local copy.
cat > "$work_dir/bin/composer" <<'STUB'
#!/bin/sh
case "$*" in
  *--version*) echo 'Composer version 2.9.0 2025-01-01';;
  *self-update*) exit 1;;
  *) exit 1;;
esac
STUB
chmod +x "$work_dir/bin/composer"
run_setup 2.10.3
version | grep 'Composer version 2.10.3 '
test "$(cat "$work_dir/output")" = "binary=$work_dir/action directory/composer.phar"

# A bad installer checksum must fail without exporting an outdated executable.
rm "$work_dir/action directory/composer.phar" "$work_dir/bin/wget"
cat > "$work_dir/bin/wget" <<'STUB'
#!/bin/sh
case "$*" in
  *installer.sig*) echo invalid-checksum;;
  *) exec "$REAL_WGET" "$@";;
esac
STUB
chmod +x "$work_dir/bin/wget"
if run_setup 2.10.3; then
  echo 'Invalid installer checksum unexpectedly accepted' >&2
  exit 1
fi
test ! -s "$work_dir/output"

# Even a successful self-update must actually satisfy the requested version.
cat > "$work_dir/bin/composer" <<'STUB'
#!/bin/sh
case "$*" in
  *--version*) echo 'Composer version 2.9.0 2025-01-01';;
  *self-update*) exit 0;;
  *) exit 1;;
esac
STUB
if run_setup 2.10.3; then
  echo 'Outdated Composer unexpectedly accepted after self-update' >&2
  exit 1
fi
test ! -s "$work_dir/output"

echo 'All Composer setup checks passed.'
