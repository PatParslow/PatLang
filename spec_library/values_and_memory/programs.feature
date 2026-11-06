@language
Feature: what functions, commands and includes give (spec 1.13)

  Scenario: a function that ends without return gives the value of its last statement
    Given functions ending in an expression, a call, a let, an if, a while, and nothing
    When each is called
    Then each gives what spec 1.13 says, and an if or while that ran nothing gives unit

  Scenario: exec_capture gives what a command wrote to both of its outputs
    Given a command that writes to standard error and to standard output
    When exec_capture runs it
    Then it gives both

  Scenario: a file reached by two includes is included once
    Given a program whose two included files both include a third
    When it runs
    Then the third file's statements run once, before the files that include it

  Scenario: a program's function may have a name the runtime has
    Given a program defining to_s, list_len and emit
    When it calls them directly, from a closure and by name
    Then each call reaches the program's function, and the runtime goes on using its own

  Scenario: two of a program's files defining one name is an error
    Given a program and a file it includes that define one function name
    When the program is given
    Then both engines report that the name is declared twice, and nothing runs
