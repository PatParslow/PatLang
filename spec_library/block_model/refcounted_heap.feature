Feature: standalone reference-counted heap (Block Ownership Model, Fork D)

  Fork D (docs/plans/block-ownership-model.md, section 6) decided refcounting
  does both jobs with one field: an ownership/exclusivity check, and real
  memory reclamation. This phase proves both jobs standalone, on the native
  x64 backend, with no block/jump execution machinery and no `mut` parameter
  syntax involved yet -- see this feature's own native check program
  (self_hosting/block_model/refcounted_heap_native_check.patlang) for why
  these scenarios run through the native pipeline directly rather than
  through self_hosting/lib/test.patlang's interpreter-based Gherkin runner.

  Scenario: a fresh allocation starts at refcount 1
    Given a freshly allocated block
    When its refcount is read
    Then the refcount is 1

  Scenario: copying a reference increments the refcount
    Given a freshly allocated block
    When the reference is copied and the copy is registered
    Then the refcount is 2

  Scenario: dropping one of two references leaves the other refcount at 1
    Given a block with refcount 2
    When one reference is dropped
    Then the refcount is 1

  Scenario: dropping the last reference makes the block reusable
    Given a block whose only reference is about to be dropped
    When that reference is dropped
    Then a later allocation of the same size reuses the freed block's address

  Scenario: many alloc-and-drop cycles of the same size do not grow the heap
    Given a free list already warmed up by one prior allocate-then-drop cycle of a fixed size
    When 100000 further allocate-then-drop-last-reference cycles run for that size
    Then the underlying heap's high-water mark shows zero further growth, not growth proportional to the cycle count

  Scenario: mutation at refcount 1 is safe in place
    Given a block with refcount 1
    When a mutating operation is attempted
    Then the ownership check reports "in place"

  Scenario: mutation at refcount 2 is not safe in place
    Given a block with refcount 2
    When a mutating operation is attempted
    Then the ownership check reports "clone first"
