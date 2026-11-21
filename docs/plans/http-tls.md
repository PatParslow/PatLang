# #272: outbound HTTP and HTTPS (TLS 1.3) for v2, then the web crawler on v2

## Context
GitHub #272: `self_hosting/examples/webcrawler.patlang` (one of #266's last
programs still on the old route) needs `http_get(url)` for arbitrary `https://`
pages. v2's TCP is loopback-only by design (review finding S15): no name lookup,
no UDP, no TLS. `regex_replace` already exists (`self_hosting/lib/regex_vm.patlang`).

Decided by the owner (2026-11-21): **a program trusts the operating system's
root store by default** (Windows: the system ROOT store; Linux:
`/etc/ssl/certs/ca-certificates.crt`). Also kept: S15's default stays, so a
program connects beyond 127.0.0.1 only after it declares so.

Already there to reuse:
- `packages/sha256` (`sha256_bytes`, incremental `sha256_new/update/finish`,
  `hmac_sha256`, `bytes_to_hex`, `hex_to_bytes`, `digest_equal`).
- `self_hosting/v2/lib/sha512.patlang` (on modints, constant-time; SHA-384 is
  SHA-512 with another IV, cut to 48 bytes).
- `self_hosting/v2/lib/curve25519.patlang` (X25519, RFC 7748 vectors, passes
  `--constant-time`: showcase P10).
- bigints and modints (`mod_make`, spec 1.14) for RSA and the NIST curves.
- `lib/ollama.patlang`'s HTTP/1.1 over loopback, for what an HTTP reader looks like.
- The opt-in pattern: `object_names_explicit()` (runtime/objects.patlang) sets a
  flag in the world's state (worlds.patlang).

## Status (2026-11-21)
- Stage 1 is written: `tcp_allow_remote()`, `dns_resolve`, `dns_query`,
  `tcp_read_status`, and `lib/http_client.patlang` with its selftest. The part 1
  scenarios pass on every engine, and gates run 17 is running. A live check
  resolved `example.org` and fetched its page over http on Windows and Linux.
- Before Stage 2, by the owner's decision: modints modulo 2^k (k up to 64) become
  as fast as ints. Measured, an add, xor and rotate on 32-bit modints cost about
  19,000 cycles compiled, against 22 on plain ints. The cryptography stays on
  modints, so the constant-time check covers it. The fast form is an
  optimisation only. A modint stays logically a modint (type_of, mod_value,
  printing, equality, errors, timing, its secrecy to the check), and the
  existing modint tests are the guard.

## Stage 1: beyond loopback, names and plain HTTP (commit 1)
- **Opt-in:** `tcp_allow_remote()`, a declaration like `object_names_explicit`: a
  flag in the world's state. Without it, `tcp_connect` keeps today's errors
  word for word; with it, any IPv4 address is allowed. `host_caps()` gains
  `"tcp_remote"` where the host can (not the browser).
- **Names:** `dns_resolve(name)` gives a list of IPv4 addresses as text, `[]` for
  none, and requires the opt-in. It is a pair of `os_*` functions, so the
  repository check holds:
  - Windows: `getaddrinfo` and `freeaddrinfo` (WS2_32), AF_INET only.
  - Linux: `/etc/hosts`, then one A query over UDP to the first `nameserver` in
    `/etc/resolv.conf`, with retries and a timeout. This needs new UDP calls in
    os_linux: socket(SOCK_DGRAM), sendto, recvfrom, poll.
  - WASM: `executor.mjs` answers `getaddrinfo` with no address.
  - IPv6 stays out of scope; the spec says so.
- **HTTP/1.1 client**, `self_hosting/lib/http_client.patlang`:
  - `http_request(method, url, headers, body, options)` gives
    `["ok", status, headers, body_bytes]` or `["err", code, detail]`;
    `http_get(url)` and `http_post(url, body, content_type)` are wrappers.
  - It reads Content-Length, chunked encoding and to-close bodies, follows up to
    `options.max_redirects` redirects (default 5), and keeps a byte limit and a
    read timeout.
  - The transport is a small interface (connect, write, read, close), so Stage 4
    plugs TLS in under it.
- **Tests (RED first):**
  - part 1 fixtures: the refusal without the opt-in, unchanged on every engine;
    the opt-in on its own; `dns_resolve("localhost")` gives `["127.0.0.1"]`.
  - `http_client_selftest`: a PatLang HTTP server on loopback serves
    Content-Length, chunked, a redirect chain, a redirect loop and a slow body.
    Body readers stay linear: timed at four sizes with cpu_cycles.
  - A real lookup through the system's resolver is one manual check, not gated,
    since the gates must not need the internet. Its result is reported.

