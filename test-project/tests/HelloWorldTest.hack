/*
 *  Copyright (c) 2018-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the MIT license found in the
 *  LICENSE file in the root directory of this source tree.
 *
 */

use type Facebook\HackTest\HackTest;
use function Facebook\FBExpect\expect;

final class HelloWorldTest extends HackTest {
  public function testHelloWorld()[defaults]: void {
    expect(hello_world())->toEqual('Hello, world!');
  }
}
