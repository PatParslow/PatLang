# PatLang packages

A package is a versioned set of PatLang include files described by a
manifest. For now packages live in this directory of the patlang git
repository, one directory per package:

```
packages/
  README.md                this file
  tools/                   programs that work on packages (verify_manifest.patlang)
  <name>/
    manifest.pkg           the manifest (format below)
    <name>.patlang         the package's entry include
    *.patlang              the rest of its includes
    spec/*.feature         its Gherkin features
    spec/run_spec.patlang  the runner for those features
    spec/*.py              test oracles (Python, tests only; never shipped as code)
    build/                 scratch output of runners and benchmarks (ignored by git)
```

A program uses a package by including its entry file:

```patlang
include "../packages/deflate/deflate.patlang"
```

Include paths resolve relative to the including file, and a file included
twice runs once, so two packages may both include a third. A package that
depends on another includes it by its path as a sibling directory (zip's
`include "../deflate/deflate.patlang"`), so an installation keeps packages
side by side under one directory, as here.

Current packages:

| package | version | what it gives |
|---------|---------|---------------|
| deflate | 0.1.0   | DEFLATE (RFC 1951) inflate and deflate, the zlib wrapper (RFC 1950), Adler-32, CRC-32 |
| zip     | 0.1.0   | zip archive reader and writer (stored and deflate entries, CRC-checked) |
| sha256  | 0.1.0   | SHA-256 (FIPS 180-4) and HMAC-SHA-256 (RFC 2104) over bytes, strings and files |
| resolve | 0.1.0   | manifest reader, version constraints, and dependency resolution through `rule_add`/`solve` (`docs/plans/package-manager.md`, P1) |
| trust   | 0.1.0   | trust records (view, genesis, transition, release, withdrawal) and every check of a release against its group's log, with the signature check passed in (`docs/plans/package-trust.md`, T1) |

## Manifest format (draft)

`manifest.pkg` is plain text, one field per line, `key value`. Blank lines
and lines starting with `#` are ignored. Keys may repeat where a list is
meant. Every value is ASCII, so a PatLang program can parse a manifest with
`split_lines` and one split at the first space.

```
# packages/zip/manifest.pkg
package zip
version 0.1.0
summary zip archive reader and writer (stored and deflated entries, CRC-32 checked)
entry zip.patlang
include zip.patlang
depends deflate >= 0.1.0, < 0.2.0
file zip.patlang sha256 9fc97f0f52d5c63f6a5bba758245058a933d5c30fa4d37cca7f37ed1584d6d4c
```

| key       | count     | meaning |
|-----------|-----------|---------|
| `package` | exactly 1 | the name: lower case letters, digits and `_` |
| `version` | exactly 1 | `MAJOR.MINOR.PATCH`, compared numerically field by field |
| `summary` | 0 or 1    | one line of description |
| `entry`   | exactly 1 | the include a user program names; it includes the rest |
| `include` | 1 or more | every PatLang file the package ships, relative to its directory |
| `depends` | 0 or more | `<name> <constraint>[, <constraint>...]`; every constraint must hold |
| `file`    | 1 or more | `<path> sha256 <64 hex digits>`, one per shipped file |

