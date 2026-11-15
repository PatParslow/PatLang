# Ensemble membership

Independent PatLang processes, started by a launcher that then leaves, find one another, prove they
belong to the same group, agree a membership, make decisions by quorum, and admit or exclude members,
with no certificates, no outside authority and no lasting process identity.

This is the project owner's design "PatLang Ensemble Membership" (draft 0.1, 17 October 2026), revised
on 2026-11-08 for PatLang without Rust and for its use in package trust
(`docs/plans/package-trust.md`). "Revisions" at the end lists what changed from draft 0.1. The
ensemble itself is not built. Two of the parts it rests on are: the record, view and transition
checks shared with package trust (`packages/trust/`, T1 of `package-trust.md`), and X25519 and
Ed25519 written in PatLang (`self_hosting/v2/lib/`), whose use in a signed handshake
`self_hosting/v2/examples/handshake_attacks.patlang` tests against a man in the middle, replay,
reflection, keys of small order and an outsider without the group secret.

## Goals

| goal | design response |
|------|-----------------|
| no certificates or outside PKI | membership starts from launcher-provisioned bootstrap material; the genesis record is the group's own root |
| no lasting process identity | group-relative handles and epoch-bound membership witnesses |
| membership of several groups | separate state per group: keys, epochs, handles, transcripts |
| distinct votes without public identity | one witness per admitted membership; decision-scoped nullifiers in the research phase |
| membership the ensemble governs | admission and exclusion are committed configuration transitions |
| collective authentication | signed approvals, collected into a quorum certificate bound to the exact message and epoch |
| no Rust | everything is PatLang compiled by v2; the only other code called is the OS's and the browser's |

### In scope

- Discovery on a local or controlled network where addresses are known and service ports are not.
- Mutual authentication of shared bootstrap knowledge, with no certificates.
- Genesis without a continuing coordinator.
- One process in several groups that cannot be linked.
- Temporary handles within a committed epoch.
- Decisions approved by distinct members, by quorum.
- Admission, departure, quarantine, exclusion, revocation and reinstatement.
- Facts, rules, goals, planning and message queues over ensemble state.
- Reproducible transcripts, and adversarial tests on both v2 engines and in the browser where its
  networking allows.

### Not in scope for the first implementation

- Internet-scale discovery or NAT traversal.
- General Byzantine consensus under full asynchrony.
- Claims of real-world identity, personhood or hardware attestation.
- Perfect unlinkability together with permanent revocation: the design states where it sits between
  them.
