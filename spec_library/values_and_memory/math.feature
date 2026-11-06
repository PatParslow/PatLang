@language
Feature: powers, trigonometry, rounding, bits and the small file functions

  Scenario: each gives the same value under every engine
    Given powers of exact and float numbers, trigonometric functions, the rounding functions, abs, to_fixed, the bit functions, len, byte_length, hash_string, try_read_file, rename_file, copy_file and read_file_b64
    When a program prints each
    Then it prints what the interpreter prints

  Scenario: bnot gives an int's bitwise complement
    Given ints that are zero, positive, negative and the largest there is
    When a program applies bnot to each
    Then each gives minus the int minus one, as an int

  Scenario: bnot of anything but an int stops the program
    Given a float
    When a program applies bnot to it
    Then the program stops, reporting the float's class

  Scenario: max and min of two numbers
    Given ints, floats, rationals and a bigint
    When a program applies max and min
    Then each gives the larger or the smaller, keeping its kind
