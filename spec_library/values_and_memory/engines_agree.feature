@language
Feature: the interpreter and native code are one language (spec 1.7)

  Scenario: every @language scenario gives the same result on both engines
    Given each @language scenario in spec_library/values_and_memory
    When it runs under the interpreter and as a native executable
    Then both pass, with the same printed output

  Scenario: a program gives the same result in any directory
    Given a program whose calls rely on the runtime's declarations: exec_capture, apply and send
    When it is started in a directory other than the repository
    Then both engines print what those calls give

  Scenario: a program file that cannot be read is an error
    Given a path with no file at it
    When that path is given as the program
    Then both engines report that it cannot be read

  Scenario: an included file that cannot be read is an error
    Given a program that includes a path with no file at it
    When that program is given
    Then both engines report that the include cannot be read, and nothing of the program runs
