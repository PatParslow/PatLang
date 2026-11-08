# Package trust

How a program that installs a PatLang package decides to trust it. This is a plan: nothing below
is built beyond the content hashes in each manifest (`packages/README.md`). It applies the
ensemble design for PatLang networking (`docs/plans/ensemble-membership.md`), so packages and
networking share one trust model, as the project owner decided on 2026-11-08. The package manager
it belongs to is planned in `docs/plans/package-manager.md`.

No part of it uses Rust. Everything is PatLang, compiled by v2. The only code it calls that
PatLang did not compile is the operating system's, through the same kind of import v2's runtime
already uses for files and processes, and in the browser the page's WebCrypto. "The OS" below
means exactly that: `bcrypt.dll` and `ws2_32.dll` on Windows, called from v2's own runtime, never
`rust-runtime/` or `hosts.rs`.

## What trust has to answer

A consumer holding a package directory needs to know:

1. that the files are the ones the manifest names (done: the `file` lines and
   `packages/tools/verify_manifest.patlang`);
2. that the manifest is one the package's publishers released;
3. that those publishers are still the package's publishers, and that the release has not since
   been withdrawn;
4. what any of that says about the package's dependencies.

Questions 2 to 4 are what this plan adds. None of them needs anyone's real-world identity: a
publisher is a member of the package's publisher group and nothing more.

## The model

A package's publishers form a **group** in the ensemble design's sense. The decisions the group
makes are releases. A release is a **statement** naming a manifest by its hash, and the group's
**quorum certificate** over that statement is the attestation. Members join and leave through
**epoch transitions**, each approved by a quorum of the epoch before it, so the group's whole
history is a chain that starts at its **genesis record**. A consumer trusts a group by pinning its
genesis hash, once, and checks everything else against the chain.

A group with one maintainer is the case today (the repository owner): its quorum is 1 of 1, and the
same formats cover it.

### What packages need beyond the networking design

The networking ensemble runs among live processes that share keys. Package trust differs in three
ways, and each changes the design:

- **The verifier is an outsider.** A consumer is not a member of the group and holds none of its
  keys. A key shared by two members (from their pairwise key exchange) lets either of them forge
  the other's approval, and lets no one else check it. So an approval is a **signature**, made with
  the member's own key pair, and the membership view lists each member's public key. The ensemble
  design's `witness_public_data` is where that key goes; the networking side needs the same change
  for its equivocation evidence (one member signing two conflicting proposals) to prove anything
  to a third member.
- **Verification is offline and late.** A consumer may check a release years after it was made,
  with no member online. Everything it needs travels as files: the group's log and the release's
  certificate.
- **There is no launcher.** A publisher group's genesis is its founders, each holding a key pair
  they made themselves; there is no bootstrap secret and no ticket. The founders sign the genesis
  record, and its hash is what consumers pin.

## Records

All records are ASCII text, one field per line, `key value`, like the manifest, so a PatLang
program reads them with `split_lines` and one split at the first space. A record's hash is the
SHA-256 of its exact bytes, LF line ends, no trailing spaces. Every record starts with a `record`
line naming its kind and format version, which domain-separates the kinds: a signature over one
kind can never be read as a signature over another.

A record holds no comments and no blank lines, so each record has exactly one byte form; the `#`
notes in the examples below are annotations, not part of the record. Format version 1 accepts one
signature algorithm, `ed25519` (32-byte keys, 64-byte signatures), until decision 3 below is made.
Readers bound their input: 65,536 bytes a record, 256 members a view, 256 signature lines a
certificate, 9,999 log entries.

### Membership view

```
record patlang-view 1
group 3f9c...              # the genesis hash; present exactly when the epoch is above 0
epoch 0
quorum majority            # or: quorum 2  (a count)
member 0 ed25519 9a41...   # slot, signature algorithm, public key (hex)
member 1 ed25519 c07e...
```

The view hash is the hash of this record. Slots are group-relative handles: they mean nothing
outside the group and epoch.

### Genesis

```
record patlang-genesis 1
package zip                # a label for the group; releases are not checked against it
view 7d2b...               # hash of the epoch-0 view
created 2026-11-08
```