A manifest is refused (by `packages/resolve`'s reader, naming the line) when:

- a key is unknown, has no value, or is a single-valued key given twice;
- the name is not lower case letters, digits and `_`, or the version is not
  three plain numbers (no leading zeros, no pre-release suffix);
- the same `include` or `file` path is given twice, an `include` has no
  `file` line, a `file` names no `include`, or the `entry` is not an
  `include`;
- a package has two `depends` lines for one dependency, depends on itself,
  gives the same constraint twice, or ends a constraint list with a comma.

A version constraint is an operator and a version: `=`, `>=`, `>`, `<=`, `<`.
`depends deflate >= 0.1.0, < 0.2.0` means any 0.1.x from 0.1.0 up. There is
no caret or tilde shorthand: a range is written out, which keeps both the
parser and the rules below to plain comparisons.

The `file` lines give the content hash of each shipped file (the bytes as
committed, SHA-256). They cover `include` files only: specs, oracles and
build output are not part of what a user program loads.
`packages/tools/verify_manifest.patlang`, built on the sha256 package,
checks them:

```
./self_hosting/build/v2.exe packages/tools/verify_manifest.patlang packages/tools/build/verify_manifest.exe --workers 2
./packages/tools/build/verify_manifest.exe packages/deflate packages/zip packages/sha256
```

It prints `ok`, `MISMATCH`, `MISSING` or `MALFORMED` for each `file` line,
`OUTSIDE` for a `file` line whose path leaves the package (a `..` part, a
leading `/` or `\`, or a `:`), which it never reads, and `UNLISTED` for each
PatLang file the package ships (any outside `spec/` and `build/`) that no
`file` line names. It exits non-zero on any of these, and the repository
checks run it over every package. The files are committed with LF line ends
whatever the platform (`.gitattributes`: `packages/** text eol=lf`), so a
checkout's bytes are the ones hashed.

## Resolution and installation

The plan is in `docs/plans/package-manager.md`. Resolution is built
(`packages/resolve`, P1): manifests become facts, version constraints become
rules over version-order facts computed in PatLang, and the resolver chooses
the newest versions that fit, reporting a conflict with its requirers when
none do. Installation is planned, not built: a GOAP plan whose fetch, verify
and install actions have each dependency's installation as a precondition,
run by a `pkg` tool.

## Trust

Package trust uses the same group model as PatLang networking. The plan is
in `docs/plans/package-trust.md`. In outline:

- a package's publishers form a group, and a release is the group's quorum
  certificate over a statement naming the manifest's hash;
- the group's membership history is a signed log starting at a genesis
  record, whose hash a consumer pins once;
- verification uses public data only, and trust does not carry from a
  package to its dependencies.

The records and their checks are built (`packages/trust`, T1), and
`self_hosting/v2/examples/trust_attacks.patlang` runs them with Ed25519
written in PatLang. The `pkg` tool that signs and certifies releases, the
operating-system signing calls and the consumer's trust store are not built,
so today a package is trusted because it is in this repository, and its
`file` hashes pin its content.

## Running a package's specs

From the repository root, build a runner with the v2 compiler and run it.
Each runner calls Python (`py -3 -I`, its `spec/oracle.py`) as the
reference implementation:

```
./self_hosting/build/v2.exe packages/deflate/spec/run_spec.patlang packages/deflate/build/run_spec.exe --workers 2
./packages/deflate/build/run_spec.exe
./self_hosting/build/v2.exe packages/zip/spec/run_spec.patlang packages/zip/build/run_spec.exe --workers 2
./packages/zip/build/run_spec.exe
./self_hosting/build/v2.exe packages/sha256/spec/run_spec.patlang packages/sha256/build/run_spec.exe --workers 2
./packages/sha256/build/run_spec.exe
```

A runner given a feature file as its argument runs that file alone.

Feature files are UTF-8, and `self_hosting/lib/gherkin.patlang` reads them
as characters, so a step's text may hold any character. The zip feature
writes its non-ASCII names as `\uXXXX` escapes, which its steps decode; it
was written when the runner read one byte per character.

`packages/deflate/spec/bench.patlang` times inflate and deflate at four
doubling sizes. Its data files go in `packages/deflate/build/`, made with
`spec/oracle.py gen KIND N OUT` and `spec/oracle.py zcompress IN OUT 6
default` for KIND text, random and repetitive and N 262144, 524288,
1048576 and 2097152, named `bench_KIND_N.bin` and `bench_KIND_N.z`.
`packages/sha256/spec/bench.patlang` times SHA-256 the same way.

PatLang has no built-in that gives a String's UTF-8 bytes, so the sha256
package encodes them itself (`utf8_encode` in `packages/sha256/text.patlang`).
