Feature: text_structure: sections, paragraphs and sentences, addresses, and edits by them
  A text is read into a tree of units with byte ranges. Units are found by
  address, walked one at a time, and changed by edits whose context comes from
  around them, so the edits still apply when the file has moved on.

  Scenario: a wrapped paragraph's sentences run across its line breaks
    Given the plain text
      """
      The first sentence is wrapped
      across two lines. The second is short.

      A second paragraph.
      """
    Then it has 2 paragraphs, the first with the sentences "The first sentence is wrapped\nacross two lines." and "The second is short."

  Scenario: no sentence ends after an abbreviation CLDR lists, or one a program adds
    Given the plain text
      """
      Mr. Jones met Prof. Smith in the U.S. capital. They spoke, e.g. about Mars.
      """
    Then it has 1 paragraph, with the sentences "Mr. Jones met Prof. Smith in the U.S. capital." and "They spoke, e.g. about Mars."
    Given the plain text
      """
      Mr. Jones met Dr. Smith. They spoke.
      """
    Then it has 1 paragraph, with the sentences "Mr. Jones met Dr.", "Smith." and "They spoke."
    When "Dr." is added to the suppressions
    Then it has 1 paragraph, with the sentences "Mr. Jones met Dr. Smith." and "They spoke."

  Scenario: underlined titles make sections in plain text
    Given the plain text
      """
      Notes
      =====

      Intro text.

      Details
      -------

      More text. And more.
      """
    Then it has a section "Notes" holding a paragraph and a section "Details", whose paragraph has 2 sentences

  Scenario: Markdown's blocks are units of their own kinds
    Given the Markdown
      """
      # Guide

      An opening paragraph. It has two sentences.

      ## Install

      - Download it. Then unpack it.
      - Run the installer.

      ```sh
      make install. Not a sentence.
      ```

      > A quoted line. Another one.

      | a | b |
      |---|---|

      ---

      Setext title
      ------------

      Last words.
      """
    Then its outline is
      """
      document
        section Guide
          heading
          paragraph: 2 sentences
          section Install
            heading
            list
              item: 2 sentences
              item: 1 sentence
            code sh
            quote
              paragraph: 2 sentences
            table
            break
          section Setext title
            heading
            paragraph: 1 sentence
      """

  Scenario: a unit is found by its address, and a walk yields one unit at a time
    Given the Markdown
      """
      # Guide

      First paragraph. Second sentence here.

      ## Install

      Run it. Then rest. Then go home.
      """
    Then the address section "Guide" / section "Install" / paragraph 1 / sentence 2 is "Then rest."
    And the address section "Guide" / paragraph 3 is not found, saying there is no paragraph 3
    And a walk over sentences gives "First paragraph." first, and stops after 5

  Scenario: edits by address apply by their context, even after the file has moved on
    Given the Markdown
      """
      # Guide

      First paragraph. Second sentence here.

      ## Install

      Run it. Then rest.
      """
    When the address section "Guide" / section "Install" / paragraph 1 / sentence 2 is made into "Then go home."
    Then the text ends "Run it. Then go home.\n"
    When an edit making "Run it." into "Run it now." is made, and then the heading "# Guide" becomes "# The guide" before it is applied
    Then the edit still applies, and the text is "# The guide\n\nFirst paragraph. Second sentence here.\n\n## Install\n\nRun it now. Then go home.\n"
    When the paragraph under "Install" is moved to before the first paragraph
    Then the paragraphs read, in order, "Run it now. Then go home." and "First paragraph. Second sentence here."
