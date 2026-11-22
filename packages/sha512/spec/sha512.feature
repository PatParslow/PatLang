Feature: sha512 package: SHA-512 (FIPS 180-4) on modint words
  The known-answer vectors are FIPS 180-4's examples. The words are modints
  modulo 2^64 and the bytes modints modulo 256 (spec 1.14), so the check of
  spec 2.7 sees them as secret.

  Scenario: The one-block message "abc"
    Given the text "abc"
    Then its SHA-512 is "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"

  Scenario: The empty message
    Given the empty text
    Then its SHA-512 is "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"

  Scenario: The 896-bit two-block message
    Given the text "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
    Then its SHA-512 is "8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909"

  Scenario: A digest is 64 bytes, each a modint modulo 256
    Given the text "abc"
    Then its digest has 64 bytes, each a modint modulo 256
