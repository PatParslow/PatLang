Feature: SQL/RDBMS test environment isolation (VFS-backed, not real disk)

  Scenario: Table state does not leak across separate process runs
    Given a table created and left existing at the end of one process's run
    When a SEPARATE, later process checks whether that table exists
    Then it reports false -- each --ir-run invocation starts with a genuinely clean table namespace, confirmed empirically rather than assumed from the implementation

  Note: this isolation is automatic (VFS lives only in the current
  process's memory) UNLESS something calls vfs_flush_to_disk, which
  writes through to real files -- a test suite that ever calls that
  host function DOES need explicit real-file teardown; one that
  doesn't gets isolation for free.

