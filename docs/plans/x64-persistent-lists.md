# Native x64 lists as persistent arrays

GitHub issues #145 (list_push/list_set mutate shared storage) and #113 (list `==`
compares by identity). Both were gates the Block Ownership Model plan set for the
cutover (#180), and both live in the native runtime, which the block-model native
output links, so fixing them there fixes both pipelines.

## What was wrong

The interpreter treats a list as a value. Native x64 did not:

- `list_push` wrote into the buffer and bumped its length whenever there was spare
  capacity, and `list_set` wrote the element in place. Anyone holding another copy
  of the same list saw the change. `let e = a; let f = list_set(a, 0, 99)` changed
  `e`, and after a loop of pushes `let b = a; let c = list_push(a, 999)` made `b`
  one element longer. Both were deliberate speed trade-offs, recorded as "only
  probably safe" in the code: a copying push made accumulating loops quadratic (a
  self-compile burned 20 CPU-minutes), and a copying `list_set` made the linker's
  per-byte relocation patching exhaust the heap (#89).
- `==` on two lists fell through to comparing the pointers, so equal lists compared
  unequal (#113).

## Why not the obvious fixes

There are no reference counts and no collector. Always copying on write is sound but
each element write in a loop then allocates a whole new buffer that is never freed:
`vt100` (56 `list_set` sites), `inflate` (22) and `image` (12) would run out of heap.
Deciding at compile time which lists are unshared needs an alias analysis over the
whole compiler, and marking lists as shared at every copy makes a call such as
`helper(xs)` inside an accumulating loop turn every later push into a copy.

## The representation

A list value is a tagged pointer to a 48-byte version node
`[len][kind][buf][idx][val][next]`; `len` sits at offset 0 in every kind, so the
inline `.length` path is unchanged.

- **ARR**: the newest version over a buffer `[cap][spare][elements]`. Exactly one
  ARR node exists per buffer. Reads and writes go to the buffer.
- **SET**: an older version, equal to `next` except that element `idx` is `val`.
- **TRUNC**: an older version, the first `len` elements of `next`.

A push or set on the newest version updates the buffer in place, allocates a new
ARR node, and rewrites the node it replaced as a SET or TRUNC diff pointing at the
new one. Every other holder of the old node keeps reading the old contents by
following the diffs. A write to an older version copies it into a fresh buffer,
applying the diffs, and works on the copy. That is the interpreter's meaning of a
list without counting references, and an accumulating or patching loop stays O(1)
per step. `rt_list_set` (write into a fresh list's buffer) is unchanged and is what
`image` and `inflate` use as an explicit mutable array.

The diff and the kind flip are written before the buffer element changes, so a
reader that still sees the old kind sees consistent data. Two threads writing the
same list are not synchronised, as before.

## Equality

`rt_dynamic_cmp_obj` compares two lists structurally: same length, and each pair of
elements equal under the same dynamic `==` a scalar comparison uses. Nested lists
recurse, numbers follow the numeric tower, strings compare by content. Ordering
lists stays false; objects and closures stay identity.

## Evidence

`spec_library/language/x64_list_semantics.feature` runs each fixture under
`pat --ir-run` and compiled with `patc1 --x64` and compares the outputs line for
line: eleven equality cases, the two repros from #145, an older list pushed to twice,
a set on a stale version, and 6000 deterministic random steps of copy, push, set and
read over eight aliased lists, with every read and the final contents in the output.
Against the previous runtime the repros print `[99, 20]` twice and `21` twice and the
walk differs; against this one all match.

Cost, native, three runs each (`bench/list_native_cost.patlang`, milliseconds):

| | before | after |
|---|---|---|
| 2,000,000 accumulating pushes | 47 | 109-125 |
| 2,000,000 indexed reads | 32 | 31-47 |
| 1,000,000 `list_set` on a 100,000-element list | 15 | 47-63 |

A write costs about 50 ns instead of 15-23 ns and 48 bytes for the node; reads are
unchanged within noise. Reading an old version costs one step per diff between it and
the newest, which is small unless a program alternates between a version and one
many writes later.

## Not covered

Reading a list through a very long chain of diffs is linear in the chain. Concurrent
writes to one list from several threads are not synchronised. Native `%` on a bigint
exits with a heap failure (#185), found while writing the walk fixture and unrelated
to lists.
