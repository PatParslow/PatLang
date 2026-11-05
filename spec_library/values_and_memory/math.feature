@language
Feature: powers, trigonometry, rounding, bits and the small file functions

  Scenario: each gives the same value under every engine
    Given powers of exact and float numbers, trigonometric functions, the rounding functions, abs, to_fixed, the bit functions, len, byte_length, hash_string, try_read_file, rename_file, copy_file and read_file_b64
    When a program prints each
    Then it prints what the interpreter prints
