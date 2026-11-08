Feature: sha256 package: SHA-256 (FIPS 180-4) and HMAC-SHA-256 (RFC 2104)
  The known-answer vectors are the FIPS 180-4 examples and RFC 4231's
  HMAC-SHA-256 test cases. Python's hashlib and hmac (spec/oracle.py) are
  the reference for the padding edge cases, random data, files and strings.

  Scenario: The empty message
    Given the text ""
    Then its SHA-256 is "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  Scenario: The one-block message "abc"
    Given the text "abc"
    Then its SHA-256 is "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

  Scenario: The 448-bit message
    Given the text "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
    Then its SHA-256 is "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"

  Scenario: The 896-bit two-block message
    Given the text "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
    Then its SHA-256 is "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1"

  Scenario: One million "a"
    Given 1000000 bytes each 97
    Then its SHA-256 is "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0"

  Scenario: Padding at length 0
    Given test data of 0 bytes
    Then its SHA-256 is the one Python's hashlib gives

  Scenario: Padding at length 1
    Given test data of 1 bytes
    Then its SHA-256 is the one Python's hashlib gives

  Scenario: Padding at length 55, the longest that fits one block
    Given test data of 55 bytes
    Then its SHA-256 is the one Python's hashlib gives

  Scenario: Padding at length 56, the shortest that needs two blocks
    Given test data of 56 bytes
    Then its SHA-256 is the one Python's hashlib gives

  Scenario: Padding at length 63
    Given test data of 63 bytes
    Then its SHA-256 is the one Python's hashlib gives

  Scenario: Padding at length 64, exactly one block
    Given test data of 64 bytes
    Then its SHA-256 is the one Python's hashlib gives

  Scenario: Padding at length 65
    Given test data of 65 bytes
    Then its SHA-256 is the one Python's hashlib gives

  Scenario: Padding at length 119, the longest that fits two blocks
    Given test data of 119 bytes
    Then its SHA-256 is the one Python's hashlib gives

  Scenario: Padding at length 120
    Given test data of 120 bytes
    Then its SHA-256 is the one Python's hashlib gives

  Scenario: Padding at length 127
    Given test data of 127 bytes
    Then its SHA-256 is the one Python's hashlib gives

  Scenario: Padding at length 128, exactly two blocks
    Given test data of 128 bytes
    Then its SHA-256 is the one Python's hashlib gives

  Scenario: Random data across many blocks
    Given test data of 100000 bytes
    Then its SHA-256 is the one Python's hashlib gives

  Scenario: The digest is 32 bytes
    Given the text "abc"
    Then its digest has 32 bytes, each from 0 to 255

  Scenario: Incremental updates of one byte each
    Given test data of 300 bytes
    Then fed in pieces of 1 bytes its SHA-256 is the one-shot digest

  Scenario: Incremental updates that straddle block boundaries
    Given test data of 1000 bytes
    Then fed in pieces of 7 bytes its SHA-256 is the one-shot digest
    And fed in pieces of 63 bytes its SHA-256 is the one-shot digest
    And fed in pieces of 64 bytes its SHA-256 is the one-shot digest
    And fed in pieces of 65 bytes its SHA-256 is the one-shot digest
    And fed in pieces of 200 bytes its SHA-256 is the one-shot digest

  Scenario: Incremental updates split at chosen offsets, with empty updates
    Given test data of 1000 bytes
    Then fed in pieces split at 0 0 1 55 56 64 64 127 128 129 500 999 1000 its SHA-256 is the one-shot digest

  Scenario: A finished hash takes no more updates
    Given the text "abc"
    Then updating a finished hash is refused

  Scenario: Hashing a file of more than 1 MB
    Given test data of 1500000 bytes
    Then its file SHA-256 is the one sha256sum gives
    And its file SHA-256 is the one Python's hashlib gives
    And its file SHA-256 is its one-shot SHA-256

  Scenario: Hashing a file of exactly one read window
    Given test data of 1048576 bytes
    Then its file SHA-256 is the one Python's hashlib gives

  Scenario: Hashing a file that does not exist
    Then the file SHA-256 of "packages/sha256/build/no_such_file.bin" is "missing"

  Scenario: Strings are hashed as UTF-8
    Then the SHA-256 of the string of character codes 97 98 99 is the one Python's hashlib gives
    And the SHA-256 of the string of character codes 233 is the one Python's hashlib gives
    And the SHA-256 of the string of character codes 72 233 2047 2048 8364 65535 is the one Python's hashlib gives
    And the SHA-256 of the string of character codes 65536 128512 1114111 120 is the one Python's hashlib gives

  Scenario: The UTF-8 encoder's byte widths
    Then the string of character codes 127 128 2047 2048 65535 65536 encodes to 1 2 2 3 3 4 bytes

  Scenario: HMAC-SHA-256, RFC 4231 test case 1
    Given the key is 20 bytes each 11
    And the text "Hi There"
    Then its HMAC-SHA-256 is "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"

  Scenario: HMAC-SHA-256, RFC 4231 test case 2, a key shorter than the output
    Given the key is the text "Jefe"
    And the text "what do ya want for nothing?"
    Then its HMAC-SHA-256 is "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"

  Scenario: HMAC-SHA-256, RFC 4231 test case 3
    Given the key is 20 bytes each 170
    And 50 bytes each 221
    Then its HMAC-SHA-256 is "773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe"

  Scenario: HMAC-SHA-256, RFC 4231 test case 4
    Given the key is the hex bytes "0102030405060708090a0b0c0d0e0f10111213141516171819"
    And 50 bytes each 205
    Then its HMAC-SHA-256 is "82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b"

  Scenario: HMAC-SHA-256, RFC 4231 test case 6, a key longer than a block
    Given the key is 131 bytes each 170
    And the text "Test Using Larger Than Block-Size Key - Hash Key First"
    Then its HMAC-SHA-256 is "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"

  Scenario: HMAC-SHA-256, RFC 4231 test case 7, key and data longer than a block
    Given the key is 131 bytes each 170
    And the text "This is a test using a larger than block-size key and a larger than block-size data. The key needs to be hashed before being used by the HMAC algorithm."
    Then its HMAC-SHA-256 is "9b09ffa71b942fcb27635fbcd5b0e944bfdc63644f0713938a7f51535c3a35e2"

  Scenario: HMAC-SHA-256 with a 64-byte key, exactly one block
    Given the key is the hex bytes "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f"
    And test data of 1000 bytes
    Then its HMAC-SHA-256 is the one Python's hmac gives

  Scenario: Hex output is lowercase and two digits a byte
    Given the hex bytes "00010f10fffe"
    Then its lowercase hex is "00010f10fffe"
