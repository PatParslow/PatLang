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
