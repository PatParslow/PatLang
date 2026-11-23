Feature: file_marshal history: every version of a file, kept on the disk
  A file's history is an append-only log of its versions with whole copies of
  some of them. Any version still in it can be read back, the shifts since a
  version carry a position forward, and the history can be cleared down to its
  last versions. A crash at any point leaves a history that can be read and a
  file that can be put right.

  Scenario: each version reads back as it was, after the history is opened again
    Given a history begun from the text "the curly haired dog"
    When it records an edit making "haired" into "furry", an append of " sat", and a write of "a new text"
    Then versions 1 to 4 read back as "the curly haired dog", "the curly furry dog", "the curly furry dog sat" and "a new text"
    And opened again from the disk, it has the same 4 versions, and each reads back the same

  Scenario: the shifts since a version, and a whole write that ends them
    Given a history begun from the text "the curly haired dog"
    When it records an edit making "haired" into "furry", an append of " sat", and a write of "a new text"
    Then the shifts since version 1 are those of the edit and the append until version 4, which rewrote the whole content
    And the shifts since version 1 carry position 17, the d of dog, to 16

  Scenario: a whole copy every 64 versions keeps a replay short
    Given a history begun from the text "count: 0"
    When it records 130 edits, each making the count one more
    Then version 131 reads back as "count: 130", and whole copies are kept for versions 1, 64 and 128 only

  Scenario: clearing keeps the last versions, and numbering goes on
    Given a history begun from the text "count: 0"
    When it records 130 edits, each making the count one more
    And the history is cleared down to its last 3 versions
    Then versions 129 to 131 read back, version 128 is gone, and the log holds 3 records
    And the next version recorded is 132, and opened again the history starts at 129

  Scenario: a record cut short at the log's end is left out
    Given a history begun from the text "the curly haired dog"
    When it records an edit making "haired" into "furry"
    And half a record is appended to its log, as a crash while appending would leave it
    Then opened again, it has 2 versions and says its log was torn, and both read back

  Scenario: a file is put right against its history after a crash or an outside change
    Given a history begun from the text "the curly haired dog"
    When it records an edit making "haired" into "furry" without the file being replaced
    Then recovering the file writes version 2's content into it, saying it completed version 2
    When the file is changed by something else to "a cat"
    Then recovering it records version 3 as an outside change, and version 3 reads back as "a cat"

  Scenario: recording a version costs the same however long the history is
    Given a history begun from the text "count: 0"
    Then recording a version after 1000 takes at most three times as long as recording one after 10, the cheapest of five each
