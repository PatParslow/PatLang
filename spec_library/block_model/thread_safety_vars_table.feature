Feature: g_vars_table is thread-safe under real OS threads (GitHub issue #198)

  Follow-up to #176 (the refcounted heap's own thread-safety fix) and #175/
  #178 (named-object classes/methods, which route EVERY `new("Class", "name")`/
  `send`/`get`/`set_var`/`obj.field` through this exact table -- the registry
  is a stated, deliberate part of the contract, per named_objects.feature,
  not an accident). docs/plans/block-ownership-model-thread-safety.md's own
  "What is actually at risk" section already named g_vars_table as unsafe,
  left unaddressed there because thread_spawn wasn't reachable from block-
  model source yet; #184 fixed that, making this reachable for real.

  g_vars_table's own ADDRESS was already fixed and compile-time-known
  (mem_vars_table_addr, a real global label) -- unlike the free list's own
  table, it never needed the "first allocation" workaround #176 built.
  What it never had was any synchronization around READING or WRITING its
  contents: two threads calling rt_ns_set/rt_ns_get/rt_ns_push (x64_runtime.
  patlang, backing set_var/get/send's own field store) or object_delete
  concurrently could lose a whole namespace or key outright (both see no
  table yet, both allocate one, one write overwrites the other), not just
  compute a stale value.

  Fixed the same way #176 fixed the free list: a ticket lock ([next_ticket:8]
  [now_serving:8], g_vars_lock, built from rt_atomic_fetch_add alone -- no
  compare-and-swap intrinsic exists), held across each of rt_ns_set/rt_ns_get/
  rt_ns_push/object_delete's own full body. This prevents CORRUPTION of the
  shared table structure -- it does not, and is not claimed to, make an
  arbitrary COMPOUND read-modify-write on one key atomic across two separate
  calls (`self.n = self.n + 1` is still a get then a set, two separate lock/
  unlock cycles, with no cross-call atomicity) -- the real engine makes no
  such promise either (named_objects.feature's own "the same exposure the
  real engine's library code already has").

  Checked by self_hosting/block_model/tools/thread_safety_vars_table_check.sh
  (races are probabilistic, so it runs the executable five times and
  requires every run correct). Each of 8 real threads, spawned via
  thread_spawn (#184) from ordinary block-model source, writes to its OWN
  distinct key 2000 times, reading it back after every write -- no
  contention on any single key, so this tests concurrent TABLE mutation
  (new namespace, new key, list growth) across threads, not single-key
  compound-op atomicity.

  Scenario: 8 threads each hammering their own distinct key in the shared vars table never lose or corrupt a read-back
    Given 8 real threads, each writing then immediately reading back its own key 2000 times, with no key shared between threads
    When the program is built as a native executable and run five times
    Then every run prints 1 (every thread's every read-back matched what it just wrote)
