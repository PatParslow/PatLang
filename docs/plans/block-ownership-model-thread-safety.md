# Block Ownership Model: thread safety of the refcounted heap

GitHub issue #176. Phase 14 of the full-language plan asked for a short design
note, in the Forks' own format, before any real-thread work: does refcounting
stay cheap and non-atomic, or does something have to change once real OS threads
run block-model code?

## What is actually at risk

Only `Box` is refcounted (`self_hosting/block_model/heap.patlang`), and Box is
native-x64-only, so the self-hosted interpreter has nothing to race on. Its
`budgeted` blocks run in fibers that are never concurrent, and its `parallel_map`
workers share only the immutable program (see `parallel_map.feature`). The risk is
in native builds that use `thread_spawn`.

Reading `heap.patlang` against the runtime found four hazards, three of them real:

1. **Refcount read-modify-write.** `bm_rc_inc` and `bm_rc_dec` loaded, added and
   stored. Two threads can both read 3 and both write 4, losing an update; a lost
   decrement leaks, a lost increment frees a live block.
2. **The free list.** Pop, push, and the claim of a new size-class slot were
   unsynchronised, so two threads could be handed the same block.
3. **Finding the free-list table.** Its address came from `get("__vars", ...)`.
   The runtime documents that a spawned closure must not call `set_var`/`get`
   because `g_vars_table` has no lock, and `thread_spawn` itself writes it (the
   thread-id counter), so a worker allocating a Box could read the table while the
   main thread spawned the next worker.
4. **`bm_rc_touch_for_mutation`** (check the count is 1, then write in place).
   This one is sound as written; see below.

The bump allocator underneath (`rt_heap_alloc`) was already atomic.

## The options

The plan named (a) atomic counts everywhere, (b) a separate thread-safe path only
for objects crossing a `thread_spawn` boundary, or (c) something else.

**(b) does not work here.** It needs the set of objects that cross a boundary to
be closed under reachability, and a Box payload is a raw 8-byte cell that can hold
a pointer to another Box with no type information to say so. A thread that reads
the inner pointer and shares it would then use the cheap non-atomic path on an
object both threads can reach. Marking transitively is not possible without types
this heap does not have.

**(a) is chosen**, with the two supporting changes that make it complete.

## Decision

- Refcount changes use `rt_atomic_fetch_add` (`lock xadd`). Exactly one thread sees
  a count reach zero and frees the block.
- The free list sits behind a ticket lock built from the same intrinsic (no
  compare-and-swap exists), taken across pop, push and slot claim only.
- Finding the free-list table depends on when the heap is initialised, and there
  are two arrangements, told apart by a marker word in the table header.
  1. **Table first (thread-safe).** When `bm_heap_init` runs before anything else
     has allocated, the table sits at `mem_heap_base()` and every thread finds it
     with no lookup. Native code the block-model generator builds gets this: its
     `main` starts with the heap init and it has no runtime class declarations.
  2. **Table later (single-threaded only).** A program that allocates first -- for
     example one with a top-level `class`, whose `class_def` runs at startup, such
     as the block-model engine compiled natively for its own tests
     (`self_hosting/lib/interp.patlang` declares `class Interpreter`) -- gets the
     table wherever the heap has room, found through `set_var`/`get` as before.
     That lookup is not thread-safe, so such a program must not spawn threads.
  The first version of this change required arrangement 1 and stopped with a
  message otherwise. Fifteen scenarios that run the engine natively hit the
  message, which is how the class-declaration case came to light; that is why
  arrangement 2 exists rather than a refusal.
- `bm_rc_get` and `bm_rc_touch_for_mutation` stay plain reads. A count of 1 means
  the calling thread holds the only reference, and a new reference can only be
  made from an existing one, so nothing can raise the count between the check and
  the in-place write. A count above 1 makes the caller clone, which is safe
  whatever other threads do.

This also keeps the ownership model's promise: a uniquely owned Box mutates in
place; a shared one is copied on write; a closure that captures a Box for a
thread takes a share (count 2), so neither side can mutate it in place.

## Cost

Ten million increment/decrement pairs on one block, single thread, native,
measured three times each with `bench/heap_rc_cost.patlang`: about 156 ms before,
about 208 ms after (roughly 2.6 ns per operation). That is the price paid on every
Box operation whether or not threads exist. It is small next to the work a Box
operation sits inside, and (b) could not be made correct.

## Evidence

`spec_fixtures/thread_safety_heap.patlang`, run by `tools/thread_safety_check.sh`
(built natively with `patc1.exe --x64`, run five times because races are
probabilistic). Four real threads do 200000 increment/decrement pairs each on one
shared block, then 20000 allocate/write/read-back/free cycles each. Before the
change the shared count came back as garbage (5369234655, want 1) and the second
phase crashed with a segmentation fault. After it, five of five runs print 1 and 0.

## Not covered

- `thread_spawn` from block-model source. Block-model closures are lists, while the
  x64 runtime's `thread_spawn` takes its own closure value, so block-model source
  cannot reach it yet. The fixture calls the runtime's `thread_spawn` directly.
- Any use of `set_var`/`get` from a worker. That remains forbidden by the runtime.
- Interpreter Box use, which does not exist.
