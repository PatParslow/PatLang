Feature: Windows findstr Command (native, literal substring search within a file)

  Scenario: A line containing the literal search string is printed
    Given a file containing the line "PATLANG_MARKER_PRESENT here" among other lines
    When the user runs findstr "PATLANG_MARKER_PRESENT" on that file
    Then the matching line is printed verbatim

  Scenario: No match produces no matching line in the output
    Given the same file, with a search string that appears nowhere in it
    When the user runs findstr with that absent string on the same file
    Then the output does not contain the absent marker text

