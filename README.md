# GitHub Actions for Hack projects

This repository contains GitHub Actions code shared by the various Hack projects
(https://github.com/hershel-theodore-layton/).

## Integrations

Set `composer_version` on `hack-lint-test` to select a Composer release.
The default is `latest`.

| Input | Selected release |
| --- | --- |
| `latest` | Latest stable Composer release |
| `2` | Latest stable release in the 2.x series |
| `2.10` | Latest stable release in the 2.10.x series |
| `2.10.3` | Exactly 2.10.3 |

```yaml
- uses: hershel-theodore-layton/actions/hack-lint-test@master
  with:
    hhvm: "26.06.05"
    composer_version: "2.10"
```

If already installed, `self-update` runs, including to downgrade to match your
requested version.

Set `typecheck_engine: strict` to fail CI on typechecker warnings as well as errors:

```yaml
- uses: hershel-theodore-layton/actions/hack-lint-test@master
  with:
    hhvm: "26.09.29"
    typecheck_engine: strict
```

| Typecheck engine | Behavior |
| --- | --- |
| `hh_client` (default) | Uses `hh_client` and its exit status. |
| `hh_server` | Runs `hh_server --check .`, which can report warnings while succeeding. |
| `strict` | Runs `hh_server --check --json .` and fails on every reported diagnostic, including warnings. |

Strict mode prints the diagnostics even when the checker exits with an error,
and fails if the checker fails or returns invalid or incomplete JSON.
It uses HHVM to read the result and does not require `jq`.
Only diagnostics emitted by the installed typechecker can be caught; HHVM 4.x
does not emit the newer redundant-assertion warnings.
The choice of `lint_engine` is separate from typechecker strictness.

Set `lint_engine: pha-server` to run PhaLinters through its server launcher,
which compiles the embedded bundle into an HHVM repository before linting.
Install `hershel-theodore-layton/portable-hack-ast-linters-server` version 0.6
or newer. The action starts a temporary server, requests lint results, and stops
it afterward. Lint diagnostics and HTTP failures fail the step.
`hhvm_flags` applies to compilation and serving. `lint_args` accepts
`lint-all [text|vscode-json] [directories]`, for example `lint-all text src,tests`.
The default `hhast` and direct `pha` modes remain available.

After the normal checks, the action also typechecks the production package.
It replaces the checkout's files with a `git archive HEAD` export, honoring
`.gitattributes` `export-ignore`, and removes the vendor directory and lockfile.
It removes `require-dev` from the published `composer.json` before installing
production dependencies, since a fresh `install --no-dev` otherwise still
resolves development requirements. Development-specific manifests and
dependencies cannot mask missing production types. Composer resolves against
the installed HHVM version. Root Composer scripts and autoload generation are
skipped. When `hhvm-autoload` is a production dependency, `vendor/autoload.hhi`
forward declares the symbols normally supplied by its generated map. This
checks types without executing an autoloader or restoring runtime configuration.
The same `typecheck_engine` applies, using the project's `.hhconfig` even when
that file is excluded from the package. Git metadata is retained. This is the
final step: later workflow steps see the pruned package and production vendor
directory, not the original development checkout.
Set `skip_production_typecheck: true` if the workflow needs to defer this step.

This CI runner integrates with:

- HHVM's original Open Source dependencies
  - [hhvm/hacktest](https://github.com/hhvm/hacktest)
  - [hhvm/hhast](https://github.com/hhvm/hhast)
  - [hhvm/hhvm-autoload](https://github.com/hhvm/hhvm-autoload)[^1] and [ext_watchman](https://hhvm.com/blog/2021/05/11/hhvm-4.109.html) autoloading
- The `HTL\` family of Open Source tools
  - [PhaLinters](https://github.com/hershel-theodore-layton/portable-hack-ast-linters)
  - [TestChain](https://github.com/hershel-theodore-layton/test-chain)

CI tests both legacy HHVM autoload and Facts/Watchman autoload on HHVM 4.x,
using the `test-project-legacy` fixture with HackTest and HHAST. This fixture
does not depend on PhaLinters. On newer HHVM versions, `test-project-modern` uses
Facts/Watchman autoload, TestChain, and PhaLinters. The legacy autoloader and
Facebook test dependencies are only installed in the HHVM 4.x fixture.

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
    This actions runner patches hhvm-autoload to continue if the hsl is built-in.
