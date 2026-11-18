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

  Scenario: chr of anything but an int stops the program
    Given chr of a float
    When the program runs
    Then it stops at chr, naming the require clause

  Scenario: bytes that are not well-formed UTF-8 are each a character U+FFFD, and nothing reads past the end
    Given text read from files holding a lead byte at the end, a three-byte character cut short, an overlong slash, a stray continuation byte, an encoded surrogate, a code past U+10FFFF, and well-formed two- and four-byte characters
    When a program measures each, reads every character's code, cuts past the end, and reads it through the cursor
    Then each byte that starts no well-formed sequence is one character with code 65533, the well-formed ones decode as ever, and the bytes are kept

  Scenario: chr of a surrogate code stops the program
    Given chr of 55295 and then of 55296
    When the program runs
    Then the first is one character, and it stops at the second, naming the require clause

  Scenario: sed replaces literal matches of its pattern
    Given sed commands with and without g and i, with no match, an empty pattern, no replacement, an empty replacement, flags after a slash, characters of two bytes and an int as input
    When each is applied
    Then each gives what spec 1.10 says

  Scenario: str_hash gives an int from a string's bytes
    Given the empty string, a single letter, two equal strings built differently, a non-ASCII string, and 1000 different names
    When str_hash hashes each
    Then the empty string and the single letter give FNV-1a's values, equal strings hash equal, the non-ASCII one hashes its UTF-8 bytes, and the 1000 hashes are different

  Scenario: str_contains says whether text holds a needle
    Given text of plain and of two- and three-byte characters, a needle at its start, middle and end, a needle it lacks, an empty needle, and a needle longer than the text
    When str_contains looks for each
    Then it is true where the text holds the needle, the empty needle included, and false elsewhere
