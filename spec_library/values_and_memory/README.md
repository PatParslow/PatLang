# values_and_memory

Executable form of `docs/spec/values-and-memory.md`, written before the new
compiler and runtime (`docs/plans/memory-design-review.md`, decision 5).
Each scenario names the section it checks.

- `@language` scenarios (Part 1) must pass on the interpreter and on native
  code, with the same result.
- `@runtime` scenarios (Part 2) check the new version's runtime and
  compiler.

None of these files is wired into a runner yet. They are wired as the new
version is built, each one RED before the code that makes it pass.
`spec_library/language/` stays the standing gate for the current
compiler.
