# v2 examples: integers modulo n and the cryptography built on them

Programs that use modints (spec 1.14), the constant-time check (spec 2.7), and SHA-512, X25519 and
Ed25519, which the `sha512` and `curve25519` packages (`packages/`) write in PatLang (#251). Build and run any of them with v2:

```
./self_hosting/build/v2.exe self_hosting/v2/examples/<name>.patlang <name>.exe
./<name>.exe
```

v2 has no random source yet, so keys and seeds come from a hash of a fixed phrase, and every run
prints the same output. The programs print secret keys so that the arithmetic can be followed. A
real program would not.

| program | shows | build and run, measured three at a time |
|---------|-------|---------|
| `modint_tour` | clock arithmetic, inverses and division, Fermat modulo 2^255 - 19, Diffie-Hellman modulo 23, the Chinese remainder theorem, and words modulo 2^32 that wrap, rotate and shift | 37 s |
| `hashing` | SHA-512 of "abc" and "" against FIPS 180-4, and 32-bit FNV-1a in a few lines on a word modulo 2^32 | 38 s |
| `key_exchange` | Alice and Bob agree a key over X25519; Eve, with her own secret, gets another | 39 s |
| `signatures` | an Ed25519 signature verifies, while a changed message, a changed signature and another key do not; signing is deterministic | 63 s |
| `handshake_attacks` | attacks on a signed X25519 handshake (below) | 116 s |
| `trust_attacks` | attacks on package trust (below) | 424 s |
| `ct_leaky_pow`, `ct_clean_pow` | the same secret-exponent power, with a branch and without; for `--constant-time` | the check: 164 s each |

## The constant-time check

```
./self_hosting/build/v2.exe self_hosting/v2/examples/ct_leaky_pow.patlang --constant-time
v2 constant-time: leaky_pow: a branch decides on a secret
v2 error: 1 places where the time can depend on a modint's residue

./self_hosting/build/v2.exe self_hosting/v2/examples/ct_clean_pow.patlang --constant-time
v2: no value-dependent branch or access
```

`ct_leaky_pow` multiplies only when the exponent's bit is 1. `ct_clean_pow` multiplies every step by
`1 + bit * (g - 1)`, which is g when the bit is 1 and 1 when it is 0.

## `handshake_attacks`

Alice and Bob have pinned each other's Ed25519 identity keys. Alice sends an ephemeral X25519 key
`ea`. Bob replies with his `eb` and a signature over `"bob" ea eb`, and Alice answers with a
signature over `"alice" ea eb`. Mallory controls the wire.

| attempt | outcome |
|---------|---------|
| a man in the middle when nothing is signed | succeeds: Mallory holds both session keys |
| the same with signatures | refused: Bob signed the keys he saw, which are not the ones Alice saw, and Mallory's own signature is not Bob's |
| Bob's reply replayed from an earlier handshake | refused: it signs the old `ea` |
| Alice's own signature reflected back as Bob's | refused, even against Alice's key, because the role name differs |
| a public key of small order (u = 0, u = 1, a point of order 8) | X25519 gives all zeros for every secret key; the handshake refuses a shared secret of zeros |
| an outsider without the group's bootstrap secret | shares an X25519 key with Alice, and fails the HMAC-SHA-256 key confirmation that mixes in the secret (as `docs/plans/ensemble-membership.md`'s handshake does) |

## `trust_attacks`

This runs `packages/trust`'s checks (`docs/plans/package-trust.md`) with `ed25519_verify` as the
verifier, and makes every key and signature in PatLang. Keys come from the seeds
`packages/trust/spec/oracle.py` uses, and the four public keys printed are the ones it gives.

The publishers of `zip` are alice, bob and carol, and two of the three are needed. Carol's key leaks,
so alice and bob exclude her at epoch 1, revoke her key from 2026-11-01, and release 0.1.0. A
consumer has pinned the group's genesis hash. The genuine release is accepted. Mallory's attempts
to get her trojan installed:

| # | attempt | outcome |
|---|---------|---------|
| 1 | the trojan under the genuine release | `manifest-mismatch` |
| 2 | a release signed with her key as alice and bob | `bad-signature` |
| 3 | signed as a slot the group does not have | `not-member` |
| 4 | alice's genuine signature on the trojan, listed twice | `duplicate-signer` |
| 5 | alice's signature alone | `too-few` |
| 6 | 0.1.0's signatures copied onto a release of 0.2.0 | `bad-signature` |
| 7 | a counterfeit group of her own | `pin-mismatch`, to a consumer who pinned the real group; **accepted** by one who pins on first use |
| 8 | carol's leaked key with alice's signature, at epoch 1 | `not-member` |
| 9 | the same at epoch 0, dated after the revocation | `revoked` |
| 10 | the same, backdated to before the revocation | **accepted**: the plan's stated limit, since only a release's other signers stop a backdated one and here alice signed |
| 11 | bob's signature with L added to S, the same scalar modulo L | `bad-signature`: the verifier requires S < L (RFC 8032 5.1.7) |
| 12 | one bit of bob's signature flipped | `bad-signature` |
| 13 | a log entry admitting herself, signed with carol's key and her own | `not-member` |
| 14 | the exclusion replayed to roll the log back | `epoch-mismatch` |
| 15 | a withdrawal signed with her own key | `bad-signature`, which still refuses the package: she can block the release, but cannot get the trojan in |

When alice and bob withdraw 0.1.0 themselves, the result is `withdrawn`.

The two accepted cases are where the plan places the trust: in the first pin, and in a release's
other signers.
