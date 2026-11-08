Feature: list/string literals and indexing

  Scenario: A list literal is 0-based indexable
    Given `[10, 20, 30]`
    When indexed at 0 and 2
    Then the results are 10 and 30

  Scenario: A string is indexable too, returning a single-character string
    Given "hello"
    When indexed at 0 and 4
    Then the results are "h" and "o" -- each a STRING of length 1, not a raw character/byte value

  Scenario: Both lists and strings expose .length
    Given the same list and string
    When .length is read
    Then it is the real element/character count (3 and 5 respectively)

  Scenario: A feature file's text reaches its steps as the characters it holds, whatever their encoding length
    Given "café λ€😀", written in this file as UTF-8
    When indexed at 3, 5, 6 and 7
    Then the results are "é", "λ", "€" and "😀", and .length is 8

