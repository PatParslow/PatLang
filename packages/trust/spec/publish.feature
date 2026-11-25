Feature: publishing: a key, a genesis, a release proposed, signed and certified
  The publisher's side of package trust. A member's secret key is a file in
  the publisher's profile directory. A package's group starts with a genesis
  signed by every founder; a release statement is proposed from the
  package's manifest and the log's latest view, each member signs it, and
  certifying collects the signatures, checks they make a quorum, and writes
  the certificate. What it makes passes the same verification an installer
  runs.

  Background:
    Given a publisher's profile and a package named demo at version 1.0.0

  Scenario: a one-member group's release verifies against its genesis pin
    When a key named owner is made
    And the package's group is founded with the key owner
    And its release is proposed, signed with owner and certified
    Then the package verifies against the genesis hash, at version 1.0.0, epoch 0, with 1 signer

  Scenario: a key is made once, and its secret stays in the profile
    When a key named owner is made
    Then making a key named owner again is refused
    And the key file holds 64 lowercase hex digits and the public key printed is another 64

  Scenario: what cannot be done is refused, naming why
    When a key named owner is made
    And a key named stranger is made
    And the package's group is founded with the key owner
    Then founding the group again is refused, saying the log exists
    And after the release is proposed, signing it with stranger is refused, saying the key is not a member
    And certifying it with no signatures is refused, saying the quorum is not met

  Scenario: a release changed after it was certified does not verify
    When a key named owner is made
    And the package's group is founded with the key owner
    And its release is proposed, signed with owner and certified
    And the package's manifest is changed after the release
    Then the package does not verify, at the release's manifest check

  Scenario: a withdrawn release does not verify, saying why it was withdrawn
    When a key named owner is made
    And the package's group is founded with the key owner
    And its release is proposed, signed with owner and certified
    Then withdrawing version 2.0.0 is refused, saying no such release is proposed
    And withdrawing version 1.0.0 with no keys is refused, saying the quorum is not met
    When version 1.0.0 is withdrawn with owner, for the reason "a bad build"
    Then the package does not verify, at the withdrawal, saying demo 1.0.0 is withdrawn: a bad build
