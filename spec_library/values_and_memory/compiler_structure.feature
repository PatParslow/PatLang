@runtime
Feature: one compiler, stages as jobs, no special cases (spec 2.5)

  Scenario: the runtime is compiled like any program
    Given the new runtime's source
    When it is compiled
    Then it goes through the same stages as a user program, with no runtime-only branch in any stage

  Scenario: a built-in class's method is declared in PatLang (spec 1.2)
    Given the runtime's source
    When the declaration of int's to_s is looked for
    Then it is a PatLang method declaration in int's class, not a name the compiler recognises

  Scenario: no stage touches shared mutable state
    Given every compiler stage
    When its source is searched for __vars reads and writes
    Then there are none: each takes input artefacts and produces one output artefact

  Scenario: a caller depends on its callee's summary, not its body
    Given a program whose function f calls g
    When g's body changes without changing its ownership summary
    Then f's compiled artefact is reused unchanged

  Scenario: registrations are recorded, not rediscovered
    Given a program with a when handler, a rule, and a function reached only through apply
    When it is compiled
    Then the program facts list all three, and no stage scans for them

  Scenario: sequential and parallel builds are identical
    Given the same input compiled once with one worker and once with eight, with the ready order shuffled
    When the two executables are compared
    Then they are byte-identical

  Scenario: synthesized names come from their declaration
    Given two functions each containing a closure and a loop
    When they are compiled in either order
    Then each synthesized name is its declaration's name plus a counter local to it
