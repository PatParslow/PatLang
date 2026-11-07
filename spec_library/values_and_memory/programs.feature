@language
Feature: what functions, commands and includes give (spec 1.13)

  Scenario: a function that ends without return gives the value of its last statement
    Given functions ending in an expression, a call, a let, an if, a while, and nothing
    When each is called
    Then each gives what spec 1.13 says, and an if or while that ran nothing gives unit

  Scenario: the name unit is the unit value, unless the program binds it
    Given a program that writes unit, and binds unit as a parameter and as a variable
    When it runs
    Then unit is the value a function with no statements gives, and a bound unit is the program's own

  Scenario: exec_capture gives what a command wrote to both of its outputs
    Given a command that writes to standard error and to standard output
    When exec_capture runs it
    Then it gives both

  Scenario: exec_peak_memory gives a command's output and its peak memory
    Given a command that writes to both outputs, once exiting 0 and once exiting 3
    When exec_peak_memory runs each
    Then it gives standard output, standard error only from the failure, and a peak above 0

  Scenario: the runtime has the stage-0 shims
    Given add, multiply and subtract of ints and of rationals, and calculate, calculate_result, get_value, process and validate of an int, a string and a list
    When each is called
    Then add, multiply and subtract give the sum, product and difference, and the others give 0 or true

  Scenario: progress_report keeps the latest status, and plan_incremental and action_clear work on the actions
    Given a status read before any report and after two, and a one-action plan found with plan and with plan_incremental, then the actions cleared
    When the program runs
    Then the status is empty, then the second report; both plans are the action, and after action_clear there is no plan

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
