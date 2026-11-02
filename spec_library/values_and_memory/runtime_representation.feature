@runtime
Feature: a value is a type word and a data word (spec 2.1)

  Scenario: an int's data word holds all 64 bits
    Given the int 9223372036854775807 in a local
    When its two words are read with the runtime's word accessors
    Then the type word names int, and the data word is 9223372036854775807

  Scenario: a float's data word is its IEEE bits, with no heap block
    Given 1.5 stored into a list and read back, a million times in a loop
    When the heap's bytes in use are compared before and after
    Then they are the same, and the value read back is 1.5

  Scenario: telling kinds apart reads only the type word
    Given a string literal, a heap string, an int whose bits look like a pointer, and a float
    When type_of is applied to each
    Then they are string, string, int, float, with no address range checked

  Scenario: a list slot is two words
    Given a list of 1000 ints
    When the list's buffer size is read
    Then it is 1000 slots of 16 bytes, plus the header

  Scenario: an operator with no handler tests one flag
    Given a function adding two ints in a loop, with no handler registered for any event
    When its generated code is inspected
    Then the addition is the machine add, and at most one flag test guards an event, none where the compiler can see that no handler exists
