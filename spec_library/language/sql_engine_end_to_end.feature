Feature: SQL engine (sql_parse/sql_execute over rdb_init())

  Scenario: CREATE TABLE, guarded by require/ensure
    Given `require not rdb_table_exists("spec_people")` beforehand
    When `CREATE TABLE spec_people (...)` is executed via sql_parse+sql_execute
    Then `ensure rdb_table_exists("spec_people")` afterward passes -- the contract itself proves the table was actually created, not assumed

  Scenario: INSERT then SELECT ... WHERE filters correctly
    Given two inserted rows (alice age 30, bob age 25)
    When `SELECT name FROM spec_people WHERE age > 28` is executed
    Then exactly 1 row is returned, and it is alice

