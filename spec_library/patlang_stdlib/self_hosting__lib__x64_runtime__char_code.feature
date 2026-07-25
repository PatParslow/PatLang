Feature: char_code (self_hosting/lib/x64_runtime.patlang)

  Scenario: Returns the ASCII code of the byte at idx
    Given "ABC"
    When char_code is applied with idx 0, then idx 2
    Then the results are 65 ('A') and 67 ('C')

