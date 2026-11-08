Feature: trust package: verifying a released package
  A package directory holds its manifest, its files, and trust/ with the
  group's log, release/<version>.rec and .sig and, when there is one,
  withdraw/<version>.rec and .sig (docs/plans/package-trust.md, "Where
  they live"). Verification checks the files against the manifest, the
  log against the pinned genesis hash, the release statement against the
  manifest and the log, then withdrawals and revocations ("Verifying a
  package", steps 1, 2, 3, 5 and 6). Releases are dated 2026-11-08 unless
  a scenario says otherwise.

  Scenario: A release signed by a quorum of its epoch verifies
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice bob"
    And the package is verified
    Then the verification passes

  Scenario: A one-member group's release verifies
    Given a group founded by "pat" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "pat"
    And the package is verified
    Then the verification passes

  Scenario: A release from an earlier epoch still verifies after the group changes
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice bob"
    And "dave" is admitted as slot 3, signed by "alice carol"
    And "alice" departs, signed by "alice bob carol"
    And the package is verified
    Then the verification passes

  Scenario: A file changed after release
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice bob"
    And the file "zip.patlang" is changed
    And the package is verified
    Then the verification fails at "files" with "file-mismatch"

  Scenario: A manifest changed after release
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice bob"
    And the file "zip.patlang" is changed and its manifest line updated
    And the package is verified
    Then the verification fails at "release" with "manifest-mismatch"

  Scenario: A missing file
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice bob"
    And the file "zip.patlang" is removed
    And the package is verified
    Then the verification fails at "files" with "file-missing"

  Scenario: A certificate with too few signers
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice"
    And the package is verified
    Then the verification fails at "release" with "too-few"

  Scenario: One member signing twice
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice alice"
    And the package is verified
    Then the verification fails at "release" with "duplicate-signer"

  Scenario: A signer not in the epoch's view
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice mallory@5"
    And the package is verified
    Then the verification fails at "release" with "not-member"

  Scenario: A member of a later epoch signing a release of an earlier one
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When "dave" is admitted as slot 3, signed by "alice bob"
    And version "0.1.0" is released at epoch 0 dated "2026-11-08", signed by "alice dave"
    And the package is verified
    Then the verification fails at "release" with "not-member"

  Scenario: A key signing for a slot that is not its own
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice mallory@1"
    And the package is verified
    Then the verification fails at "release" with "bad-signature"

  Scenario: A signature over a different record kind with the same lines after its first
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed over the same lines as a "patlang-withdraw 1" record by "alice bob"
    And the package is verified
    Then the verification fails at "release" with "bad-signature"

  Scenario: A release naming an epoch the log does not reach
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released at epoch 3 dated "2026-11-08", signed by "alice bob"
    And the package is verified
    Then the verification fails at "release" with "epoch-unknown"

  Scenario: A release naming another version than its manifest
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When a release naming version "0.2.0" is stored as version "0.1.0", signed by "alice bob"
    And the package is verified
    Then the verification fails at "release" with "version-mismatch"

  Scenario: A package with no release statement
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When the package is verified
    Then the verification fails at "release" with "missing"

  Scenario: A withdrawn release
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice bob"
    And "dave" is admitted as slot 3, signed by "alice bob"
    And version "0.1.0" is withdrawn, signed by "bob carol dave"
    And the package is verified
    Then the verification fails at "withdrawal" with "withdrawn"

  Scenario: A withdrawal must itself be signed by a quorum
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice bob"
    And version "0.1.0" is withdrawn, signed by "mallory@0 bob"
    And the package is verified
    Then the verification fails at "withdrawal" with "bad-signature"

  Scenario: A release signed with a key revoked from a date before it
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice bob"
    And "alice" rekeys to "alice2" revoking from "2026-11-01", signed by "alice bob"
    And the package is verified
    Then the verification fails at "revocation" with "revoked"

  Scenario: A key revoked from the release's own date
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice bob"
    And "alice" rekeys to "alice2" revoking from "2026-11-08", signed by "alice bob"
    And the package is verified
    Then the verification fails at "revocation" with "revoked"

  Scenario: A key revoked from a date after the release
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice bob"
    And "alice" rekeys to "alice2" revoking from "2026-11-09", signed by "alice bob"
    And the package is verified
    Then the verification passes

  Scenario: A revoked signer whose release keeps a quorum without it
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice bob carol"
    And "alice" is excluded revoking from "2026-10-01", signed by "bob carol"
    And the package is verified
    Then the verification passes

  Scenario: An excluded signer's revocation leaves too few
    Given a group founded by "alice bob carol" with quorum "majority"
    And the package "zip" version "0.1.0" with the file "zip.patlang"
    When version "0.1.0" is released, signed by "alice bob"
    And "alice" is excluded revoking from "2026-10-01", signed by "bob carol"
    And the package is verified
    Then the verification fails at "revocation" with "revoked"
