Feature: file_marshal undo: a version's change taken back, as a new version
  Undoing a version applies the inverse of its edits, or of its append, to the
  file as it is now, found by the context around what it changed, and records
  that as a new version. So a version can be undone after others have come,
  as long as what it changed is still there, and an undo can itself be undone.
  A version that replaced the whole content is not undone; the file is
  reverted to the version wanted instead.

  Scenario: the last edit is undone
    Given a history begun from the text "the curly haired dog sat on the mat"
    When it records an edit making "haired" into "furry"
    And version 2 is undone
    Then the file reads "the curly haired dog sat on the mat", recorded as version 3, an undo
    And the shifts since version 2 are [[10, 5, 6]]

  Scenario: an earlier edit is undone, and a later one elsewhere stays
    Given a history begun from the text "the curly haired dog sat on the mat"
    When it records an edit making "haired" into "furry"
    And it records an edit making "mat" into "rug"
    And version 2 is undone
    Then the file reads "the curly haired dog sat on the rug", recorded as version 4, an undo

  Scenario: an undo whose change a later edit has changed again is refused
    Given a history begun from the text "the curly haired dog sat on the mat"
    When it records an edit making "haired" into "furry"
    And it records an edit making "furry" into "fluffy"
    And version 2 is undone
    Then the undo is refused, saying the part between is "fluffy", not "furry", and the file still reads "the curly fluffy dog sat on the mat"

  Scenario: an undo is undone, which does the change again
    Given a history begun from the text "the curly haired dog sat on the mat"
    When it records an edit making "haired" into "furry"
    And version 2 is undone
    And version 3 is undone
    Then the file reads "the curly furry dog sat on the mat", recorded as version 4, an undo

  Scenario: a batch of edits is undone together, and so is an append
    Given a history begun from the text "the curly haired dog sat on the mat"
    When it records one batch making "curly" into "straight" and "mat" into "rug"
    And it records an append of " all day"
    And version 3 is undone
    Then the file reads "the straight haired dog sat on the rug"
    When version 2 is undone
    Then the file reads "the curly haired dog sat on the mat"

  Scenario: a whole write is not undone, but the file can be reverted past it
    Given a history begun from the text "the curly haired dog sat on the mat"
    When it records an edit making "haired" into "furry"
    And it records a write of "something else entirely"
    And version 3 is undone
    Then the undo is refused, saying version 3 replaced the whole content
    When the file is reverted to version 2
    Then the file reads "the curly furry dog sat on the mat", recorded as version 4, a write