- Cryptographic primitives on secret data written in PatLang before integers modulo n exist
  ([#251](https://github.com/PatParslow/PatLang/issues/251)); see "Cryptography".
- Parity with mature TLS.
- Punishment based only on subjective distrust.

## Terms

| term | meaning |
|------|---------|
| group | a named cryptographic and protocol domain with its own membership history |
| launcher | a transient provisioner that starts processes and gives each a bootstrap package |
| bootstrap secret | 256-bit group material proving initial eligibility; never a member's identity |
| launch ticket | a unique, one-use authorisation for one bootstrap |
| membership witness | the member's signing key pair, issued at admission and bound to an epoch; the private key stays with the member, the public key is in the view |
| handle | `(group, epoch, slot, incarnation)`, meaningful only inside that group and epoch |
| membership view | the exact set of current handles and their public keys |
| epoch | a membership configuration number that only increases |
| nullifier | a value derived from a witness and a decision, showing one witness was counted at most once without revealing it (research phase) |
| quorum certificate | signatures of the required number of distinct members over one exact statement |
| exclusion certificate | a quorum certificate over a transition that removes a member |

### Invariants

- Every signed or authenticated statement is domain-separated by protocol, purpose, group, epoch,
  view hash and message type.
- One witness contributes at most one approval to a decision.
- A handle means something only within one group, epoch and incarnation.
- No process accepts two conflicting committed transitions from the same prior configuration.
- Authority from an old epoch never becomes current-epoch authority.
- Admission and exclusion are configuration transitions, never local edits to a peer list.
- Bootstrap eligibility does not imply membership after genesis.
- A cryptographic check passing never bypasses the application's own authorisation or resource
  limits.
- A member's choice between proposals, or a rejection that claims no failed check, is never
  grounds for a challenge, quarantine or exclusion. Only disagreement about a checkable claim is.

## Architecture

```
Launcher (transient)
  └─ bootstrap package per process
       ├─ group_id
       ├─ bootstrap_secret
       ├─ launch_ticket
       ├─ peer_ip_hints, discovery port range
       └─ genesis policy (minimum members, quorum, expiry, protocol version)

PatLang process (v2-compiled)
  ├─ discovery
  ├─ pairwise handshake
  ├─ per-group membership state machine
  ├─ quorum collector
  ├─ record channel
  ├─ evidence and exclusion
  └─ API and fact projection for PatLang programs
```

### Trust boundaries

- The launcher is trusted only to provision the intended candidates and tickets, and for nothing
  after.
- A peer is untrusted until its handshake succeeds, and only provisionally trusted until genesis or
  admission commits.
- An admitted member may later turn faulty or hostile; membership is revocable.
- The network may observe, delay, duplicate, reorder, replay or change traffic.
- The OS and the browser are trusted for the cryptographic operations they provide (see
  "Cryptography") and for sockets. Nothing else outside v2-compiled PatLang is trusted.
- PatLang application code never holds a raw secret: it holds OS or browser key handles.

### Per-group state

```
GroupState {
  group_id, protocol_version
  status: bootstrapping | active | suspended | closed
  epoch, view_hash
  members: Handle -> public key
  local_handle
  local_witness          # an OS or browser key handle
  bootstrap_policy, quorum_policy
  peer_channels
  committed_log_head
  revocation_state
}
```

A process holds any number of these. No key, nonce, ticket, witness, sequence number or nullifier is
reused across groups.

## Lifecycle

### Provisioning

1. Make a random group identifier and a 256-bit bootstrap secret.
2. Make one random launch ticket per process; keep only their hashes if the launcher needs nothing
   more.
3. Give each process the candidate addresses, a discovery port range, an expiry, the minimum genesis
   size, the quorum policy and the protocol version.
4. Start the processes. The launcher may exit at once, or after it sees genesis commit.

### Discovery when ports are unknown

Each process binds an ordinary service port and answers discovery probes on a small configured
range (for example 45000 to 45010 on one host, where several processes cannot share one port). A
probe carries `HMAC(bootstrap_secret, "discover" || time_window)`, so it shows neither the group's
name nor its existence to anyone without the secret, and an unauthenticated probe gets no service
port back. Probes are bounded, stateless where possible and rate-limited.

```
DISCOVER { protocol_version, hint = HMAC(secret, "discover" || window), nonce_a, ephemeral_a }
OFFER    { nonce_a, nonce_b, service_endpoint, ephemeral_b, cookie }
```

### Pairwise handshake

The bootstrap secret has 256 bits, so it cannot be guessed and needs no password-authenticated key
exchange: an ephemeral X25519 exchange with the secret mixed into the transcript (the pattern
Noise's `psk` handshakes and TLS 1.3's `psk_dhe_ke` use) gives both sides a shared key only another
holder of the secret could derive.

- The transcript binds both nonces, both ephemeral keys, the endpoints, the protocol version, the
  group identifier, the genesis parameters and the hash of the sender's launch ticket.
- Key confirmation runs in both directions.
- Separate keys are derived (HKDF) for confirmation, discovery cookies, record authentication,
  encryption and later stages.
- Neither the bootstrap secret nor a launch ticket is ever sent in the clear.
- Oversized, malformed, repeated, expired or cross-group transcripts are rejected before any
  expensive work.

### Genesis

Peers launched together have no member set yet. Over their pairwise channels they exchange candidate
records, each carrying a freshly made signing public key (the candidate's witness) and its launch
ticket, now revealed under encryption. A duplicate or unlisted ticket aborts genesis.

```
GenesisRecord {
  group_id, epoch = 0
  members: [(slot, public key)]   # slots in order of the public keys' bytes
  ticket hashes consumed
  quorum_policy, protocol_version
  transcript_root, created_at
}
genesis_id = SHA-256(canonical encoding)
```

Genesis commits when at least `min_genesis_members` candidates have appeared within the genesis
timeout and every one of them has signed the identical record. After it commits, the bootstrap
secret is erased, or kept only as one factor of an invitation that still needs the ensemble's
approval.

## Messages and agreement

### Record envelope

```
Record {
  protocol_version, group_id, epoch, view_hash
  sender_handle, channel_id, sequence_number
  message_type, payload_hash
  ciphertext_or_payload
  authenticator
}
```

- Per-channel sequence numbers increase; duplicates are rejected.
- The authenticator covers the whole canonical envelope.
- Sizes, times, queues and concurrent checks are bounded.
- Records may be encrypted with an AEAD under keys from the pairwise handshake.
- A new epoch means new keys.

Channel authentication uses the pairwise keys. Anything that may need to convince a third member
(approvals, proposals, evidence) is also **signed** with the sender's witness: a pairwise key lets
either holder forge the other's message, so only a signature proves to someone else who said it.

### Approvals

| mode | what travels | when |
|------|--------------|------|
| explicit | one signed approval per handle | phase 1: easiest to inspect, debug and show |
| aggregated | the approvals collected into one certificate | phase 2: less traffic, approvers still visible by handle |
| anonymous | one proof that at least t distinct current witnesses approved | research phase: approvers hidden |

### What a vote states

A proposal names its **checks**: conditions over the committed log and the payload, such as the
`require` clauses of the action it proposes or a plan's GOAP preconditions. Each check is named by
the hash of its PatLang source, and must be a pure function of the log at a given head and the
payload: no clock, no randomness, no local state, so every member computes the same answer. The
discipline of the v2 engines' agreement suite applies: a check gives the same result on both
engines.

```
Vote {
  group_id, epoch, view_hash, decision_id, payload_hash
  log_head                                  # the head the checks were run against
  verdict: approve | reject
  checks: [(check_hash, holds | fails)]     # all of them to approve; those that failed to reject
  signature
}
```

An approval says "every check holds at this head". A rejection either names the checks it found
failing, or names none: a rejection naming none is a choice, and nothing follows from it. A member
may also not vote at all.

### Distinctness and nullifiers

A quorum means distinct admitted memberships. In the anonymous mode each approval carries

```
context   = H(group_id || epoch || view_hash || decision_id || payload_hash)
nullifier = PRF(witness secret, "vote" || context)
```

with a zero-knowledge proof that the nullifier was derived from the secret of some key in the
current view, and the verifier counts unique nullifiers with valid proofs. A nullifier is scoped to
one decision and is not an identity. The proof is the hard part: it needs a SNARK (as Semaphore
uses) or a linkable ring signature. Neither is offered by the OS or the browser, so the anonymous
mode waits until a reviewed construction can run in PatLang, on integers modulo n (#251).

### Agreement

A bounded agreement service, stated as such and not offered as general Byzantine consensus:

- A proposal extends one committed log head and names the current epoch and view hash.
- A member approves at most one of any conflicting proposals for a decision slot.
- A proposal commits when a quorum of current members signs the identical canonical proposal:
  floor(N/2) + 1 of N by default.
- The certificate and the new log head are written and flushed to disk before anything acts on
  them.
- Two conflicting certificates, if ever seen, are evidence of a protocol failure and stop the
  process safely.

The network model claimed: partially synchronous (messages arrive within a bound during agreement),
crash-recovery, and equivocation detected and treated as fail-stop evidence. Every demo's transcript
states its own model.

### Divergence checks

Members who disagree about a choice are what voting is for, and the quorum settles it. Members who
disagree about a fact show that at least one is behind, cut off, faulty or lying, and that is worth
asking about. Divergence checks question **claims and state, never votes**:

| divergence | seen when | what happens |
|------------|-----------|--------------|
| state | votes on one decision name different epochs, view hashes or log heads | each member is asked for its signed state |
| check | one vote says a check holds at head H and another says it fails at H | every member evaluates the check at H itself |
| key | traffic for a stale epoch under a current handle, or a key thought stolen | the handle is asked to sign a fresh nonce |

```
STATE?  { group_id, epoch, nonce, challenger, cause, signature }
STATE   { group_id, nonce, epoch, view_hash, log_head, sequence, signature }
PROVE?  { group_id, epoch, handle, nonce, challenger, cause, signature }
PROVEN  { group_id, epoch, handle, nonce, signature }
```

What follows from the answers:

- **A member behind** (its head an ancestor of the committed one) catches up: it fetches the
  certificates between the two heads and checks each. Nobody is blamed.
- **A head with no certificate**, presented as committed, is objective evidence: a head is committed
  only with its quorum certificate.
- **Two different signed states** from one handle for the same epoch and sequence number are
  equivocation, handled as in "Exclusion".
- **A false check claim**: every member re-runs the check at H, and the vote that got it wrong is a
  signed false statement. That is objective, but it cannot tell a lie from a bug in the member's
  engine, so on its own it leads to quarantine and a report naming the check's source hash.
  Exclusion needs the usual quorum, with the evidence.
- **Two different `PROVEN` answers** for one nonce mean two processes hold the same key: evidence of
  a stolen key, leading to a rekey. A thief who stays silent is not caught this way; the check is
  cheap, and not complete.
- **No answer** by the agreement bound is operational evidence, never proof of malice: the member
  may be cut off.

Limits, so that questioning cannot be used as an attack:

- Challenges are signed, so every one is attributable.
- A challenge names its cause: the two conflicting votes, or the stale record. A challenge naming
  none is dropped.
- Each member may challenge each other member a bounded number of times per epoch (the bound is in
  the quorum policy). Challenges beyond it are dropped, and the excess is operational evidence
  against the challenger.
- Challenges and answers go into the transcript.

In the anonymous mode a vote's check claims travel inside its proof. A verifier re-runs the checks
at the stated head and does not count a vote whose claims are false; it cannot blame the voter
without linking the vote to a member, which the mode exists to prevent. State divergence is handled
as above, since asking for state reveals nothing about votes.

## Membership change and exclusion

```
candidate -> active -> suspected -> quarantined -> excluded -> revoked
               ^            |                           |
               +------------+-------- reinstated -------+
```

Suspicion is a claim; quarantine a temporary restriction; exclusion removes current authority;
revocation tries to prevent re-entry under the same credential.

### Evidence

```
Evidence { group_id, epoch, reporter, accused, reason, items[], evidence_hash, observed_at, signature }
```

- Objective: two signed conflicting records, a duplicate vote, an invalid proof, authority from a
  stale epoch, conflicting transitions, a head presented without its certificate, a false check
  claim (see "Divergence checks" for how far that goes). Signatures make these checkable by every member.
- Operational: repeated malformed traffic, resource exhaustion, missed deadlines, refusing a
  challenge.
- Subjective: distrust with nothing checkable. Enough for investigation or quarantine; durable
  exclusion needs a higher threshold.

### Exclusion

```
ExcludeProposal { prior_epoch, prior_view_hash, accused, evidence_hash, next_epoch, next_view_hash, rekey_commitment }
```

The accused is left out of both the voters and the denominator: an exclusion commits with
floor((N - 1)/2) + 1 signatures of the N - 1 others, so a compromised or silent member cannot block
its own removal. On commit: install the new view, advance the epoch, rotate keys, refuse old-epoch
authority, and keep the exclusion certificate in the log.

### Blacklisting without public identity

| mechanism | prevents | limitation |
|-----------|----------|------------|
| handle tombstone | replay by the removed handle | does not stop a fresh admission |
| launch-ticket burn | reuse of one bootstrap entitlement | needs the ticket hashes kept |
| witness revocation | return under the same key | needs the key to be linkable |
| evidence-backed denial | reinstatement unless the ensemble overturns the evidence | needs a link between applicant and excluded credential |
| bootstrap rotation | use of a compromised group secret | needs new material distributed securely |

The choice made: tickets are burned at genesis and recorded, the bootstrap secret is retired after
genesis, excluded handles are tombstoned, and re-entry needs an invitation the ensemble approves,
which gives a fresh handle and incarnation. Perfect fresh anonymity and durable blacklisting cannot
both hold unless an applicant proves hidden continuity with a revocable credential, and this design
does not attempt that.

## API for PatLang programs

Group operations, never raw cryptography. Secrets stay behind key handles.

```patlang
let group = ensemble_bootstrap(package_path)
let status = ensemble_wait_for_genesis(group, timeout_ms)
let events = ensemble_poll(group)
let proposal = ensemble_propose(group, "adopt_plan", payload)
let decision = ensemble_seek_agreement(group, proposal, "majority")
let evidence = ensemble_report(group, accused, reason, items)
let result = ensemble_propose_quarantine(group, evidence)
let result = ensemble_propose_exclusion(group, evidence)
let invite = ensemble_create_invitation(group, policy)
let joined = ensemble_join(invite)
let left = ensemble_leave(group)
```

These are ordinary PatLang functions in the ensemble package, taking a context argument rather than
reading globals.

### Facts

```patlang
rule_add("member", ["g", "peer_4", "7"], [])
rule_add("quorum_proved", ["g", "proposal_31", "3"], [])
rule_add("committed", ["g", "proposal_31", "92"], [])
rule_add("excluded", ["g", "peer_6", "8"], [])
```

and likewise `authenticated_peer`, `proposal`, `approval`, `suspected` and `diverged`. With approvers hidden,
only `quorum_proved` is asserted, never the individual approvals.

### Events

`group.discovery.candidate_seen`, `group.handshake.succeeded`/`failed`,
`group.genesis.proposed`/`committed`,
`group.membership.admitted`/`departed`/`quarantined`/`excluded`/`reinstated`,
`group.proposal.received`/`approved`/`committed`/`rejected`,
`group.security.replay`/`equivocation`/`malformed`/`rate_limited`,
`group.divergence.state`/`check`/`key`/`resolved`, `group.epoch.changed`; raised
with `emit`, handled with `when`.

## Without Rust

Draft 0.1 placed the implementation in `rust-runtime/src/ensemble/`, mirrored its host functions into
`hosts.rs`, `codegen.rs` and `runtime_rs.patlang`, and relied on Rust crates. None of that applies
after the Rust removal (`docs/plans/removing-rust.md`):

| draft 0.1 | now |
|-----------|-----|
| `rust-runtime/src/ensemble/` (codec, domain, membership, records, agreement, evidence, reconfigure, persistence, limits) | a PatLang package, `packages/ensemble/`, compiled by v2; the state machine takes its transport as a parameter, so its features run on simulated transports |
| `discovery.rs`, sockets | v2's runtime calling `ws2_32.dll`: TCP, which v2 has, and UDP for discovery, to add; a browser page has no UDP, so it joins through a relay or not at all, as each demo states |
| `spake2` crate | not needed: X25519 with the bootstrap secret in the transcript (see "Pairwise handshake") |
| `hkdf`, `sha2`, `chacha20poly1305` crates | SHA-256 and HKDF in PatLang on public inputs (`packages/sha256`); secret-keyed work by the OS (see "Cryptography") |
| `zeroize` crate | keys live only behind OS or browser handles, destroyed with `BCryptDestroyKey` |
| `hosts.rs`, PRELUDE and `runtime_rs.patlang` parity | v2's runtime only: one implementation, nothing to mirror |
| `rust-runtime/tests/ensemble_*.rs` | Gherkin features under `packages/ensemble/spec/` with a Python oracle, like the other packages |
| facts in `patlang_runtime::logic_engine` | `rule_add` from PatLang code |

## Cryptography

No secret-handling primitive is written in PatLang until integers modulo n exist (#251): an
operation on a tagged integer may branch on its tag or grow into a bignum, so its time depends on
its value. Until then:

| operation | data | where |
|-----------|------|-------|
| SHA-256, HKDF and HMAC on public inputs | public | PatLang |
| key pairs, signing, X25519, AEAD, HMAC under a secret key | secret | the OS (`bcrypt.dll` from v2's runtime) or the browser (WebCrypto) |
| signature verification | public | the OS or browser, preferred |

To check before the algorithms are pinned: which Windows versions' `bcrypt.dll` offers Ed25519 and
X25519, whether it offers ChaCha20-Poly1305 (it has AES-GCM), and the browsers' WebCrypto support
for Ed25519 and X25519. ECDSA and ECDH over P-256 with AES-GCM are the fallback both have. The
protocol version pins the algorithms; there is no negotiation and so no downgrade.

With #251, the modulus fixes a value's width and the spec promises an operation's time depends only
on n, which v2's tests check. Then Ed25519, X25519 and ChaCha20-Poly1305 can be PatLang, checked
against RFC 8032, RFC 7748, RFC 8439 and Wycheproof, and the OS calls retire. The anonymous mode's
proofs would be built the same way, once a reviewed construction is chosen.

Every check accepts bounded byte strings and returns a structured failure. Transcript test vectors,
positive and negative, live in the repository.

## Plan

Small RED to GREEN slices. No claim of anonymity, consensus safety, forward secrecy or revocation is
made until the adversarial tests for it pass.

| milestone | builds | done when |
|-----------|--------|-----------|
| M0 | records, canonical codec, domain separation, GroupState and transitions in memory | no network; encodings and separators tested; the record and view checks shared with package trust (`package-trust.md`, T1) |
| M1 | UDP discovery in v2's runtime, random service ports, rate limits | N processes on known addresses find each other's endpoints; wrong-group probes learn nothing |
| M2 | the pairwise handshake through the OS | same-group peers derive matching keys; a wrong secret, a replay and a changed transcript all fail |
| M3 | tickets, candidate ordering, genesis | independent peers commit the same epoch-0 view after the launcher exits |
| M4 | the record envelope, replay protection | tampered, duplicated, wrong-group, stale-epoch and reordered records behave as specified |
| M5 | signed votes with their checks, quorum certificates | a proposed PatLang plan commits only with a quorum, and only when its checks hold at the head its approvals name |
| M5a | divergence checks: state, check and key challenges, catch-up, limits | each divergence row resolves as specified, and a member who always rejects without naming a check is never challenged |
| M6 | several groups per process | one process in G and H with unrelated handles and no key or sequence reuse |
| M7 | evidence, quarantine, exclusion, rekey | an excluded member cannot authenticate current-epoch records or count in a quorum |
| M8 | nullifiers and proofs | waits on #251 and a reviewed construction |
| M9 | fuzzing, bounds, crash recovery, a transcript viewer | malformed input is cheap to reject; a restart keeps the committed view |

### Demonstrations

Each shows a live event timeline and a machine-readable transcript, and states its network and
failure model.

| demo | shows |
|------|-------|
| D1 launcher leaves | five workers form a group and commit genesis after the launcher exits |
| D2 wrong group | G and H on the same addresses never admit each other, and the logs leak no secret |
| D3 one process, two groups | its handles, epochs, channels and keys in G and H cannot be linked |
| D4 decision | of three plans put to a 3-of-5 group, only the one with three distinct approvals commits; a duplicate approval is refused |
| D5 anonymous quorum | as D4 with approvers hidden; waits on M8 |
| D6 quarantine | a member sending malformed traffic is quarantined and traffic goes on |
| D7 exclusion | a member signing two conflicting proposals is excluded; the others move to epoch E+1, rekey and refuse its messages |
| D8 re-entry | the excluded process restarted with its old key and ticket is refused; an approved invitation readmits it with a new incarnation |
| D9 partition | the minority cannot commit; on reconnection all converge or stop safely |
| D10 goal | a quorum certificate becomes a fact that lets `activate(plan)` run |
| D11 divergence | a member cut off rejoins behind and catches up unblamed; a member approving a plan whose precondition fails at the named head is quarantined; a member who rejects everything is never challenged |

### Tests

| area | positive | adversarial |
|------|----------|-------------|
| discovery | known peers find random ports | probe floods, a wrong hint, a forged offer, a stale window |
| handshake | the same secret confirms keys | a wrong secret, replay, a relayed man in the middle, reflection, a changed transcript |
| genesis | all commit the same record | a duplicate ticket, a missing candidate, two orderings, an expired package |
| records | ordered messages check and decrypt | a flipped bit, a duplicate, a stale epoch, a wrong group, an oversized payload |
| agreement | a quorum of distinct approvals commits | a repeated nullifier, conflicting approvals, too few approvals |
| divergence | a member behind catches up; a stolen key answering twice is caught | a false check claim; a head without its certificate; a challenge naming no cause; challenges past the bound; a dissenting minority challenged for its votes (must never happen) |
| several groups | each group progresses alone | a key, nonce, handle or proof moved across groups |
| exclusion | the new epoch excludes its target | a local-only deletion, a reused old certificate, the accused counted in the denominator |
| persistence | a restart recovers the log and witness | rollback to an old epoch, a truncated log, a repeated sequence number after restart |
| resources | normal traffic stays bounded | handshake amplification, expensive-proof floods, queue growth, codec fuzzing |

The state machine's features run on both v2 engines over simulated transports. Socket features run
where the engine has the sockets; the browser's limits are stated in each feature.

## Decisions recorded

| decision | choice |
|----------|--------|
| discovery | UDP probes carrying an HMAC hint, over a configured port range |
| handshake | ephemeral X25519 with the bootstrap secret in the transcript, HKDF-SHA-256, an AEAD from the OS |
| launch tickets | 256-bit random values; their hashes in the package; revealed under encryption at genesis and burned |
| genesis | within a timeout, at least the minimum number of candidates, all signing the identical record |
| quorum | floor(N/2) + 1; exclusion floor((N-1)/2) + 1 of the others, the accused not voting |
| approvals | signed per handle first; aggregated next; anonymous when M8 can be built |
| linkability kept for revocation | burned tickets, tombstoned handles, retired bootstrap secret, readmission only by invitation |
| keys | behind OS or browser handles; the committed log written and flushed before acting |
| network model | partially synchronous, crash-recovery, equivocation as fail-stop evidence |

### Still open

- The signature and key-exchange algorithms, after the OS and browser check.
- Whether M2 uses the OS's X25519, or waits for #251 so the handshake is PatLang from the start.
- How a browser page takes part: through a relay member, or as an observer only.
- Whether subjective evidence can ever lead to exclusion, and at what threshold.
- The challenge bound per member per epoch.
- Whether repeated false check claims, with no other evidence, can lead to exclusion, and after how
  many: each one may be an engine bug.
- What a check may use (the PatLang subset that counts as pure), and how a proposal's checks travel
  (by source hash, the source fetched from the proposer or the log).

## Revisions from draft 0.1

- **Signatures for approvals and evidence.** Draft 0.1 recorded "explicit per-handle signatures"
  but derived only pairwise symmetric keys, which let either holder forge the other's message and
  prove nothing to a third member. The witness is now a signing key pair, its public key in the view.
- **No password-authenticated key exchange.** The bootstrap secret has 256 bits, so X25519 with the
  secret in the transcript replaces SPAKE2.
- **No Rust.** Draft 0.1's `rust-runtime/` layout, host-function mirrors and crates are replaced as
  in "Without Rust".
- **Cryptography.** Secret-keyed operations are the OS's or browser's until integers modulo n
  (#251) let them be PatLang; the anonymous mode waits on #251 and a reviewed construction.
- **Divergence checks.** Votes state the head and the checks they ran, and disagreement about a
  checkable claim or about state is questioned; disagreement about a choice never is. Added on
  2026-11-08 from the owner's question of interrogating members who disagree.
- **Package trust.** The records, view checks and signatures are shared with
  `docs/plans/package-trust.md`, which builds them first.
- Draft 0.1's references (RFC 9382, RFC 9807, the NIST threshold-cryptography project, Hu et al. on
  DAG-BFT reconfiguration, Garg et al. on threshold anonymous credentials) are kept in the owner's
  original document.
