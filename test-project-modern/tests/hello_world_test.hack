/** actions is MIT licensed, see /LICENSE. */
namespace HTL\Actions\Tests;

use namespace HTL\TestChain;
use function HTL\Expect\expect;
use function HTL\Actions\hello_world;

<<TestChain\Discover>>
function hello_world_test(TestChain\Chain $chain)[]: TestChain\Chain {
  return $chain->group(__FUNCTION__)
    ->test(
      'hello_world returns a greeting',
      ()[defaults] ==> {
        expect(hello_world())->toEqual('Hello, world!');
      },
    );
}
