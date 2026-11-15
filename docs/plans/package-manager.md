# Package manager

A PatLang package is a versioned set of include files described by a manifest. This plan covers
finding, choosing, checking and installing packages. Trust is planned separately
(`docs/plans/package-trust.md`), and so is the group model trust is built on
(`docs/plans/ensemble-membership.md`).

The project owner set the direction on 2026-11-08:

- a package is a versioned set of includes with a manifest;
- resolution and installation use PatLang's own logic and planning (facts, rules, `solve`,
  `action_add`, `plan`), never a hand-written solver;
- packages come first from the patlang git repository, later from other sources;
- deflate and zip are the common base, under format packages (PDF, Word and Excel, graphics);
- trust uses the same model as PatLang networking, with zero-knowledge approvals as its research
  phase;
- no Rust: everything is PatLang compiled by v2.

The work starts once the v2 compiler is working properly (`docs/plans/v2-implementation.md`), and
must not take time from it before then.

## Built so far

As of 2026-11-15:

- the layout: `packages/<name>/` with `manifest.pkg`, includes, `spec/` and an ignored `build/`;
- the manifest format: `package`, `version`, `summary`, `entry`, `include`, `depends`, `file`
  (`packages/README.md`);
- three packages: `deflate` 0.1.0 (RFC 1950/1951, Adler-32, CRC-32), `zip` 0.1.0 and `sha256` 0.1.0
  (FIPS 180-4, HMAC), each with Gherkin features checked against a Python oracle;
- `packages/tools/verify_manifest.patlang`, which checks every `file` hash (10 ok);
- feature files may be UTF-8: `gherkin.patlang` reads them as characters (fixed 2026-11-08; all v2
  gates pass with it);