## Stage 2: the cryptography, test-first against published vectors (commit 2)
Everything goes in `packages/tls/` with a manifest, as `packages/sha256` has. Each
file has a selftest built from the RFC vectors.
- HKDF-SHA256 and SHA-384 (RFC 5869 vectors; SHA-384 from NIST examples).
- The AEADs:
  - ChaCha20-Poly1305 (RFC 8439 §2.8.2 and Appendix A).
  - AES-128-GCM (the GCM spec's test cases), with a computed S-box and no
    table lookups indexed by secrets, so it passes `--constant-time`.
  - The client offers both, ChaCha20 first; AES-128-GCM is TLS 1.3's
    must-implement suite (RFC 8446 §9.1).
- Signature checks, on public data only:
  - RSA PKCS#1 v1.5 with SHA-256, SHA-384 and SHA-512;
  - RSA-PSS with SHA-256 (TLS 1.3's CertificateVerify for RSA keys);
  - ECDSA P-256 with SHA-256 and P-384 with SHA-384.
  - Vectors: a committed subset of Wycheproof's (Apache-2.0, credited), and RFC
    6979's keys.
- ECDHE P-256 alongside X25519, from the same field code, so a HelloRetryRequest
  that asks for P-256 is answered.
- `--constant-time` passes for X25519, the AEADs, HKDF and the key schedule. The
  signature checks see only public data, and are marked `ct_public` where they
  read it.
- Scaling: an AEAD over 16 KB to 128 KB, a doubling at a time. An RSA-2048 and a
  P-384 verify are timed and reported. A handshake verifies about four
  signatures, and a slow one needs a fix before Stage 4.

## Stage 3: certificates and roots (commit 3)
- **DER and X.509**, `packages/tls/x509.patlang`: read a certificate (TBS bytes,
  issuer, subject, validity, public key, extensions, signature).
  - Extensions handled: basicConstraints, keyUsage, subjectAltName and
    extKeyUsage.
  - An unknown extension marked critical rejects the certificate (RFC 5280
    §4.2).
  - Malformed DER gives `["err", ...]` and never stops the program. A small
    fuzz loop over mutated certificates checks that.
- **Chain checking:**
  - Build a path from the leaf, through intermediates the server sent, to a
    trusted root.
  - At each link check the signature, validity at `time_now`, CA and path
    length, and key usage.
  - The leaf's name: `subjectAltName` dNSName, with one left-most wildcard
    label (RFC 6125). IP addresses come later.
  - Revocation is out of scope, stated in the spec and in the error text.
- **Roots, the owner's choice:** `os_trust_roots()` gives a list of DER bytes,
  with the same name in both os_* files.
  - Windows: CRYPT32's `CertOpenSystemStoreW(0, "ROOT")` and
    `CertEnumCertificatesInStore`, copying each `pbCertEncoded`.
  - Linux: the PEM bundle, base64-decoded.
  - WASM: none.
  - A program can pass its own roots instead (`options.roots`); the tests do,
    to trust a test CA.
- **Fixtures:** a test CA, an intermediate and leaves (good, expired, wrong
  name, not a CA, wrong key usage, unknown critical extension). They are made
  once with `openssl` in WSL by a committed script, and the DER files are
  committed with the script that regenerates them.

## Stage 4: the TLS 1.3 client and HTTPS (commit 4)
- **The client**, `packages/tls/tls13.patlang`:
  - The record layer, and a ClientHello carrying SNI, supported_versions (1.3
    only), key_share (X25519, then P-256 after a HelloRetryRequest),
    signature_algorithms and ALPN `http/1.1`.
  - The key schedule (RFC 8446 §7).
  - EncryptedExtensions, Certificate, CertificateVerify and Finished.
  - close_notify. A KeyUpdate from the server is accepted. Session tickets are
    received and dropped.
  - No 0-RTT, no resumption, no client certificates.
  - An alert or a malformed message ends the connection with
    `["err", "tls", detail]`.
- **RED, from RFC 8448 §3** (a full 1-RTT trace): with the trace's own client
  random and key share fed in, the client's ClientHello, derived secrets and
  Finished match the trace byte for byte. Then the client reads the trace's
  server flight and decrypts its application data.
- **Against a real server, gated with no internet:** `openssl s_server -tls1_3`
  in WSL, on loopback, with the Stage 3 test CA. Scenarios:
  - an https GET succeeds with `options.roots` set to the test root;
  - the same with no roots given fails as untrusted;
  - a wrong name fails, naming it;
  - an expired leaf fails;
  - a server limited to `-ciphersuites TLS_AES_128_GCM_SHA256` works;
  - `-groups P-256` makes a HelloRetryRequest.
  - The selftest fails by name when wsl or openssl is missing.
- `http_client` takes `https://` URLs over the TLS transport. Certificate errors
  are never ignored, and nothing turns the checks off.
- **One manual check over the internet** with the OS roots (`https://example.org`
  on Windows, and under WSL on Linux). It is reported, not gated.

## Stage 5: the web crawler on v2 (commit 5)
- Port `self_hosting/examples/webcrawler.patlang`:
  - its includes go to `lib/http_client.patlang` and `lib/regex_vm.patlang`;
  - it calls `tcp_allow_remote()`;
  - it gets status and quit signals, per CLAUDE.md §6.
- Take it off the repository check's allowed list, so the check proves it.
- A gated run crawls the Stage 4 s_server, which serves a few linked pages; a
  live crawl of a public site is a manual check.

## Docs, each stage
- `docs/spec/values-and-memory.md`: the opt-in, `dns_resolve`, `os_trust_roots`,
  `host_caps`, what is out of scope (IPv6, revocation, resumption, 0-RTT,
  client certificates).
- `packages/README.md` and `packages/tls/README.md`; the vectors' sources and
  their licences.
- `docs/plans/gates.md`: the new selftests and the WSL/openssl dependency.
- Close #272, and #266's crawler item, after Stage 5's gates pass.

## Verification
- Every piece RED then GREEN, on the interpreter, a Windows build and a Linux
  build under WSL, with outputs compared.
- `--constant-time` on the secret-handling code: no reports.
- Scaling at four sizes for the AEADs, the DER reader and the HTTP body reader.
- Gates with `--cap 12` before each commit. Each commit is staged explicitly with
  the attribution lines. Nothing is pushed unless asked.
