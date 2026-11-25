# Where these test vectors come from

- `rfc8032_ed25519.txt`: the five Ed25519 test vectors of RFC 8032 section 7.1 (TEST 1, 2, 3,
  1024 and SHA(abc)), taken from the RFC's text (https://www.rfc-editor.org/rfc/rfc8032.txt) on
  2026-11-23: under each heading, the lines made wholly of hex digits, joined. RFC 8032 is
  covered by the IETF Trust's licence for code components.
- `wycheproof_ed25519_test.json`: Project Wycheproof's Ed25519 test set,
  `testvectors_v1/ed25519_test.json` from https://github.com/C2SP/wycheproof, unchanged, fetched
  2026-11-23: 210 cases (117 valid, 64 invalid, 29 acceptable). Wycheproof is under the Apache
  License 2.0.

Both are read by `spec/run_spec.patlang` for `curve25519.feature`; neither ships with the package.
