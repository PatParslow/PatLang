# trust

The records and checks of PatLang package trust, phase T1 of
`docs/plans/package-trust.md`. They are shared with the ensemble design's
milestone M0 (`docs/plans/ensemble-membership.md`).

```patlang
include "../packages/trust/trust.patlang"
```

It includes `../sha256/sha256.patlang`, so `sha256` sits beside it.

## What it gives

- Readers and writers for the records `patlang-view`, `patlang-genesis`,
  `patlang-transition`, `patlang-release` and `patlang-withdraw`, and for
  signature files (`sign <slot> <hex>` lines). A reader gives
  `["ok", record]` or `["err", code, stage, detail]` and never stops the
  program. A writer reads back what it wrote, so it refuses exactly what a
  reader refuses.
- Checks: quorum certificates, the genesis against a pinned hash, the
  transition log, a release statement against its manifest and the log,
  withdrawals, and `revoke-from` revocations.
  `trust_verify_package(dir, pin, verify)` runs them over a package
  directory laid out as the plan's "Where they live" describes, with the
  log in `trust/log/`.

The signature check is not PatLang's. Every check that needs one takes a
function value `verify(alg, public_key_hex, message_hex, signature_hex)`
that gives `true` or `false`, and the message is always a record's hash.
Pass a closure literal bound in the calling scope:

```patlang
let verify = |alg, pub, msg, sig| {
  return my_os_verify(alg, pub, msg, sig)
}
let r = trust_verify_package("packages/zip", pinned_genesis_hash, verify)
```

The trust store and its rollback check (step 4 of "Verifying a package")
are not here: the result gives the log's highest epoch for a store to
compare with.

## The record form

A record is printable ASCII (bytes 32 to 126), one `key value` field a
line, each line ending in LF. There is one space between key and value and
none at either end, no blank lines and no comments. Fields come in a fixed
order and number, so a record has a single byte form, and its hash
(SHA-256 of its bytes) names it.

| record | fields, in order |
|--------|------------------|
| view | `group` (only when epoch > 0), `epoch`, `quorum` (`majority` or a count from 1 to the members), `member <slot> ed25519 <key>` (1 to 256, slots increasing, keys distinct) |
| genesis | `package`, `view`, `created` |
| transition | `group`, `from-epoch`, `from-view`, `to-epoch`, `to-view`, `reason` (admit, depart, exclude, rekey), `subject`, `evidence` (only for exclude), `revoke-from` (optional, not for admit) |
| release | `group`, `epoch`, `view`, `package`, `version`, `manifest`, `created` |
| withdraw | `group`, `epoch`, `view`, `package`, `version`, `reason` |

Hashes, keys and signatures are lowercase hex. Numbers have no leading
zeros. Dates are `YYYY-MM-DD` calendar dates. A record is at most 65536
bytes, a signature file at most 256 lines, and a log at most 9999
transitions.

The release statement's `created` line is not in the plan's example. It
gives the date step 6 compares with a `revoke-from` date.

## Rules the checks apply

- Genesis: its hash is the pinned one, it names the epoch-0 view by hash,
  and every founder signed it.
- A certificate: every line is a distinct member of the view (else
  `not-member` or `duplicate-signer`), every counted signature holds
  (`bad-signature`), and the count reaches the quorum (`too-few`). A
  majority is floor(N/2) + 1.
- A transition starts from the epoch and view before it and goes to the
  next epoch. The view beside it is its `to-view`, changed from the one
  before as its reason says (`view-change`). It is signed by a quorum of
  the view before. An exclusion leaves the subject out: its signature does
  not count, and the quorum is a majority of the N - 1 others,
  floor((N-1)/2) + 1, or a count of at most N - 1. A departure or rekey
  must include the subject's own signature (`subject-missing`).
- A release names the manifest's hash, package and version, an epoch the
  log reaches and that epoch's view, and is signed by a quorum of that
  view.
- A withdrawal of the release, at an epoch of the log and signed by a
  quorum of that epoch's view, refuses it (`withdrawn`). A withdrawal file
  that does not check also refuses it, with its own failure.
- Revocation: a signer whose key any transition revoked from a date at or
  before the release's `created` date no longer counts. The release fails
  (`revoked`) when the rest fall short of its view's quorum. Keys, not
  slots, are compared, so a revocation follows a key wherever it appears.

## Specs and benchmark

```
./self_hosting/build/v2.exe packages/trust/spec/run_spec.patlang packages/trust/build/run_spec.exe --workers 2
./packages/trust/build/run_spec.exe [feature file]
./self_hosting/build/v2.exe packages/trust/spec/bench.patlang packages/trust/build/bench.exe --workers 2
./packages/trust/build/bench.exe
```

`spec/oracle.py` (Python's `cryptography`, Ed25519) makes the test keys
from fixed seeds and signs with them. The features' verifier closure calls
it to check signatures. Scenario directories go in `build/s<n>/`.
