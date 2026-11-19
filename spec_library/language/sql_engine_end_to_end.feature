Feature: SQL engine (sql_parse/sql_execute over rdb_init())

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: CREATE TABLE makes a table that did not exist
    Given the program
      """
      include "{lib}/sql.patlang"
      let db = rdb_init()
      print(rdb_table_exists("people"))
      let db = sql_execute(db, sql_parse("CREATE TABLE people (name STRING, age INT)"), "0")[0]
      print(rdb_table_exists("people"))
      """
    When it runs interpreted and compiled
    Then both print
      """
      false
      true
      """

  Scenario: INSERT then SELECT ... WHERE filters correctly
    Given the program
      """
      include "{lib}/sql.patlang"
      let db = rdb_init()
      let db = sql_execute(db, sql_parse("CREATE TABLE people (name STRING, age INT)"), "0")[0]
      let db = sql_execute(db, sql_parse("INSERT INTO people VALUES ('alice', 30)"), "0")[0]
      let db = sql_execute(db, sql_parse("INSERT INTO people VALUES ('bob', 25)"), "0")[0]
      let sel = sql_execute(db, sql_parse("SELECT name FROM people WHERE age > 28"), "0")
      print(sel[1][2])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [[alice]]
      """
