Feature: first-class closures (GitHub issue #182)

  A closure literal, `|params| { body }`, was rejected by `bm_lower_expr` as an
  unsupported expression shape. Closures are the common blocker for methods
  (#175), `budgeted` (#176) and `activate`/`action_bind` (#177), so they are
  built first.

  Semantics, checked against `pat --ir-run` rather than assumed: a closure
  captures a SNAPSHOT of the enclosing scope BY VALUE at creation -- a later
  rebinding of a captured variable is not seen (`let snap = 100; let show =
  |u| { return snap }; let snap = 200` then `show(0)` is 100). By-value capture
  is exactly what Fork B's value semantics already give, so it needs no new
  ownership rule.

  Design, reusing what the engine already has. A closure is the list
  `["__closure", <block name>, [captured values...]]`. Creating one synthesizes
  a function block `__closure_N` taking `(__captured, params..., __globals)`,
  whose prologue unpacks each captured name with `list_get`; the captured set
  is the body's free variables (the free-variable analysis gained a `Closure`
  case, so an enclosing loop forwards a variable used only inside a closure)
  intersected with the names the enclosing function binds. An expression cannot
  hand a new block back to its caller, so synthesized blocks go in a
  compile-time registry that `bm_lower_program` drains -- the pattern
  `bm_class_registry` already uses. A call `f(a, b)` where `f` is a parameter or
  `let` of the current function lowers to `apply(list_get(f, 1), list_get(f, 2),
  a, b)`, reusing `CallDynamic` (#153); a local shadows a declared function of
  the same name, as in the real engine.

  One thing the shared analysis had wrong: a call's CALLEE name is not a `Var`
  node, so a closure held in a local and only ever CALLED was never counted as a
  variable reference -- not captured by a closure that calls it, and not
  forwarded through a loop that calls it. The callee name is now treated as a
  variable reference; every caller intersects the analysis with the enclosing
  scope, so declared and host function names simply drop out.

  Interpreter only: native `CallDynamic` dispatches over declared functions and
  does not include synthesized closure blocks, so closures under native/WASM are
  a follow-up.

  Scenario: closures capture, return, pass and call each other, matching the real engine
    Given a program capturing an enclosing local, returning a closure from a function, passing a closure as a parameter, rebinding a captured variable after capture, and calling a closure from a closure
    When it runs through bm_lower_program/bi_run
    Then every printed value of the closure program matches exactly what pat --ir-run produces for the identical source

  Scenario: a loop captures a variable used only inside a closure it creates, and a closure used only as a callee
    Given a loop whose body creates a closure over one outer variable and calls another closure held in a local
    When it runs through bm_lower_program/bi_run
    Then the total matches exactly what pat --ir-run produces for the identical source
