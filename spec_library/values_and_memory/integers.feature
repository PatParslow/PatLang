@language
Feature: an integer is an int exactly when it fits in 64 bits (spec 1.3)

  Scenario: the largest and smallest ints are ints
    Given 9223372036854775807 and 0 - 9223372036854775807 - 1
    When type_of is applied to each
    Then both are int

  Scenario: values between 2^47 and 2^63 are ints
    Given 140737488355327 + 10
    When type_of is applied
    Then it is int, and the value is 140737488355337

  Scenario: leaving the range gives a bigint, and coming back gives an int
    Given big = 9223372036854775807 + 1, and back = big - 1
    When type_of is applied to each
    Then big is bigint with value 9223372036854775808, and back is int with value 9223372036854775807

  Scenario: the same holds below the range
    Given low = 0 - 9223372036854775807 - 1 - 1
    When type_of is applied
    Then it is bigint, and low + 1 is int

  Scenario: integer division that divides evenly is an int
    Given 3 / 1, 6 / 4 and 2^70 / 2^69
    When type_of is applied to each
    Then they are int, rational and int

  Scenario: multiplication that overflows gives the exact bigint
    Given 4294967296 * 4294967296
    When it is evaluated
    Then it is bigint with value 18446744073709551616

  Scenario: dividing bigints is exact, and a gcd costs time growing as the square of the digits
    Given bigint dividends and divisors of many sizes, and consecutive Fibonacci numbers of about 50 and 200 digits
    When each is divided, and each Fibonacci fraction is reduced
    Then q * b + r gives back the dividend with the remainder smaller than the divisor, and the larger reduction costs at most 16 times the smaller

  Scenario: rational arithmetic is exact on small parts and large, ints and rationals mixed
    Given 399 pairs of random operands from a fixed seed: ints, and rationals with parts under 2^31 and past it, of both signs
    When each pair is added, subtracted, multiplied, divided and compared
    Then every result is what Python's fractions give for the same pair

  Scenario: arithmetic on rationals with parts under 2^31 costs a small part of the general path's
    Given 1/3 and 2/7, and 2147483659/3, whose part past 2^31 takes the general path
    When each of +, -, *, / and < is done 20000 times on 1/3 and 2/7, and on 2147483659/3 and 2/7
    Then each on the small parts costs at most a quarter of the same, the loop around it not counted, on the large part
