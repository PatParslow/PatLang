Feature: trust package: the genesis and the transition log
  A group's log starts at its genesis, signed by every founder, whose hash
  the consumer pins. Each transition starts from the epoch and view before
  it and is signed by a quorum of that view (docs/plans/package-trust.md,
  "Verifying a package", steps 2 and 3). Keys and signatures are made by
  spec/oracle.py from fixed seeds, and the verifier passed to the checks
  calls the oracle. Signers are named; "mallory@1" is the key named
  mallory signing as slot 1.

  Scenario: A genesis signed by every founder checks
    Given a group founded by "alice bob carol" with quorum "majority"
    When the log is checked
    Then the check passes at epoch 0

  Scenario: A one-member group, the case today
    Given a group founded by "pat" with quorum "majority"
    When the log is checked
    Then the check passes at epoch 0

  Scenario: The pinned hash must be the genesis record's
    Given a group founded by "alice bob carol" with quorum "majority"
    When the pin is a different hash
    And the log is checked
    Then the check fails at "genesis" with "pin-mismatch"

  Scenario: Genesis needs every founder's signature
    Given a group founded by "alice bob carol" with quorum "majority", the genesis signed by "alice bob"
    When the log is checked
    Then the check fails at "genesis" with "founder-missing"

  Scenario: A genesis signature by a key that is not the founder's
    Given a group founded by "alice bob carol" with quorum "majority", the genesis signed by "alice bob mallory@2"
    When the log is checked
    Then the check fails at "genesis" with "bad-signature"

  Scenario: The genesis names its view by hash
    Given a group founded by "alice bob carol" with quorum "majority"
    When log entry 0's view has its "quorum" changed to "1"
    And the log is checked
    Then the check fails at "genesis" with "view-mismatch"

  Scenario: Admission, departure, rekey and exclusion, each signed by a quorum of the epoch before
    Given a group founded by "alice bob carol" with quorum "majority"
    When "dave" is admitted as slot 3, signed by "alice bob"
    And "carol" departs, signed by "carol dave alice"
    And "bob" rekeys to "bob2", signed by "bob dave"
    And "dave" is excluded, signed by "alice bob2"
    And the log is checked
    Then the check passes at epoch 4

  Scenario: A transition signed by the members it admits, not the epoch before
    Given a group founded by "alice bob carol" with quorum "majority"
    When "dave" is admitted as slot 3, signed by "alice dave"
    And the log is checked
    Then the check fails at "log 1" with "not-member"

  Scenario: A transition signed by too few of the epoch before
    Given a group founded by "alice bob carol" with quorum "majority"
    When "dave" is admitted as slot 3, signed by "alice"
    And the log is checked
    Then the check fails at "log 1" with "too-few"

  Scenario: A count quorum is a count
    Given a group founded by "alice bob carol" with quorum "3"
    When "dave" is admitted as slot 3, signed by "alice bob"
    And the log is checked
    Then the check fails at "log 1" with "too-few"

  Scenario: One member signing a transition twice is refused
    Given a group founded by "alice bob carol" with quorum "majority"
    When "dave" is admitted as slot 3, signed by "alice alice"
    And the log is checked
    Then the check fails at "log 1" with "duplicate-signer"

  Scenario: An exclusion does not count the excluded member
    Given a group founded by "alice bob carol" with quorum "majority"
    When "carol" is excluded, signed by "alice carol"
    And the log is checked
    Then the check fails at "log 1" with "too-few"

  Scenario: An exclusion needs a majority of the others only
    Given a group founded by "alice bob carol dave" with quorum "majority"
    When "dave" is excluded, signed by "alice bob"
    And the log is checked
    Then the check passes at epoch 1

  Scenario: A departure is signed by the departing member as well
    Given a group founded by "alice bob carol" with quorum "majority"
    When "carol" departs, signed by "alice bob"
    And the log is checked
    Then the check fails at "log 1" with "subject-missing"

  Scenario: A rekey is signed by the rekeying member as well
    Given a group founded by "alice bob carol" with quorum "majority"
    When "carol" rekeys to "carol2", signed by "alice bob"
    And the log is checked
    Then the check fails at "log 1" with "subject-missing"

  Scenario: A transition must start from the epoch before it
    Given a group founded by "alice bob carol" with quorum "majority"
    When "dave" is admitted as slot 3, signed by "alice bob"
    And log entry 1's "from-epoch" is changed to "5" and re-signed by "alice bob"
    And the log is checked
    Then the check fails at "log 1" with "epoch-mismatch"

  Scenario: A transition must start from the view before it
    Given a group founded by "alice bob carol" with quorum "majority"
    When "dave" is admitted as slot 3, signed by "alice bob"
    And log entry 1's "from-view" is changed to "<64:7>" and re-signed by "alice bob"
    And the log is checked
    Then the check fails at "log 1" with "view-mismatch"

  Scenario: A transition names its group
    Given a group founded by "alice bob carol" with quorum "majority"
    When "dave" is admitted as slot 3, signed by "alice bob"
    And log entry 1's "group" is changed to "<64:3>" and re-signed by "alice bob"
    And the log is checked
    Then the check fails at "log 1" with "group-mismatch"

  Scenario: Each view's hash must match the transition naming it
    Given a group founded by "alice bob carol" with quorum "majority"
    When "dave" is admitted as slot 3, signed by "alice bob"
    And log entry 1's view has its "quorum" changed to "1"
    And the log is checked
    Then the check fails at "log 1" with "view-mismatch"

  Scenario: The new view is the old one changed as the reason says
    Given a group founded by "alice bob carol" with quorum "majority"
    When "dave" is admitted as slot 3, signed by "alice bob"
    And log entry 1's "reason" is changed to "rekey" and re-signed by "alice bob"
    And the log is checked
    Then the check fails at "log 1" with "view-change"

  Scenario: A changed transition no longer matches its signatures
    Given a group founded by "alice bob carol" with quorum "majority"
    When "dave" is admitted as slot 3, signed by "alice bob"
    And log entry 1's "subject" is changed to "4" without re-signing
    And the log is checked
    Then the check fails at "log 1" with "bad-signature"
