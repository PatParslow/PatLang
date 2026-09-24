Feature: the refcounted heap is safe under real OS threads (GitHub issue #176)

  The design decision and its reasoning are in
  docs/plans/block-ownership-model-thread-safety.md. In short: refcount changes
  are atomic, the free list is behind a ticket lock, and the free-list table is
  the first heap allocation so a worker thread finds it without `get`, which the
  runtime forbids in spawned closures.

  Native only, checked by self_hosting/block_model/tools/thread_safety_check.sh
  (about three minutes, nearly all of it the native build). Races are
  probabilistic, so the check runs the executable five times and requires every
  run to be correct.

  Scenario: four threads hammering one shared block and the free list leave every count and block intact
    Given four real threads each doing 200000 increment/decrement pairs on a block the main thread also holds, then 20000 allocate, tag, read back and free cycles
    When the program is built as a native executable and run five times
    Then every run prints a shared count of 1 and zero wrong read-backs
