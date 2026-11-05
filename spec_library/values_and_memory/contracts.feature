@runtime
Feature: the runtime and compiler state their contracts (spec 2.4)

  Scenario: every runtime function states its contract
    Given the runtime's source
    When each function's declaration is read
    Then each has require and ensure clauses covering its ownership behaviour and its representation invariants

  Scenario: a broken ownership contract stops at the call that broke it
    Given a runtime function changed to return a borrowed argument without a reference of its own
    When a program calls it
    Then the program stops at that call, naming the broken ensure clause, before anything is released twice

  Scenario: a broken representation contract stops where it was broken
    Given a value built with a type word naming no class, or with a heap type word and a freed block in its data word
    When it is passed to a function requiring a live value
    Then the program stops at that call, naming the require clause

  Scenario: contracts are checked in every build
    Given a program whose function has a require clause it breaks, built in the default way and in every other build mode
    When each build runs
    Then each stops at that call, naming the clause

  Scenario: whether contracts are checked is one setting
    Given the compiler and runtime sources
    When they are searched for what decides whether a require or ensure is checked
    Then exactly one place reads that setting, and no contract refers to it

  Scenario: every compiler stage states its contract
    Given each compiler stage's job function
    When its declaration is read
    Then it requires well-formed input artefacts and ensures a well-formed output artefact

  Scenario: a match no case takes stops the program
    Given a match no case takes
    When the program is built and run
    Then it stops at the match, naming the function, with a non-zero exit code
