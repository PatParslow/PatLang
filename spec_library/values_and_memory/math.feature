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

  Scenario: to_int gives the int a whole number is
    Given an int, whole floats of either sign and zero, and floats of 2^62, 2^63, -2^63 and 1e20
    When a program applies to_int to each
    Then each is the int it is, a bigint from 2^63 up, and floor's float made an int indexes a list

  Scenario: to_int of a number that is not whole stops the program
    Given 2.5, an infinite float and a string
    When a program applies to_int to each
    Then each stops, saying to_int takes a whole number and naming what it was given

  Scenario: max and min of two numbers
    Given ints, floats, rationals and a bigint
    When a program applies max and min
    Then each gives the larger or the smaller, keeping its kind

  Scenario: to_num reads a rational as it prints
    Given the texts of fractions, signed and not, in lowest terms and not, and one with a bigint numerator
    When a program reads each with to_num
    Then each is the exact rational in lowest terms, or the int when it divides evenly, and a printed sum reads back as itself

  Scenario: an operation on two floats costs about what one on two ints does
    Given a loop of 200000 float additions and multiplications, and one of int ones
    When each runs three times
    Then the best float run takes no more than four times the best int run
