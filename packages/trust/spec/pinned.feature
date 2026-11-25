Feature: verifying a package against the trust store: pkg pin and pkg verify
  The consumer's side of package trust before installing. A package is
  checked against the pin the trust store holds for its name, or a shipped
  pin when the store holds none; the store's own pin wins, and a shipped pin
  that differs is told, not resolved silently. Every check of the package
  runs (its files, its log against the pin, its release and withdrawals),
  and then its log's epoch against the highest the store has seen, so a
  rolled-back log is refused. Nothing is written: verifying raises no epoch.

  Background:
    Given a publisher's profile and a package named demo at version 1.0.0
    And a key named owner is made
    And the package's group is founded with the key owner
    And its release is proposed, signed with owner and certified
    And a consumer's trust store in a directory of its own

  Scenario: a package pinned in the store verifies, naming its pin's source
    When demo is pinned to its genesis hash, given
    Then the package verifies against the store at version 1.0.0, epoch 0, with 1 signer, its pin given

  Scenario: a package with no pin is refused, saying how to give one
    Then the package is refused at the pin, saying demo is not pinned and naming pkg pin

  Scenario: a shipped pin is used when the store holds none
    When the shipped pins name demo's genesis hash
    Then the package verifies against the store at version 1.0.0, epoch 0, with 1 signer, its pin shipped

  Scenario: the store's pin wins over a shipped one, and the difference is told
    When demo is pinned to the hash "a" repeated 64 times, given
    And the shipped pins name demo's genesis hash
    Then the package is refused at the genesis, its hash not the pin, telling that the shipped pin differs from the store's

  Scenario: a log behind the epoch the store has seen is refused as rolled back
    When demo is pinned to its genesis hash, given
    And the store has seen demo's log at epoch 2
    Then the package is refused at the epoch, saying the log is rolled back
    And the store still holds epoch 2 for demo

  Scenario: a file changed after the release is refused at the file check
    When demo is pinned to its genesis hash, given
    And the package's file demo.patlang is changed after the release
    Then the package is refused at the files, naming demo.patlang
