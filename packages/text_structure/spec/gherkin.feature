Feature: text_structure Gherkin: a feature file's units
  Feature, Rule, Background, Scenario and Examples headings make nested
  sections; steps, doc strings, tables, comments and description paragraphs
  are units of their own; a heading's tags are in its attrs. (The feature
  files read here are in the runner, run_spec.patlang, since a doc string
  cannot hold one with its own doc string.)

  Scenario: a feature file read into its units
    Given the Gherkin sample with a rule, an outline, a table and a doc string
    Then its outline is
      """
      document
        comment
        section Ordering
          heading
          paragraph: 2 sentences
          section
            heading
            step Given
          section stock is kept
            heading
            section buying one
              heading
              step When
              step Then
              table
            section buying many
              heading
              step When
              step Then
              code
              section
                heading
                table
      """
    And the heading "buying one" has the tags "@fast", and the feature's the tags "@smoke"

  Scenario: after each of 150 random edits to a feature file, the updated tree is the full read's
    Given the Gherkin sample with a rule, an outline, a table and a doc string
    When 150 random Gherkin edits are made one at a time, from seed 5
    Then after every edit the updated tree equals a full read of the new text