followed, in a separate signature file, by one `sign <slot> <hex>` line per founder over the genesis
record's hash. Genesis needs every founder's signature. The **genesis hash** names the group from
then on.

### Epoch transition

```
record patlang-transition 1
group 3f9c...
from-epoch 0
from-view 7d2b...
to-epoch 1
to-view 51aa...            # hash of the new view, published beside it
reason admit | depart | exclude | rekey
subject 1                  # the slot admitted, departing or excluded
evidence e3d0...           # hash of an evidence record; for exclude only
revoke-from 2026-10-01     # for a compromised key: its releases dated on or after this are withdrawn
```

signed by a quorum of the `from` epoch. `revoke-from` is not allowed on an admission. For an
exclusion, the excluded member does not count in the quorum's denominator and its signature, if
present, is neither checked nor counted (the ensemble design's §15.2, item 5): under `quorum
majority` that is floor((N-1)/2)+1 of the others, and under `quorum k` it is min(k, N-1), or a
group needing all N could never exclude anyone (decision 5). Departures and rekeys are signed by the
departing or rekeying member as well. A rekey is signed with the member's old key only, so nothing
yet shows that the member holds the new one; the next change is to require a signature by the new
key too.

### Release statement

```
record patlang-release 1
group 3f9c...
epoch 1
view 51aa...
package zip
version 0.1.0
manifest 9fc9...           # hash of manifest.pkg's bytes
created 2026-11-08
```

Its certificate is one `sign <slot> <hex>` line per approving member, over the statement's hash. It
holds when the signers are distinct members of that epoch's view and their count meets its quorum.
`created` is what a `revoke-from` date is compared with. It is the signers' own claim: whoever holds
a compromised key can backdate a release to before its `revoke-from`, and offline verification
cannot tell. Only the release's other signers, still making a quorum, protect against that.

### Withdrawal

```
record patlang-withdraw 1
group 3f9c...
epoch 2
view 0c47...
package zip
version 0.1.0
reason ...
```

signed by a quorum of its epoch, which must be in the log, for a release found to be broken or
malicious. (A manifest already names exact file hashes, so a withdrawal never needs to name files.)
A withdrawal file that fails its own check refuses the package, with that failure.

### Where they live

For the repository as first source:

```
packages/<name>/trust/
  log/0000-genesis.rec, 0000-genesis.sig, 0000-view.rec
  log/0001-transition.rec, 0001-transition.sig, 0001-view.rec
  ...
  release/<version>.rec, release/<version>.sig
  withdraw/<version>.rec, withdraw/<version>.sig
```

Log entries are numbered and never rewritten. A group that publishes several packages keeps one
log, and each package's `trust/` names it with a `group` file holding the genesis hash and a path.

## Verifying a package

The consumer has a **trust store**: for each package it trusts, the pinned genesis hash, and the
highest epoch it has seen. Given a package directory:

1. Check the `file` hashes against the manifest (as now).
2. Check the genesis record's hash against the pinned one, and every founder's signature on it.
3. Walk the log: each transition must start from the epoch and view before it, and be signed by a
   quorum of that view. Each view's hash must match the transition naming it.
4. Refuse the package if the log ends below the highest epoch in the trust store (a rolled-back
   log); otherwise record the new highest epoch.
5. Check the release statement: its manifest hash, package and version match the manifest; its
   epoch and view are in the log; its signatures are a quorum of that view.
6. Refuse it if a withdrawal names it, or if any transition in the log revokes one of its signers'
   keys (matched by key, since slots are reused) from a date on or before the release's `created`
   date, and the remaining signers no longer make a quorum.

Every step is a check over public data, so verification needs no secret and can run anywhere a
consumer can read files.

### Where the first pin comes from

A package cannot vouch for its own genesis hash: whoever could change the package could change the
pin beside it. The first pin has to come from somewhere else. The options, for the owner to choose
between:

- **Shipped with the toolchain.** The PatLang distribution carries pins for the packages in this
  repository. This moves the question to how the toolchain itself is trusted.
- **On first use.** The first install records the genesis hash and later installs check against it.
  This catches a substitution after the first install, and cannot catch one before it.
- **Given by the user**, out of band, for anything outside the toolchain's own set.

These can be combined: shipped pins for the repository's packages, explicit pins for others, and
first use only when the user asks for it.

### Dependencies

Trust in a package does not carry to its dependencies. Each dependency is verified against its own
pin. A manifest may recommend a pin for a dependency:

```
depends deflate >= 0.1.0, < 0.2.0
trust deflate 3f9c...
```

A recommendation is used only when the consumer's trust store has no pin for that package and the
consumer's policy accepts recommendations from the depending package's group. Whether that policy
exists at all, and its default, is a decision for the owner.

## Resolution and installation

Verification produces facts, which the resolution rules in `packages/README.md` use:

```patlang
rule_add("pkg_trusted", ["zip", "0.1.0"], [])
rule_add("pkg_withdrawn", ["deflate", "0.0.9"], [])
```

The planner's `verify_<pkg>_<ver>` action has the effect `verified` only when verification passed,
and candidate versions that are withdrawn are never offered as actions. A trusted install is then a
plan whose every `install` step has a `verified` precondition.

## Where the cryptography runs

The rule from the ensemble design stands: no secret-handling primitive is written in PatLang.
PatLang's integers are tagged and grow into bignums, so no PatLang code can promise constant-time
behaviour on secret data.

| operation | data | where |
|-----------|------|-------|
| SHA-256 of records, manifests, files | public | PatLang (`packages/sha256`, tested against the FIPS 180-4 vectors) |
| making a key pair, signing | secret | the OS or the browser, until PatLang can do it (below) |
| verifying a signature | public | the OS or the browser, preferred; see the decisions |

v2's runtime calls `bcrypt.dll` as it calls `kernel32.dll` today, and a browser page calls
WebCrypto. A key stays inside the OS or browser as an opaque handle (`BCRYPT_KEY_HANDLE`, a
`CryptoKey`); PatLang code holds the handle, never the key's bytes, and destroying the handle
(`BCryptDestroyKey`) is the erasure the ensemble design asks of `zeroize`. Before the algorithm is
pinned, check what each gives:

- Windows CNG (`bcrypt.dll`): Ed25519 signing and verification, by Windows version. If it is
  missing, ECDSA over P-256 is the fallback, since both CNG and WebCrypto have it.
- WebCrypto: Ed25519 is newer than ECDSA P-256 there; check the browsers the presentation layer
  targets.

The format version pins one algorithm per `member` line, and there is no negotiation, so a verifier
never accepts a weaker algorithm than the one the view names.

Signature verification uses no secret, so a PatLang verifier would not leak anything through
timing. Its risk is getting an edge case wrong (non-canonical encodings, points of small order). A
PatLang verifier is acceptable only if the owner decides so, and then only when it passes a
published set of test vectors, including the negative ones (RFC 8032's for Ed25519, and Wycheproof's).

### Cryptography in PatLang itself

What stops secret-handling code being PatLang today is the integers: an operation on a tagged
integer may branch on its tag or grow into a bignum, so its time depends on its value. The way to
PatLang-native signing is a language feature, integers modulo n as a built-in numeric type
([#251](https://github.com/PatParslow/PatLang/issues/251)):

- The modulus is fixed when a value is made, so it fixes the value's width: a value never promotes,
  and every operation is a fixed loop over a fixed number of limbs, whose time depends on n alone.
- Fixed-width words are the case n = 2^k: SHA-256 and ChaCha work mod 2^32, bignum limbs mod 2^64.
  The field under Ed25519 and X25519 is the case n = 2^255 - 19, and their signatures also work
  modulo the group order.
- The spec promises that an operation's time depends only on n, and v2's tests check it: no
  branch or memory access in the compiled routines depends on a value.

With that, Ed25519 and X25519 can be written in PatLang and checked against the vectors of RFC 8032
and RFC 7748 and Wycheproof's. Until then the OS and browser do the secret work. #251 comes after
the v2 goal, as part of the numeric-system review; whether T2's OS calls are built first, or wait
for it, is a decision for the owner.

### Test oracle

Tests use Python's `cryptography` package (version 41.0.7 is installed here, with Ed25519) as the
oracle, the way the other packages' specs use `spec/oracle.py`: it makes the keys and signatures the
feature files check against, and never ships as package code.

## Where zero knowledge fits

Everything above names approvers by slot. Slots are group-relative and say nothing about who a
member is, so a group already reveals no real-world identity. What it does reveal is which slots
approved each release.

Hiding that (a consumer learns that a quorum of current members approved, and not which) is the
ensemble design's research phase: each approval carries a nullifier derived from the member's
secret, and a zero-knowledge proof that the nullifier came from some member of the view. That proof
needs a SNARK (as Semaphore uses) or a linkable ring signature, and neither is available from the OS
or the browser. Under the rule above it waits for a reviewed construction that can be written in
PatLang on modular integers (above), or called from the OS or browser.
The record formats leave room for it: a new certificate kind, `record patlang-release-zk 1`, with the
statement unchanged.

## Phases

Each phase is RED to GREEN: its feature files come first, in `packages/trust/spec/`, run by a
`run_spec.patlang` like the other packages'.

| phase | builds | done when |
|-------|--------|-----------|
| T0 | content hashes in manifests | done (`verify_manifest`, 10 ok) |
| T1 | record reader and writer; view, genesis, transition and release checks in PatLang, with the signature check passed in as a function | built 2026-11-08 in `packages/trust/`: 62 scenarios, 127 checks, signatures made and checked by the Python oracle; every adversarial case below but the trust store's rollback passes |
| T2 | `bcrypt.dll` imports in v2's runtime: key pair, sign, verify; the algorithm pinned | the T1 features pass with the OS's verify in place of the oracle's; a key's bytes never reach PatLang code |
| T3 | a `pkg` tool: `pkg genesis`, `pkg propose`, `pkg sign`, `pkg certify`, `pkg verify` | the repository's three packages get a one-member group, a genesis and release certificates, and `pkg verify` accepts them and rejects tampered copies |
| T4 | transitions: admit, depart, exclude, rekey, `revoke-from`, withdrawal; the trust store with rollback refusal | the adversarial cases below all fail as specified |
| T5 | resolution: verification as facts, `verify` actions in the install plan | installing zip plans deflate's verification first, and refuses a withdrawn deflate |
| T6 | the browser: verification through WebCrypto | the T3 verification passes in a headless browser |
| T7 | anonymous approvals | waits on a reviewed zero-knowledge construction PatLang can run |
| W | integers modulo n in the language and both v2 engines ([#251](https://github.com/PatParslow/PatLang/issues/251)); then signing and key exchange in PatLang, replacing T2's OS calls | Ed25519 and X25519 in PatLang pass RFC 8032, RFC 7748 and Wycheproof, and v2's check finds no value-dependent branch |

Adversarial cases T4 must reject: a file changed after release; a manifest changed after release; a
certificate with too few signers; one member signing twice; a signer not in the epoch's view; a
signature over a different record kind with the same bytes after its first line; a transition not
signed by a quorum of the epoch before it; an exclusion counting the excluded member; a log
truncated below the trust store's epoch; a release signed with a key revoked from a date before it;
a withdrawn release.

## Shared with the ensemble

Package trust and the networking ensemble (`docs/plans/ensemble-membership.md`) share the record
reader, the view and transition checks, and the signature calls. Package trust builds them first
(T1 to T4), since it needs no network, and the ensemble reuses them.

## Decisions for the owner

1. Where the first pin comes from (shipped, first use, given; or a combination).
2. Whether a manifest's `trust` recommendations are ever used, and the default policy.
3. The signature algorithm, once the OS and browser check above is done: Ed25519, or ECDSA P-256.
4. Whether a PatLang signature verifier is allowed before #251, under the test-vector condition
   above, where the OS or browser has none.
5. The default quorum for a new group (majority, or all founders), whether a group may change it
   by a transition (T1 allows it), and the quorum for excluding a member under `quorum k` (T1 uses
   min(k, N-1)).
6. Whether withdrawal needs the same quorum as release, or fewer (withdrawing is the safer act).
7. Whether T2's OS calls are built first, or wait for integers modulo n (#251, phase W) so that
   signing is PatLang from the start.
