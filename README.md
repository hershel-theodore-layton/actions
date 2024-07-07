# GitHub Actions for Hack projects

This repository contains GitHub Actions code shared by the various Hack projects
(https://github.com/hershel-theodore-layton/).

## Integrations

This CI runner integrates with:

- HHVM's original Open Source dependencies
  - [hhvm/hacktest](https://github.com/hhvm/hacktest)
  - [hhvm/hhast](https://github.com/hhvm/hhast)
  - [hhvm/hhvm-autoload](https://github.com/hhvm/hhvm-autoload)[^1] and [ext_watchman](https://hhvm.com/blog/2021/05/11/hhvm-4.109.html) autoloading
- The `HTL\` family of Open Source tools
  - [PhaLinters](https://github.com/hershel-theodore-layton/portable-hack-ast-linters)

## Acknowledgements

This project is a fork of [hhvm/actions](https://github.com/hhvm/actions).
`hhvm/actions` represents the effort Facebook, later Meta, made to support and
maintain a healthy Open Source community of Hack developers. The `HTL\` family
of packages was built with the aid of many packages from the `hhvm/` ecosystem:

- [HackTest](https://github.com/hhvm/hacktest)
- [HHAST](https://github.com/hhvm/hhast)
- [TypeAssert](https://github.com/hhvm/type-assert)
- [HHVMAutoload](https://github.com/hhvm/hhvm-autoload)
- [hhvm/actions](https://github.com/hhvm/actions)

I stood on the shoulders of giants and I wouldn't have been able to build and
publish the `HTL\` family of packages without that strong foundation. The
`hhvm/` ecosystem is frozen in time, somewhere in 2022. I believe this to be the
right time to finish replacing the foundations for ones which I can update
without permission or aid from Facebook (Meta).

[^1]:
    When you depend on `hhvm/hhvm-autoload`, but you do not depend on other
    packages from the `hhvm/` ecosystem, the autoloader will fail to initialize.
    This is because it can not find the `vendor/hhvm/hsl` directory.
    This search is pointless on [hhvm version 4.108](https://hhvm.com/blog/2021/05/04/hhvm-4.108.html) and above,
    since these versions of hhvm include the hsl in the hhvm binary.
    This actions runner patches hhvm-autoload to check if the hsl is built-in,
    before searching for the `vendor/hhvm/hsl` directory.
