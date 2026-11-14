Feature: the named-object contract (GitHub issue #178)

  `signal_wrap` in self_hosting/lib/signal_discovery.patlang is written in terms
  of named objects: `new("SignalProxy", name)`, `send(name, "set", key, value)`
  and `get(name, key)`, and its selftest reads the same objects back by name. The
  owner's decision on #178 is that this contract stays for existing callers, so
  block-model serves it rather than asking callers to switch to returned records.

  Fork B removed ambient state for a program's own globals, and that stays: those
  are threaded through `__globals`. Named objects were never part of `__globals` --
  like `fact`/`query` and the rule/goal/action stores (Phase 15, #177) they live in
  one process-wide registry outside it. Until now the lowerer refused `set_var`,
  `get`, `send` and a named `new` outright as a guard against reaching that
  registry by accident. Now that the registry is a stated part of the contract,
  the guard is replaced by a scenario proving the calls reach it and behave as in
  the real engine. (`set_var` and `get("__vars", key)` were the same registry
  under the reserved name `__vars`; v2 has no `set_var`, so they are not here.)

  The engine's own bookkeeping uses `__vars` keys prefixed `bm_`; a program that
  sets one of those names deliberately can disturb the engine, which is the same
  exposure the real engine's library code already has.

  Scenario: named objects behave exactly as under the real engine
    Given a function that creates two named objects, sets and reads their properties, and reads an unset property
    When it runs through bm_lower_program/bi_run
    Then it prints the same four values as the v2 interpreter does for the identical source

  `object_delete(name)` is a real host function the shared host table does not
  serve, so it joins the block-model host extension table (#159). zs_explore's
  breadth-first search keeps its visited set in a named Dict, so exploration stays
  as cheap as under the real engine: a hash lookup per state, not a scan (issue #179).

  Scenario: object_delete drops a named object exactly as under the real engine
    Given a function that creates a named Dict, sets a key, reads it, deletes the object and reads the key again
    When it runs through bm_lower_program/bi_run
    Then it prints 1, true and bool, as the v2 interpreter does for the identical source
