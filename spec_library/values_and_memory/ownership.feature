@runtime
Feature: five ownership rules, and no others (spec 2.2)

  Scenario: a call returns a value its caller owns
    Given a runtime function returning one of its arguments unchanged
    When it is called with a fresh string and the caller releases its own copy of the argument
    Then the returned string is still readable, and its count is 1

  Scenario: a copy of a local takes its own reference
    Given s = "a" + "b", t = s, then s is rebound
    When t is read
    Then it is "ab"

  Scenario: a structure owns what it holds, and releases it when freed
    Given a list holding a fresh string, the only reference to that string
    When the list is released
    Then the string's block is back on its free list

  Scenario: overwriting a slot releases what it held
    Given an object field holding a fresh string, overwritten with another
    When the first string's count is read
    Then its block has been freed

  Scenario: an inline value has nothing to count
    Given an int, a float, a bool and unit
    When each is retained and released ten times
    Then no heap block is touched and no count changes

  Scenario: every ownership fact the compiler uses comes from these rules
    Given the compiler's source
    When it is searched for lists of runtime function names
    Then there are none: each function's ownership summary is derived from its own source
