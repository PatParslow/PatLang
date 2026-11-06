@language
Feature: a program with bounded live data runs in bounded memory (spec 1.6)

  The harness measures the process's peak memory at two run lengths, N and
  10N iterations. "Does not grow" means the longer run's peak exceeds the
  shorter's by less than 10%. The program itself has no way to read its
  memory use.

  Scenario: a loop replacing one value each iteration does not grow memory
    Given loops of N iterations that each replace a local every iteration with one of these producers:
      | the string "x" + i                         |
      | a string grown by one character, restarted every 100 characters |
      | a 3-element list [i, i + 1, "s"]           |
      | list_push of i onto a list restarted every 100 elements |
      | list_set of an element of an older version |
      | a total past 2^63, so a bigint             |
      | i / 7, a rational                          |
      | sqrt(0 - 4) * i, a complex number          |
      | interval_make(i, i + 1) + 1, an interval   |
      | a new Widget object, unnamed               |
      | a string builder with 10 pushes, read back |
      | a vec with 10 pushes, read back            |
      | a bool array with 100 pushes               |
      | a closure capturing i                      |
      | exec_capture of "echo"                     |
      | read_file of a small file                  |
    When each runs for N and for 10N iterations
    Then no loop's peak memory grows

  Scenario: a named object lives until object_delete
    Given a loop that makes new("Widget", "w" + i) and calls object_delete on it each iteration
    When it runs for N and for 10N iterations
    Then the peak memory does not grow

  Scenario: a named object not deleted is kept
    Given a loop that makes new("Widget", "w" + i) without object_delete, then reads get of the first
    When it runs
    Then the first object's fields are still readable after the loop

  Scenario: many named objects are each found by their name
    Given thousands of named objects, and two objects with one name
    When a program reads each by its name and then deletes them
    Then each read finds its own object, a repeated name finds the first until it is deleted, and a deleted name can be used again

  Scenario: finding a named object does not depend on how many there are
    Given the same lookups at 1,000 and at 16,000 named objects
    When a program times them
    Then the larger takes no more than about three times as long
