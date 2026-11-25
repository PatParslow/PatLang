Feature: trust store: pins, epochs that only rise, shipped pins, and the project lock file
  The trust store holds, for each package a user trusts, the genesis hash it is
  pinned to, where the pin came from, and the highest epoch its log has
  reached. Each entry is a file of its own in the records' form, replaced
  through a file beside it. A log that ends below the epoch held is refused
  as rolled back. A project's lock file names the versions, pins and
  manifests it was built with.

  Background:
    Given a trust store in a directory of its own

  Scenario: a pin given is kept, and read back by another opening of the store
    When zip is pinned to the hash "a" repeated 64 times, given
    Then zip's entry reads back, from the store opened again, as that pin, the source given and the epoch 0

  Scenario: a package pinned to one hash is not pinned to another without unpinning
    When zip is pinned to the hash "a" repeated 64 times, given
    Then pinning zip to that hash again keeps its entry
    And pinning zip to the hash "b" repeated 64 times is refused, naming both hashes
    And after zip is unpinned, pinning it to the hash "b" repeated 64 times is kept

  Scenario: an epoch only rises, and a log that ends below it is refused as rolled back
    When zip is pinned to the hash "a" repeated 64 times, given
    And zip's epoch is raised to 3
    Then a log ending at epoch 2 is refused as rolled back, and one ending at 3 or 4 is not
    And raising zip's epoch to 2 leaves it at 3

  Scenario: what cannot be read is refused, not believed
    Then a package name with a capital letter, a pin that is not a hash, and the source "trusted" are each refused
    And an entry whose pin field was changed to "zz" is refused when read, saying its pin is not a hash
    And a file left half written beside an entry is not read, and the entry beside it reads as before

  Scenario: shipped pins, and the store's pin winning over a shipped one that differs
    Given the shipped pins "pin zip " with "a" repeated 64 times, and "pin deflate " with "c" repeated 64 times
    When zip is pinned to the hash "b" repeated 64 times, given
    Then the pin to use for deflate is the shipped one, its source shipped
    And the pin to use for zip is the store's, its source given, with a note that the shipped pin differs
    And the pin to use for tar is none
    And shipped pins with a line that is not pin PACKAGE HASH are refused, naming the line

  Scenario: two installers pinning different packages at once both keep their pins
    When 4 threads each pin a package of their own, 10 packages each
    Then all 40 packages read back pinned to their own hashes

  Scenario: a project's lock file refuses a package changed since it was written
    When a lock file is written naming zip 0.2.0 and deflate 0.2.0 with their pins and manifests
    Then it reads back as written
    And checking zip 0.2.0 with its pin and manifest passes, and checking a package it does not name passes
    And checking zip 0.3.0, zip with another pin, or zip with another manifest is each refused, saying which
