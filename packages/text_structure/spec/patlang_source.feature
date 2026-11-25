Feature: text_structure PatLang source: a program's units
  A program's section comments make sections; functions and classes are units
  titled by their names, each to the end at its own indentation; comment runs
  have sentences; other top-level lines are statements. (The program read is
  in the runner, run_spec.patlang.)

  Scenario: a program read into its units
    Given the PatLang sample with sections, functions, a class, comments and statements
    Then its outline is
      """
      document
        comment: 2 sentences
        statement
        section Helpers
          heading
          comment: 1 sentence
          function
          function
        section Objects
          heading
          class
          statement
          statement
      """
    And the section "Helpers" holds the functions "double" and "describe", and "Objects" the class "Point"

  Scenario: after each of 200 random edits to a program, the updated tree is the full read's
    Given the PatLang sample with sections, functions, a class, comments and statements
    When 200 random PatLang edits are made one at a time, from seed 3
    Then after every edit the updated tree equals a full read of the new text
