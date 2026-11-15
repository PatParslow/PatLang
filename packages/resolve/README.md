# resolve

Chooses one version of each package from a set of manifests, using
PatLang's logic engine (`rule_add`, `rule ... :- ...`, `solve`). It is
phase P1 of `docs/plans/package-manager.md`.

```patlang
include "../packages/resolve/resolve.patlang"

let u = rs_universe_read(["packages/deflate", "packages/zip"])
let result = rs_resolve(u[1], rs_request("zip", "any"))
print(rs_result_text(result))      # resolved deflate 0.1.0, zip 0.1.0
```

## What it does

- `rs_manifest_read(path)` reads a `manifest.pkg` (format in
  `packages/README.md`) into `[name, version, summary, entry, includes,
  files, depends]`, or gives `["error", line, message]`; line 0 means a line
  the manifest lacks. Versions must be `MAJOR.MINOR.PATCH` with no leading
  zeros. A dependency's constraints all go on one `depends` line, none
  repeated; every `include` needs a `file` line and every `file` line must be
  an `include`.
- `rs_universe_read(paths)` reads manifests from `.pkg` files and
  directories (a directory's `manifest.pkg`, or else every `.pkg` in it), and
  refuses a package version given twice.
- `rs_resolve(manifests, [name, constraints])` asserts
  `pkg_available(Name, Ver)`, `pkg_requires(Pkg, PVer, Dep, Op, Bound)` and
  `version_order(A, B, lt|eq|gt)` for every pair of known versions and
  bounds (compared in PatLang), declares the `satisfies` and `dep_candidate`
  rules from the plan, and then chooses. The request is a requirer named
  `@request`; with no constraint it asks for `>= 0.0.0`.
- Choosing walks a breadth-first agenda from the request. Each package gets
  the newest version that every requirer so far accepts, and the search backs
  up when a later package has no version left. A version meets all of a
  requirer's constraints exactly when `dep_candidate` has as many solutions
  for it as the requirer has constraints, since each constraint it meets has
  exactly one proof.
- When nothing works, the result is the first conflict met: the package,
  each requirer with its constraints (read back from `pkg_requires`), and the
  versions available.

`rs_assert_facts` is the one function that calls `rule_add`.

## Specs and benchmark

```
./self_hosting/build/v2.exe packages/resolve/spec/run_spec.patlang packages/resolve/build/run_spec.exe --workers 2
./packages/resolve/build/run_spec.exe
```

The runner runs itself again as a child (`--resolve`, `--facts`) for every
step that asserts facts. `spec/oracle.py` (`py -3 -I`) generates universes,
resolves them with no logic engine, and checks choices and version_order
facts. `spec/bench.patlang` times one universe per run (`resolve <dir>
<name>`) and the version_order facts alone (`order <count>`).

Since #252 the logic engine indexes rules by predicate: `rule_add` pushes
in place, and a goal visits only its own predicate's rules, skipping one whose
head contradicts a constant in the goal. Asserting D known versions and bounds
still asserts D^2 `version_order` facts, one for each pair.

The facts go in the process's default rule store, which has no retraction, so
a process resolves once and the runner starts a child for each resolution.
Rule stores are now values (#255), so a store per resolution can replace that.
