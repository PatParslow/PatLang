@language
Feature: a program sees characters, whatever bytes they take

  Scenario: length, indexes, substr, char_code, chr and the string cursor count characters
    Given a string with characters of two, three and four bytes
    When a program measures, indexes and cuts it, and writes it to a file and reads it back
    Then each gives what the interpreter gives, and only byte_length and hash_string see its bytes

  Scenario: let s = s + x gives a new value, and leaves what else holds the old string alone
    Given strings also held by another variable, a list, a closure and a caller
    When a program appends to them with let s = s + x
    Then what else holds each old string still sees it, and numbers and multi-byte characters add as ever

  Scenario: appending to a string nothing else holds does not copy all of it each time
    Given a loop of let s = s + x, at 100,000 and at 200,000 appends
    When a program times them
    Then twice the appends take no more than about three times as long
