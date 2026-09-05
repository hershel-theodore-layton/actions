/** actions is MIT licensed, see /LICENSE. */
namespace HTL\Actions;

use namespace HH\Asio;
use namespace HH\Lib\{C, IO, Str};

<<__EntryPoint>>
async function resolve_composer_version_main_async()[defaults]: Awaitable<void> {
  try {
    $argv = \HH\global_get('argv') as vec<_>;
    $selector = ($argv[1] ?? '') as string;
    validate_composer_selector($selector);
    $releases = vec[];
    $parts = composer_version_parts($selector);

    if ($parts is null || C\count($parts) !== 3) {
      $contents = await Asio\curl_exec(
        'https://repo.packagist.org/p2/composer/composer.json',
      );
      $metadata = ((): mixed ==> {
        $error = null;
        $decoded = \json_decode_with_error(
          $contents,
          inout $error,
          true,
          512,
          \JSON_FB_HACK_ARRAYS,
        );
        if ($error is nonnull) {
          throw new \RuntimeException('Invalid Composer release metadata.');
        }
        return $decoded;
      })() as dict<_, _>;
      $packages = $metadata['packages'] as dict<_, _>;
      $entries = $packages['composer/composer'] as vec<_>;
      foreach ($entries as $release) {
        $entry = $release as dict<_, _>;
        $releases[] = $entry['version'] as string;
      }
    }
    echo resolve_composer_version($selector, $releases);
  } catch (\Throwable $error) {
    $stderr = IO\request_error();
    if ($stderr is nonnull) {
      await $stderr->writeAllAsync($error->getMessage()."\n");
    }
    exit(1);
  }
}

function composer_version_parts(string $version)[]: ?vec<int> {
  $parts = Str\split($version, '.');
  if (C\count($parts) < 1 || C\count($parts) > 3) {
    return null;
  }
  $numbers = vec[];
  foreach ($parts as $part) {
    if ($part === '' || Str\trim($part, '0123456789') !== '') {
      return null;
    }
    $number = Str\to_int($part);
    if ($number is null) {
      return null;
    }
    $numbers[] = $number;
  }
  return $numbers;
}

function validate_composer_selector(string $selector)[]: void {
  if ($selector !== 'latest' && composer_version_parts($selector) is null) {
    throw new \InvalidArgumentException(
      'Composer version must be latest, major, major.minor, or major.minor.patch.',
    );
  }
}

function resolve_composer_version(
  string $selector,
  vec<string> $releases,
)[]: string {
  validate_composer_selector($selector);
  $prefix = $selector === 'latest' ? vec[] : composer_version_parts($selector);
  invariant($prefix is nonnull, 'Validated selector must have numeric parts');
  if (C\count($prefix) === 3) {
    return $selector;
  }

  $selected = null;
  $selected_parts = vec[0, 0, 0];
  foreach ($releases as $version) {
    $parts = composer_version_parts($version);
    if ($parts is null || C\count($parts) !== 3) {
      continue;
    }
    $matches = true;
    foreach ($prefix as $index => $part) {
      if ($parts[$index] !== $part) {
        $matches = false;
        break;
      }
    }
    if (!$matches) {
      continue;
    }
    $comparison = 0;
    foreach ($parts as $index => $part) {
      $comparison = $part <=> $selected_parts[$index];
      if ($comparison !== 0) {
        break;
      }
    }
    if ($selected is null || $comparison > 0) {
      $selected = $version;
      $selected_parts = $parts;
    }
  }
  if ($selected is null) {
    throw new \RuntimeException(
      'No stable Composer release matches '.$selector.'.',
    );
  }
  return $selected;
}
