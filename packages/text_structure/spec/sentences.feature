Feature: text_structure sentences: Unicode's sentence boundaries (UAX #29)
  Sentence boundaries follow UAX #29 section 5 over the Sentence_Break values of
  Unicode's data. Unicode's own conformance test, SentenceBreakTest.txt, marks
  where each of its strings breaks; every one of its lines must give exactly
  those breaks.

  Scenario: the table is made from Unicode 18's data, with every class
    Given the sentence-break table
    Then it says it was made from SentenceBreakProperty-18.0.0.txt
    And full stop is ATerm, question mark STerm, comma SContinue, "a" Lower, "A" Upper, "5" Numeric, a space Sp, a line feed LF, a no-break space Sp, the Hebrew letter alef OLetter, U+0308 Extend, and U+10FFFF Other

  Scenario: every line of Unicode's conformance test gives the breaks it marks
    Given the lines of SentenceBreakTest.txt
    Then each gives exactly the breaks it marks, all 512 of them

  Scenario: UTF-8 is read as code points, and a byte that starts nothing well formed is U+FFFD
    Given the bytes of "é—a" and the bytes 255, 65 and 226, 130
    Then they read as 233, 8212, 97 at 0, 2, 5, and as 65533, 65, 65533, 65533
