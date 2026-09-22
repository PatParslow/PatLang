Feature: an explicit object handler for deliberate naming (Block Ownership Model, Fork B)

  The other half of Fork B's resolution (section 6): the deliberate-naming
  minority of today's `new`/`send` (a fixed, meaningful name with no
  counter, e.g. `zs_registry()`) gets an explicit, ordinary object
  handler -- a plain value passed around like any other parameter, not a
  hidden runtime primitive. Contrasted directly with
  globals_elimination.feature: a handler is NOT auto-threaded the way
  "__globals" is -- it has to be passed explicitly, because its own scope
  is a deliberate choice, not automatically program-wide. (The other,
  ephemeral majority of that same fork needs nothing further here: this
  engine's own Box, since Phase 1, was designed with no name parameter at
  all, so two independently created boxes were already, unconditionally,
  independent -- there was never a collision to fix.)

  Scenario: two names registered in the same handler resolve independently
    Given a handler with two different names registered to two different values
    When both names are looked up, after the handler was passed to another block explicitly
    Then each name resolves to its own value, not the other's
