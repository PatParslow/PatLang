Feature: text_structure updates: a tree carried past edits, re-reading only what they touched
  After edits, ts_update gives the tree of the new text from the old tree and
  the edits' shifts, reading again only the blocks the edits touched and
  their neighbours. The tree it gives must be the one a full read gives.

  Scenario: after each of 200 random edits to Markdown, the updated tree is the full read's
    Given a Markdown text of headings, paragraphs, a list, a quote, code and a table
    When 200 random edits are made one at a time, each deleting up to 3 bytes and inserting up to 3 pieces of line breaks, letters, full stops, "#", "- ", "```", "> ", "|", "===" and spaces, from seed 7
    Then after every edit the updated tree equals a full read of the new text

  Scenario: the same for plain text, with titles
    Given a plain text of titles and paragraphs
    When 100 random edits are made one at a time in the same way, from seed 11
    Then after every edit the updated tree equals a full read of the new text

  Scenario: a batch of edits in different places is one update
    Given a Markdown text of headings, paragraphs, a list, a quote, code and a table
    When a batch changes a word in the first paragraph and one in the last, and the tree is updated from the batch's shifts
    Then the updated tree equals a full read of the new text

  Scenario: an edit to one sentence of a large document re-reads a small region, at a small part of a full read's cost
    Given a Markdown document of about 280 KB
    When one sentence in its middle is changed
    Then the region read again is under 1 KB, the updated tree equals a full read, and the update takes at most a tenth of the full read's time
