/** actions is MIT licensed, see /LICENSE. */
namespace HTL\Actions;

use namespace HH\Lib\{C, IO};

<<__EntryPoint>>
async function check_typecheck_result_main_async()[defaults]: Awaitable<void> {
  try {
    $input = await IO\request_input()->readAllAsync();
    $result = decode_typecheck_result($input);
    if (!($result is shape('passed' => bool, 'errors' => vec<_>, ...))) {
      throw new \RuntimeException(
        'Invalid hh_server JSON: expected passed (bool) and errors (array).',
      );
    }

    if (!C\is_empty($result['errors'])) {
      echo "Strict typechecking failed: hh_server reported diagnostics.\n";
      echo \json_encode(
        $result['errors'],
        \JSON_PRETTY_PRINT | \JSON_UNESCAPED_SLASHES,
      ).
        "\n";
      exit(1);
    }
    if (!$result['passed']) {
      throw
        new \RuntimeException('hh_server reported an unsuccessful typecheck.');
    }
    echo "Typecheck passed with no diagnostics.\n";
  } catch (\Throwable $error) {
    $stderr = IO\request_error();
    if ($stderr is nonnull) {
      await $stderr->writeAllAsync($error->getMessage()."\n");
    }
    exit(1);
  }
}

function decode_typecheck_result(string $input)[defaults]: mixed {
  $error = null;
  $result = \json_decode_with_error(
    $input,
    inout $error,
    true,
    512,
    \JSON_FB_HACK_ARRAYS,
  );
  if ($error is nonnull) {
    throw
      new \RuntimeException('Invalid hh_server JSON: unable to decode output.');
  }
  return $result;
}
