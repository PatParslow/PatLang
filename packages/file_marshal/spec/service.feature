Feature: file_marshal service: one owner in front of the files under a root
  The service applies every operation on a file one at a time, in the order
  they arrive, records each in the file's history, and is reached through the
  port marshaller by the name "files". Each scenario runs a marshaller, the
  service and its clients in this process, on threads, over a root of its own.

  Background:
    Given a marshaller and a file service registered as "files", over a root holding notes.txt saying "the curly haired dog sat on the mat"

  Scenario: a client reads a file, edits it, and reads the new version
    When a client reads notes.txt
    Then it gets version 1 and "the curly haired dog sat on the mat"
    When it edits notes.txt from version 1, making "haired" into "furry"
    Then the edit is version 2, and notes.txt on the disk says "the curly furry dog sat on the mat"

  Scenario: two clients editing different parts of one file at once both get every edit in
    Given a file counts.txt saying "a=0 b=0"
    When one client makes a 25 times one more, and another makes b 25 times one more, at once
    Then counts.txt says "a=25 b=25", and its history has 51 versions

  Scenario: an edit made against an older version has its hint carried to where its context now is
    Given a file data.bin of 4096 bytes in which the bytes 1 2 3 and 7 8 9 come at 100 and again at 3000, with 4 5 6 between them
    When one client reads data.bin, and another then inserts 10 bytes before the first 1 2 3
    And the first client, from the version it read, changes the 4 5 6 near 3000, within 4, to 0
    Then the change applies at 3013, where the bytes now are

  Scenario: a write that says which version it replaces is refused once the file has moved on
    When a client reads notes.txt
    And another client edits notes.txt from version 1, making "mat" into "rug"
    And the first client writes "something else" to notes.txt if it is still at version 1
    Then the write is refused, saying the file is at version 2
    When the first client writes "something else" to notes.txt if it is at version 2
    Then the write is version 3

  Scenario: a change made by something else is recorded as a version of its own
    When notes.txt is changed on the disk to "a cat"
    And a client reads notes.txt
    Then it gets version 2 and "a cat"
    And version 2 in the history is an outside change

  Scenario: a path that would leave the root is refused
    Then reading "../outside.txt", "/etc/passwd", "a//b", "c:/x" and "a\b" are each refused, and no file outside the root is read

  Scenario: appends from several clients are all there, and an undo through the service
    Given a file log.txt saying ""
    When 4 clients each append 20 lines to log.txt at once
    Then log.txt holds the 80 lines, each whole, and its history has 81 versions
    When a client edits notes.txt from version 1, making "haired" into "furry"
    And it undoes version 2 of notes.txt
    Then notes.txt says "the curly haired dog sat on the mat" again

  Scenario: find with a cursor gives each match in turn, carried past edits made between calls
    Given a file find.txt saying "x cat y cat z cat"
    When a client finds "cat" in find.txt from the start
    Then it is found at 2
    When another client puts "big " between "x " and "cat" in find.txt
    And the client finds "cat" in find.txt from its cursor
    Then it is found at 12
    When the client finds "cat" in find.txt from its cursor
    Then it is found at 18
    When the client finds "cat" in find.txt from its cursor
    Then the search has ended
    And finding "" is refused, saying a pattern is at least one byte

  Scenario: the service answers status, and quits with its token
    When a client reads notes.txt
    Then a status query says 1 file and at least 2 operations
    And quit with a wrong token is refused, and quit with the service's token ends it
