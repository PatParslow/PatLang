Feature: trust package: reading and writing the trust records
  Records are ASCII, one `key value` field a line, each line ending in LF,
  with no trailing spaces (docs/plans/package-trust.md, "Records"). A
  reader gives ["ok", record] or a structured failure ["err", code, stage,
  detail]; it never stops the program. In the step texts below `|` stands
  for LF, `<N:X>` for N copies of X, `<sp>` for a space, `<cr>` for CR and
  `<b:N>` for the byte N.

  Scenario: An epoch-0 view reads with its members and quorum
    Given the bytes "record patlang-view 1|epoch 0|quorum majority|member 0 ed25519 <64:a>|member 1 ed25519 <64:b>|member 2 ed25519 <64:c>|"
    Then reading it as a view succeeds
    And the view has epoch 0, 3 members and needs 2 signatures
    And the view needs 2 signatures for an exclusion
    And its hash is the one Python's hashlib gives

  Scenario: A later view names its group, and a count quorum needs that count
    Given the bytes "record patlang-view 1|group <64:f>|epoch 4|quorum 3|member 0 ed25519 <64:a>|member 2 ed25519 <64:b>|member 7 ed25519 <64:c>|member 9 ed25519 <64:d>|"
    Then reading it as a view succeeds
    And the view has epoch 4, 4 members and needs 3 signatures
    And the view needs 3 signatures for an exclusion

  Scenario: A majority of the others decides an exclusion
    Given the bytes "record patlang-view 1|group <64:f>|epoch 1|quorum majority|member 0 ed25519 <64:a>|member 1 ed25519 <64:b>|member 2 ed25519 <64:c>|member 3 ed25519 <64:d>|"
    Then the view has epoch 1, 4 members and needs 3 signatures
    And the view needs 2 signatures for an exclusion

  Scenario: An all-of-N count quorum can still exclude, with all of the others
    Given the bytes "record patlang-view 1|group <64:f>|epoch 1|quorum 3|member 0 ed25519 <64:a>|member 1 ed25519 <64:b>|member 2 ed25519 <64:c>|"
    Then the view needs 3 signatures
    And the view needs 2 signatures for an exclusion

  Scenario: The other record kinds read
    Given the bytes "record patlang-genesis 1|package zip|view <64:7>|created 2026-11-08|"
    Then reading it as a genesis succeeds
    Given the bytes "record patlang-transition 1|group <64:3>|from-epoch 0|from-view <64:7>|to-epoch 1|to-view <64:5>|reason admit|subject 3|"
    Then reading it as a transition succeeds
    Given the bytes "record patlang-transition 1|group <64:3>|from-epoch 1|from-view <64:7>|to-epoch 2|to-view <64:5>|reason exclude|subject 1|evidence <64:e>|revoke-from 2026-10-01|"
    Then reading it as a transition succeeds
    Given the bytes "record patlang-release 1|group <64:3>|epoch 1|view <64:5>|package zip|version 0.1.0|manifest <64:9>|created 2026-11-08|"
    Then reading it as a release succeeds
    And the release names package "zip" version "0.1.0" at epoch 1
    Given the bytes "record patlang-withdraw 1|group <64:3>|epoch 2|view <64:0>|package zip|version 0.1.0|reason the inflate loop can be made to run forever|"
    Then reading it as a withdrawal succeeds
    Given the bytes "sign 0 <128:a>|sign 2 <128:b>|"
    Then reading it as a signature file succeeds

  Scenario: A record of one kind does not read as another
    Given the bytes "record patlang-genesis 1|package zip|view <64:7>|created 2026-11-08|"
    Then reading it as a view fails with "malformed"
    And reading it as a release fails with "malformed"
    Given the bytes "record patlang-view 2|epoch 0|quorum 1|member 0 ed25519 <64:a>|"
    Then reading it as a view fails with "malformed"

  Scenario: Line ends and spacing are exact
    Given the bytes "record patlang-view 1<cr>|epoch 0|quorum 1|member 0 ed25519 <64:a>|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1|epoch 0<sp>|quorum 1|member 0 ed25519 <64:a>|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1|epoch<sp><sp>0|quorum 1|member 0 ed25519 <64:a>|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1|<sp>epoch 0|quorum 1|member 0 ed25519 <64:a>|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1|epoch 0|quorum 1|member 0 ed25519 <64:a>"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1||epoch 0|quorum 1|member 0 ed25519 <64:a>|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1|# a comment|epoch 0|quorum 1|member 0 ed25519 <64:a>|"
    Then reading it as a view fails with "malformed"
    Given the bytes ""
    Then reading it as a view fails with "malformed"

  Scenario: Only printable ASCII is allowed
    Given the bytes "record patlang-genesis 1|package zip|view <64:7>|created 2026-11-08 <b:195><b:169>|"
    Then reading it as a genesis fails with "malformed"
    Given the bytes "record patlang-genesis 1|package zip|view <64:7>|created 2026-11-08<b:9>|"
    Then reading it as a genesis fails with "malformed"
    Given the bytes "record patlang-genesis 1|package zip|view <64:7>|created 2026-11-08<b:0>|"
    Then reading it as a genesis fails with "malformed"

  Scenario: Fields come once each, in order
    Given the bytes "record patlang-genesis 1|view <64:7>|package zip|created 2026-11-08|"
    Then reading it as a genesis fails with "malformed"
    Given the bytes "record patlang-genesis 1|package zip|package zip|view <64:7>|created 2026-11-08|"
    Then reading it as a genesis fails with "malformed"
    Given the bytes "record patlang-genesis 1|package zip|view <64:7>|"
    Then reading it as a genesis fails with "malformed"
    Given the bytes "record patlang-genesis 1|package zip|view <64:7>|created 2026-11-08|colour blue|"
    Then reading it as a genesis fails with "malformed"

  Scenario: Values have one form each
    Given the bytes "record patlang-genesis 1|package zip|view <64:A>|created 2026-11-08|"
    Then reading it as a genesis fails with "malformed"
    Given the bytes "record patlang-genesis 1|package zip|view <63:a>|created 2026-11-08|"
    Then reading it as a genesis fails with "malformed"
    Given the bytes "record patlang-genesis 1|package Zip|view <64:a>|created 2026-11-08|"
    Then reading it as a genesis fails with "malformed"
    Given the bytes "record patlang-genesis 1|package zip|view <64:a>|created 2026-02-30|"
    Then reading it as a genesis fails with "malformed"
    Given the bytes "record patlang-genesis 1|package zip|view <64:a>|created 2024-02-29|"
    Then reading it as a genesis succeeds
    Given the bytes "record patlang-genesis 1|package zip|view <64:a>|created 2023-02-29|"
    Then reading it as a genesis fails with "malformed"
    Given the bytes "record patlang-view 1|group <64:f>|epoch 01|quorum 1|member 0 ed25519 <64:a>|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-release 1|group <64:3>|epoch 1|view <64:5>|package zip|version 0.1|manifest <64:9>|created 2026-11-08|"
    Then reading it as a release fails with "malformed"
    Given the bytes "record patlang-release 1|group <64:3>|epoch 1|view <64:5>|package zip|version 0.01.0|manifest <64:9>|created 2026-11-08|"
    Then reading it as a release fails with "malformed"
    Given the bytes "sign 00 <128:a>|"
    Then reading it as a signature file fails with "malformed"
    Given the bytes "sign 0 <126:a>|"
    Then reading it as a signature file fails with "malformed"
    Given the bytes "sign 0|"
    Then reading it as a signature file fails with "malformed"

  Scenario: A view's members are well formed
    Given the bytes "record patlang-view 1|epoch 0|quorum 1|member 1 ed25519 <64:a>|member 0 ed25519 <64:b>|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1|epoch 0|quorum 1|member 0 ed25519 <64:a>|member 0 ed25519 <64:b>|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1|epoch 0|quorum 1|member 0 ed25519 <64:a>|member 1 ed25519 <64:a>|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1|epoch 0|quorum 1|member 0 rsa <64:a>|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1|epoch 0|quorum 1|member 0 ed25519 <64:a> extra|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1|epoch 0|quorum 1|"
    Then reading it as a view fails with "malformed"

  Scenario: A view's quorum fits its members
    Given the bytes "record patlang-view 1|epoch 0|quorum 3|member 0 ed25519 <64:a>|member 1 ed25519 <64:b>|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1|epoch 0|quorum 0|member 0 ed25519 <64:a>|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1|epoch 0|quorum most|member 0 ed25519 <64:a>|"
    Then reading it as a view fails with "malformed"

  Scenario: Only a later view names its group
    Given the bytes "record patlang-view 1|group <64:f>|epoch 0|quorum 1|member 0 ed25519 <64:a>|"
    Then reading it as a view fails with "malformed"
    Given the bytes "record patlang-view 1|epoch 1|quorum 1|member 0 ed25519 <64:a>|"
    Then reading it as a view fails with "malformed"

  Scenario: A transition's optional fields follow its reason
    Given the bytes "record patlang-transition 1|group <64:3>|from-epoch 1|from-view <64:7>|to-epoch 2|to-view <64:5>|reason exclude|subject 1|"
    Then reading it as a transition fails with "malformed"
    Given the bytes "record patlang-transition 1|group <64:3>|from-epoch 1|from-view <64:7>|to-epoch 2|to-view <64:5>|reason depart|subject 1|evidence <64:e>|"
    Then reading it as a transition fails with "malformed"
    Given the bytes "record patlang-transition 1|group <64:3>|from-epoch 1|from-view <64:7>|to-epoch 2|to-view <64:5>|reason admit|subject 4|revoke-from 2026-10-01|"
    Then reading it as a transition fails with "malformed"
    Given the bytes "record patlang-transition 1|group <64:3>|from-epoch 1|from-view <64:7>|to-epoch 2|to-view <64:5>|reason promote|subject 1|"
    Then reading it as a transition fails with "malformed"
    Given the bytes "record patlang-transition 1|group <64:3>|from-epoch 1|from-view <64:7>|to-epoch 2|to-view <64:5>|reason rekey|subject 1|revoke-from 2026-10-01|"
    Then reading it as a transition succeeds

  Scenario: Input sizes are bounded
    Given a view with 256 members
    Then reading it as a view succeeds
    Given a view with 257 members
    Then reading it as a view fails with "too-large"
    Given a signature file with 256 lines
    Then reading it as a signature file succeeds
    Given a signature file with 257 lines
    Then reading it as a signature file fails with "too-large"
    Given a withdrawal whose reason is 65000 characters long
    Then reading it as a withdrawal succeeds
    Given a withdrawal whose reason is 66000 characters long
    Then reading it as a withdrawal fails with "too-large"

  Scenario: Every proper prefix of a record is refused
    Given the bytes "record patlang-release 1|group <64:3>|epoch 1|view <64:5>|package zip|version 0.1.0|manifest <64:9>|created 2026-11-08|"
    Then every proper prefix of it fails to read as a release
    Given the bytes "record patlang-transition 1|group <64:3>|from-epoch 1|from-view <64:7>|to-epoch 2|to-view <64:5>|reason exclude|subject 1|evidence <64:e>|"
    Then every proper prefix of it fails to read as a transition

  Scenario: Random bytes give a structured failure for every kind
    Then 200 pseudo-random byte strings each fail to read as every kind

  Scenario: The writer's records read back, and hash as Python hashes them
    When a view is written with group "" epoch 0 quorum "majority" and members "0=a 1=b 2=c"
    Then the writing succeeds and reads back as a view
    And its hash is the one Python's hashlib gives
    And its text is "record patlang-view 1|epoch 0|quorum majority|member 0 ed25519 <64:a>|member 1 ed25519 <64:b>|member 2 ed25519 <64:c>|"
    When a release is written for package "zip" version "0.1.0" at epoch 1
    Then the writing succeeds and reads back as a release
    And its text is "record patlang-release 1|group <64:3>|epoch 1|view <64:5>|package zip|version 0.1.0|manifest <64:9>|created 2026-11-08|"
    When a signature file is written for slots "0=a 2=b"
    Then the writing succeeds and reads back as a signature file
    And its text is "sign 0 <128:a>|sign 2 <128:b>|"

  Scenario: The writer refuses what the reader would refuse
    When a view is written with group "" epoch 0 quorum "majority" and members "1=a 0=b"
    Then the writing fails with "malformed"
    When a view is written with group "" epoch 0 quorum "4" and members "0=a 1=b"
    Then the writing fails with "malformed"
    When a release is written for package "Zip!" version "0.1.0" at epoch 1
    Then the writing fails with "malformed"
    When a release is written for package "zip" version "0.1.0 evil" at epoch 1
    Then the writing fails with "malformed"