- P1, the resolver, in `packages/resolve/` (2026-11-08, commit b481bd3): 35 scenarios, 127 checks
  passing, checked against a Python oracle that resolves without logic programming. A 200-package
  universe took about 31 s before v2's logic engine was reworked
  ([#252](https://github.com/PatParslow/PatLang/issues/252)). On 2026-11-15, `spec/bench.patlang`
  over generated universes of 50, 100, 200 and 400 packages took 0.75, 1.7, 4.9 and 13.1 s. That
  is still more than linear, at 2.2 to 3 times per doubling, and reading the manifests grows
  fastest (0.24, 0.59, 1.5 and 4.5 s), so the reader is the next thing to profile.

## Resolution

### Manifests become facts

Reading a manifest asserts one fact per field that matters to resolution:

```patlang
rule_add("pkg_available", ["deflate", "0.1.0"], [])
rule_add("pkg_available", ["zip", "0.1.0"], [])
# depends deflate >= 0.1.0, < 0.2.0: one fact per constraint
rule_add("pkg_requires", ["zip", "0.1.0", "deflate", "ge", "0.1.0"], [])
rule_add("pkg_requires", ["zip", "0.1.0", "deflate", "lt", "0.2.0"], [])
rule_add("pkg_file_hash", ["zip", "0.1.0", "zip.patlang", "9fc97f0f..."], [])
```

### Version order as facts

Comparing two versions is the one piece of arithmetic the rules need. It needs no new built-in:
the resolver compares versions in PatLang, field by field as numbers, and asserts the result:

```patlang
rule_add("version_order", ["0.1.0", "0.2.0", "lt"], [])
rule_add("version_order", ["0.2.0", "0.1.0", "gt"], [])
rule_add("version_order", ["0.1.0", "0.1.0", "eq"], [])
```

P1 asserts every pair of the versions it knows (each available version and each bound): D known
versions give D² facts, and every goal over `version_order` pays for all of them while #252 stands.
Only pairs of an available version of a package and a bound on that package are ever asked about,
so the resolver should assert those alone; that is the next change. The constraint rules are then
plain rules:

```patlang
rule satisfies(V, ge, Min) :- version_order(V, Min, gt).
rule satisfies(V, ge, Min) :- version_order(V, Min, eq).
rule satisfies(V, gt, Min) :- version_order(V, Min, gt).
rule satisfies(V, le, Max) :- version_order(V, Max, lt).
rule satisfies(V, le, Max) :- version_order(V, Max, eq).
rule satisfies(V, lt, Max) :- version_order(V, Max, lt).
rule satisfies(V, eq, W)   :- version_order(V, W, eq).

rule dep_candidate(Pkg, PVer, Dep, DVer) :-
    pkg_requires(Pkg, PVer, Dep, Op, Bound),
    pkg_available(Dep, DVer),
    satisfies(DVer, Op, Bound).
```

"Every constraint holds" is universally quantified, which Horn rules express through negation
(`not violates(...)`). `solve` has no negation as failure, so P1 checks it in PatLang: a version
meets all of a requirer's constraints when `dep_candidate` has as many solutions for it as the
requirer has constraints. That count is right only while each constraint met has exactly one proof,
so the manifest reader refuses a repeated constraint, a second `depends` line for one package and a
repeated package version. Putting `Op` and `Bound` in `dep_candidate`'s head would let the check
name each constraint met instead of counting; negation as failure would remove the loop. Which, if
either, is a decision for the owner.

### Choosing among candidates

Several versions may satisfy every constraint, and two packages may constrain one dependency
differently. One version of each package is installed in a program (includes resolve by path, and a
file included twice runs once), so the resolver needs one version per package satisfying every
requirer. Planner costs cannot say "one version per package, satisfying everyone", so the choice is
a search: packages are taken breadth first from the request, each gets the newest version every
requirer so far accepts, and the search backtracks when a later package is left with none.

The request is a requirer like any other, named `@request` (no package name can start with `@`),
with `>= 0.0.0` when no constraint is given. When no choice satisfies everyone, the resolver reports
every conflict, as the owner decided on 2026-11-08: each package for which some set of requirers
leaves no version, with those requirers, their constraints read back from `pkg_requires`, and the
versions available. A search that fails has tried every branch, so it collects each conflict it
meets on the way, once each (by package and set of requirers), and reports them all. P1 reports
only the first; reporting all of them is the next change.

Preferring versions already installed belongs to P2, where there is an installation to look at.

## Installation as a plan

Installation is a planning problem: the goal is `installed(Pkg, Ver)` for the requested package,
and the actions fetch, verify and install one package each, with each dependency's installation as
a precondition:

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

The actions are generated from the resolved facts, one set per candidate version. An install whose
effect already holds costs 0.

**Verify** checks the `file` hashes now, and the release certificate once package trust exists
(`package-trust.md`, T5): its effect `verified` is added only when the check passes, and a withdrawn
version is never offered as an action.

**Install** copies a verified package into an installation directory, keeping packages side by side
so the sibling includes between them (`include "../deflate/deflate.patlang"`) resolve. Where that
directory lives (per project, per user, or both) is a decision below.

Packages are included today, so every package's functions share one namespace with the program and
with each other. Once the language has modules (`docs/plans/future-work-program-as-closure.md`,
"Includes and modules"), a package's entry file becomes a module: a program imports it by name and
reaches its definitions qualified, a package's own files still `include` one another, and two
packages may define the same names. Modules may import each other in a cycle, resolved by name, so
packages keep the dependency cycles the resolver accepts today. A module's `export` list, with each
export's contract, is the package's interface: `pkg` can check that a release's version agrees with
how its exports' contracts changed (a stronger `require` or a weaker `ensure` needs a new major
version).

**Fetch** reads from a source. The first source is a checkout of this repository: fetching is a
copy from `packages/<name>/` at a given commit. Other sources (an archive over HTTP, another git
repository) come later, and each one only has to produce a package directory; verification never
trusts where a package came from.

## The `pkg` tool

A PatLang program compiled by v2, with the long-running program conventions (`status` and `quit`
signals, progress written to a file) since a fetch can be slow:

- `pkg resolve <name> [<constraint>]`: print the plan without acting;
- `pkg install <name> [<constraint>]`: resolve, fetch, verify, install;
- `pkg verify <dir>`: run `verify_manifest`'s checks, and the trust checks once they exist;
- `pkg list`: what is installed, with versions;
- the trust commands from `package-trust.md` (T3): `pkg genesis`, `pkg propose`, `pkg sign`,
  `pkg certify`.

## Format packages

The packages that make this worth doing, in roughly the order their dependencies allow:

| package | depends on | notes |
|---------|------------|-------|
| png | deflate | reader and writer; CRC-32 from deflate |
| bmp, ppm | none | the simplest graphics formats, useful for testing the others |
| jpeg | none | baseline decoder first; Huffman and DCT in PatLang |
| xlsx, docx | zip | Office Open XML: zip archives of XML; needs an XML reader package |
| xml | none | a reader first, for the Office formats |
| pdf | deflate | object syntax, cross-reference tables, Flate streams; reading text first |

Every format package is byte-level PatLang over `List<Int>`, with no host shortcuts, and is checked
against a Python oracle in its features like the existing three.

## Dependencies on other work

- **v2 speed** ([#238](https://github.com/PatParslow/PatLang/issues/238),
  [#239](https://github.com/PatParslow/PatLang/issues/239)): compiled by v2, SHA-256 runs at about
  1.1 MB/s, inflating takes about 0.5 µs a byte and deflating 2.5 to 5.5 µs. Verifying large packages, and the format packages
  on real files, need compiled code to be faster.
- **Integers modulo n** ([#251](https://github.com/PatParslow/PatLang/issues/251)): SHA-256, CRC-32
  and Adler-32 are word arithmetic mod 2^32 and 65521, written today with `band` and masks on tagged
  integers. With modular integers they become plain arithmetic, and signing for package trust can be
  PatLang.
- **The logic engine's speed** ([#252](https://github.com/PatParslow/PatLang/issues/252)): `rule_add`
  copies the whole rule store each call, and `solve` renames every rule of a goal's predicate before
  trying to unify it. The resolver's time is almost all there.
- **A string's UTF-8 bytes**: PatLang has no built-in giving them, so `packages/sha256/text.patlang`
  encodes them itself. A built-in, in both v2 engines, would serve every format package that writes
  text.

## Phases

| phase | builds | done when |
|-------|--------|-----------|
| P0 | layout, manifest, three packages, `verify_manifest` | done |
| P1 | manifest reader as facts; version order facts; `dep_candidate` and the every-constraint check | built 2026-11-08: features over 38 hand-written manifests and generated universes resolve, and report conflicts with their requirers (127 checks) |
| P2 | installation plans; fetch from a repository checkout; install side by side | `pkg install zip` installs deflate then zip into an empty directory, and a program including zip from there runs |
| P3 | the `pkg` tool with signals and progress | `pkg resolve`, `install`, `verify` and `list` pass their features; a `status` query answers during a fetch |
| P4 | trust (`package-trust.md` T1 to T5) | `pkg install` refuses a tampered or withdrawn package |
| P5 | format packages | each passes its features against its oracle |
| P6 | other sources | an archive over HTTP installs the same bytes as the repository source |

## Decisions for the owner

1. Where packages install: per project (a `packages/` beside the program), per user, or both with an
   order between them.
2. How the every-constraint check is expressed: counting `dep_candidate` solutions as now, `Op` and
   `Bound` in its head, or negation as failure in `solve`.
3. Whether two versions of one package may ever be installed side by side (today an include path
   names one directory, so not without a change to how includes resolve).
4. The order of the format packages.
5. Whether `pkg` records what it installed in a lock file, so a second install reproduces the first
   exactly.

Decided on 2026-11-08:

- Report every conflict.
- The rule store becomes an explicit value: `let kb = logic_new()`, passed to `rule_add(kb, ...)`
  and `solve(kb, ...)`, so one process can hold several stores and resolve as often as it likes.
  v2 keeps one store per process today, with no way to empty it, which is why P1's runner starts
  itself as a child process for each resolution; that goes once the store is a value. The change
  belongs with the store's rework in [#252](https://github.com/PatParslow/PatLang/issues/252) and
  the removal of ambient globals. The `rule ... :- ...` sugar takes its store from a lexical
  `using kb as logic do ... end` block ([#253](https://github.com/PatParslow/PatLang/issues/253)),
  resolved when compiling, never from a store chosen at run time.
