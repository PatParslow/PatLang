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

  Scenario: no program keeps its state in globals
    Given every PatLang file but the old runtime's own and the fixtures testing set_var as a language feature
    When its code is searched for set_global, get_global, set_var and reads of __vars
    Then there are none

  Scenario: a caller depends on its callee's summary, not its body
    Given a program whose function f calls g
    When g's body changes without changing its ownership summary
    Then f's compiled artefact is reused unchanged

  Scenario: a reused artefact counts as just used
    Given two functions' artefacts, the first stored before the second
    When the first is reused by a later build
    Then the second is now the less recently used

  Scenario: artefacts are evicted only when asked, least recently used first
    Given a store of three jobs, the first used most recently, of more than the size asked for
    When eviction is asked for with that size
    Then whole jobs go, least recently used first, until the store fits, and a larger size removes nothing

  Scenario: a partly written artefact is rebuilt, never used
    Given a built program whose function's stored code, assembly or record is then cut short
    When the program is built again
    Then that function is built again, and the program runs

  Scenario: registrations are recorded, not rediscovered
    Given a program with a when handler, a rule, and a function reached only through apply
    When it is compiled
    Then the program facts list all three, and no stage scans for them

  Scenario: sequential and parallel builds are identical
    Given the same input compiled once with one worker and once with eight, with the ready order shuffled
    When the two executables are compared
    Then they are byte-identical

  Scenario: a file is included once
    Given a program whose two included files both include a third
    When it is compiled and run
    Then the third file's statements run once, before the files that include it

  Scenario: a build that fails says so in its exit code
    Given a program that does not parse
    When it is compiled
    Then the compiler prints the error, exits non-zero, and writes no executable

  Scenario: synthesized names come from their declaration
    Given two functions each containing a closure and a loop
    When they are compiled in either order
    Then each synthesized name is its declaration's name plus a counter local to it

  Scenario: a frame many pages long runs
    Given a program with three thousand functions reached by name
    When it starts, registering them all from one function
    Then it runs, the stack committed a page at a time
