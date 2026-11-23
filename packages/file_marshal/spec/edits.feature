Feature: file_marshal edits: a change given by its context, and the shift it makes
  An edit names what comes before the part to change (P) and what comes after
  it (S), and gives what the part becomes (Z); it may give the old part (X) and
  a position (N) where it expects the context. Text and flat binaries are both
  edited as bytes. An edit that applies says where it changed and by how much,
  so positions given for the file before it can be carried past it.

  Scenario: a text edit replaces what lies between its contexts
    Given the text "the curly haired dog sat"
    When the part between "the curly " and " dog" becomes "furry"
    Then the text is "the curly furry dog sat"
    And the shift is at 10, 6 bytes removed and 5 inserted

  Scenario: the old part, when given, must be what is there
    Given the text "the curly haired dog sat"
    When the part "haired" between "the curly " and " dog" becomes "furry"
    Then the text is "the curly furry dog sat"
    When the part "bald" between "the curly " and " dog" becomes "furry"
    Then the edit is refused, saying the part between is "furry", not "bald"

  Scenario: a context that is not there, or is there twice, is refused
    Given the text "a cat, a dog, a cat"
    When the part between "a " and ", a dog" becomes "cow"
    Then the text is "a cow, a dog, a cat"
    When the part between "a " and " fish" becomes "cow"
    Then the edit is refused, saying its context is not found
    When the part between ", a " and "" becomes "bird"
    Then the edit is refused, saying its context is found 2 times, at 5 and 12

  Scenario: in a flat binary the context need be unique only near the position given
    Given 4096 bytes in which the bytes 1 2 3 and 7 8 9 come at 100 and again at 3000, with 4 5 6 between them
    When the bytes between 1 2 3 and 7 8 9 near 2990, within 64, become 0 0
    Then the bytes at 3000 are 1 2 3 0 0 7 8 9, and those at 100 are as they were
    And the shift is at 3003, 3 bytes removed and 2 inserted
    When the bytes between 1 2 3 and 7 8 9 are changed with no position
    Then the edit is refused, saying its context is found 2 times, at 100 and 3000

  Scenario: an edit that knows its place takes the candidate nearest it, in text that repeats
    Given the text "x. x. x. x."
    When the part "x" between ". " and "." near 5, within 20, nearest it, becomes "y"
    Then the text is "x. x. y. x."
    When the part "x" between ". " and "." near 4, within 20, nearest it, becomes "z"
    Then the edit is refused, saying its context is found 2 times, at 1 and 7

  Scenario: a position is carried past an edit, or reported as inside it
    Given the shifts [10, 6, 5] and then [2, 0, 4]
    Then position 3 becomes 7, position 20 becomes 23, and position 0 stays 0
    And position 12 is inside the first edit

  Scenario: a batch applies every edit or none, each hint moved by the ones before it
    Given 4096 bytes in which the bytes 1 2 3 and 7 8 9 come at 100 and again at 3000, with 4 5 6 between them
    When a batch inserts 10 bytes after the first 1 2 3, then changes the 4 5 6 near 3000, within 4, to 0
    Then both apply, the second found at 3013 because its hint was moved by 10
    When a batch makes a good edit and then one whose context is not found
    Then the batch is refused, naming the second edit, and the bytes are as they were

  Scenario: an edit near the end of a large file costs about what one near its start does
    Given a text of 1 MB with one line near its start and one near its end that each say "here"
    Then changing the one near the end, with its position given, takes at most three times as long as changing the one near the start, the cheapest of three runs each
