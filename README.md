# GitHub Actions for Hack projects

This repository contains GitHub Actions code shared by the various Hack projects
(https://github.com/hershel-theodore-layton/).

## Integrations

This CI runner integrates with:

- HHVM's original Open Source test and lint frameworks
  - [hhvm/hacktest](https://github.com/hhvm/hacktest)
  - [hhvm/hhast](https://github.com/hhvm/hhast)
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
- [hhvm/actions](https://github.com/hhvm/actions)

I stood on the shoulders of giants and I wouldn't have been able to build and
publish the `HTL\` family of packages without that strong foundation. The
`hhvm/` ecosystem is frozen in time, somewhere in 2022. I believe this to be the
right time to finish replacing the foundations for ones which I can update
without permission or aid from Facebook (Meta).
