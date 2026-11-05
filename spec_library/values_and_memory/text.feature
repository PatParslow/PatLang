@language
Feature: a program sees characters, whatever bytes they take

  Scenario: length, indexes, substr, char_code, chr and the string cursor count characters
    Given a string with characters of two, three and four bytes
    When a program measures, indexes and cuts it, and writes it to a file and reads it back
    Then each gives what the interpreter gives, and only byte_length and hash_string see its bytes
