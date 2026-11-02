@runtime
Feature: PatLang manages its own memory, per thread (spec 2.3)

  Scenario: no system call per allocation
    Given a program making a million small allocations within 100 MB
    When its system calls for memory are counted
    Then there is one reservation and at most one commit

  Scenario: a freed block of any size is reused by its size class
    Given a string grown one character at a time to 4000 characters
    When the heap's bytes in use are read
    Then they are a few times the final string's size, not the sum of every version

  Scenario: a thread allocates and frees without a lock
    Given 8 threads, each allocating and freeing a million blocks of its own
    When the shared pool's lock is counted
    Then it was taken at most once per batch, never per block

  Scenario: a block freed on another thread is reused there
    Given thread A making blocks that thread B releases
    When thread B then allocates blocks of the same size class
    Then it reuses A's freed blocks, taking no lock per block

  Scenario: imbalance moves in batches
    Given thread A only allocating and thread B only releasing, for a million blocks
    When the run ends
    Then A's memory came partly from batches B handed back, and the peak stays within twice the live data

  Scenario: freed memory stays with PatLang
    Given a program that allocates 500 MB, frees it, then allocates 500 MB again
    When its committed memory is read
    Then it is about 500 MB, not 1 GB, and nothing was returned to the system
