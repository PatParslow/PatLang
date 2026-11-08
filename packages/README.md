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

It prints `ok`, `MISMATCH`, `MISSING` or `MALFORMED` for each `file` line and
exits non-zero on any failure. The files are committed with LF line ends
whatever the platform (`.gitattributes`: `packages/** text eol=lf`), so a
checkout's bytes are the ones hashed.

## Resolution and installation (sketch)

Resolution and installation are meant to use PatLang's own logic features
(facts, rules, `solve`) and GOAP planning (`action_add`, `plan`), not a
hand-written solver. This section is a sketch of how the pieces would be
expressed; none of it is implemented yet.

### Manifests become facts

Reading a manifest asserts one fact per field that matters to resolution:

```patlang
rule_add("pkg_available", ["deflate", "0.1.0"], [])
rule_add("pkg_available", ["zip", "0.1.0"], [])
# depends zip on deflate >= 0.1.0, < 0.2.0: one fact per constraint
rule_add("pkg_requires", ["zip", "0.1.0", "deflate", "ge", "0.1.0"], [])
rule_add("pkg_requires", ["zip", "0.1.0", "deflate", "lt", "0.2.0"], [])
rule_add("pkg_file_hash", ["zip", "0.1.0", "zip.patlang", "9fc97f0f52d5c63f6a5bba758245058a933d5c30fa4d37cca7f37ed1584d6d4c"], [])
```

### Version rules

Version comparison is the one piece of arithmetic the rules need. It would
be a small built-in relation over parsed versions (`version_cmp(A, B, Order)`
with Order one of `lt`, `eq`, `gt`), then the constraint rules are plain
rules:

```patlang
rule satisfies(V, ge, Min) :- version_cmp(V, Min, gt).
rule satisfies(V, ge, Min) :- version_cmp(V, Min, eq).
rule satisfies(V, lt, Max) :- version_cmp(V, Max, lt).
rule satisfies(V, eq, W)   :- version_cmp(V, W, eq).

# A candidate version of a dependency fits one constraint of a requirer.
rule dep_candidate(Pkg, PVer, Dep, DVer) :-
    pkg_requires(Pkg, PVer, Dep, Op, Bound),
    pkg_available(Dep, DVer),
    satisfies(DVer, Op, Bound).
```

"Every constraint holds" is a universally quantified condition, which plain
Horn rules express through negation (`not violates(...)`). Whether PatLang's
`solve` gets negation as failure, or the check stays a small loop over the
solutions of `dep_candidate`, is an open decision for when this is built.

### Installation as a plan

Installation is a GOAP problem: the goal is `installed(Pkg, Ver)` for the
requested package, and the actions fetch, verify and install one package
each, with dependency installation as a precondition:

```patlang
action_add("fetch_deflate_0_1_0", [], [["fetched", ["deflate", "0.1.0"]]], [], 1)
action_add("verify_deflate_0_1_0", [["fetched", ["deflate", "0.1.0"]]],
           [["verified", ["deflate", "0.1.0"]]], [], 1)
action_add("install_deflate_0_1_0", [["verified", ["deflate", "0.1.0"]]],
           [["installed", ["deflate", "0.1.0"]]], [], 1)
action_add("install_zip_0_1_0",
           [["verified", ["zip", "0.1.0"]], ["installed", ["deflate", "0.1.0"]]],
           [["installed", ["zip", "0.1.0"]]], [], 1)
let steps = plan([["installed", ["zip", "0.1.0"]]])
```

The actions are generated from the resolved facts (one set per candidate
version), so the planner's cost function can prefer, for example, versions
already installed (cost 0 for an `install` whose effect already holds) or
the newest version satisfying every constraint (cost rising with age).

## Trust (OPEN: not designed)

Package trust is to use the same zero-knowledge mechanism being designed
for PatLang networking. That mechanism does not exist yet, and this
document does not propose one.

What is decided: the manifest's `file` hashes pin a package's content, so
whatever the trust mechanism attests to can be a statement about the
manifest's own hash.

Open questions, to be settled with the networking design:

- what is attested (the manifest, a release, a publisher's key) and by whom;
- where attestations live (beside the manifest in the repo, or fetched);
- how a verify step in the installation plan above checks one;
- how trust in a package carries, or does not carry, to its dependencies.

Until then a package is trusted because it is in this repository.

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

Feature files must be ASCII: `self_hosting/lib/gherkin.patlang` reads a
feature one byte per character, so a UTF-8 character arrives as several.
The zip feature writes non-ASCII names as `\uXXXX` escapes for that reason.

`packages/deflate/spec/bench.patlang` times inflate and deflate at four
doubling sizes. Its data files go in `packages/deflate/build/`, made with
`spec/oracle.py gen KIND N OUT` and `spec/oracle.py zcompress IN OUT 6
default` for KIND text, random and repetitive and N 262144, 524288,
1048576 and 2097152, named `bench_KIND_N.bin` and `bench_KIND_N.z`.
`packages/sha256/spec/bench.patlang` times SHA-256 the same way.

PatLang has no built-in that gives a String's UTF-8 bytes, so the sha256
package encodes them itself (`utf8_encode` in `packages/sha256/text.patlang`).
