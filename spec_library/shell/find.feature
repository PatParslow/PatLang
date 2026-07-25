Feature: Windows find.exe (System32) -- literal string search within text files

  Scenario: A line containing the literal search string is printed
    Given a file containing the line "PATLANG_MARKER_PRESENT here" among other lines
    When the user runs find "PATLANG_MARKER_PRESENT" on that file
    Then a "---------- <FILENAME>" header line is printed first, followed by the matching line verbatim (confirmed by direct fresh execution, not just this probe's own internal check)

  Scenario: No match prints only the header, no matching line
    Given the same file, with a search string that appears nowhere in it
    When the user runs find on that file
    Then only the "---------- <FILENAME>" header is printed; the output does not contain the absent marker text

