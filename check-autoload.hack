/** actions is MIT licensed, see /LICENSE. */
namespace HTL\Actions;

<<__EntryPoint>>
function check_autoload()[defaults]: void {
  $argv = \HH\global_get('argv') as vec<_>;
  $expected_native = $argv[1] === 'native';
  invariant(
    \HH\autoload_is_native() === $expected_native,
    'Unexpected autoload mode',
  );
}
