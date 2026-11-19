Feature: SQL/RDBMS test environment isolation (VFS-backed, not real disk)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: Table state does not leak across separate process runs
    Given the program
      """
      include "{lib}/sql.patlang"
      let db = rdb_init()
      print(rdb_table_exists("isolated_table"))
      let db = sql_execute(db, sql_parse("CREATE TABLE isolated_table (x INT)"), "0")[0]
      print(rdb_table_exists("isolated_table"))
      """
    When it runs interpreted and compiled
    Then both print
      """
      false
      true
      """

  The program runs twice, as two processes, and each leaves the table
  existing: each run starting with no such table is the isolation.

  Note: this isolation is automatic (VFS lives only in the current
  process's memory) UNLESS something calls vfs_flush_to_disk, which
  writes through to real files -- a test suite that ever calls that
  host function DOES need explicit real-file teardown; one that
  doesn't gets isolation for free.
