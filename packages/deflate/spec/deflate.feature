Feature: deflate package: DEFLATE (RFC 1951), zlib (RFC 1950), CRC-32 and Adler-32
  Python's zlib is the reference. Data goes both ways: what PatLang writes
  must decompress in Python to the same bytes, and what Python writes must
  decompress in PatLang to the same bytes.

  Scenario: CRC-32 of the standard check string
    Given the text "123456789"
    Then its CRC-32 is 3421780262

  Scenario: Adler-32 of the standard check string
    Given the text "123456789"
    Then its Adler-32 is 152961502

  Scenario: Checksums agree with Python's on random data
    Given test data "random" of 100000 bytes
    Then its CRC-32 is the one Python's zlib gives
    And its Adler-32 is the one Python's zlib gives

  Scenario: Python's stored blocks inflate
    Given test data "text" of 70000 bytes
    When Python compresses it with zlib at level 0
    Then its first block is "stored"
    And PatLang zlib-decompresses it to the same bytes

  Scenario: Python's fixed-Huffman blocks inflate
    Given test data "text" of 50000 bytes
    When Python compresses it with the fixed-Huffman strategy
    Then its first block is "fixed"
    And PatLang zlib-decompresses it to the same bytes

  Scenario: Python's dynamic-Huffman blocks inflate
    Given test data "mixed" of 200000 bytes
    When Python compresses it with zlib at level 9
    Then its first block is "dynamic"
    And PatLang zlib-decompresses it to the same bytes

  Scenario: Python's raw DEFLATE inflates without a zlib wrapper
    Given test data "text" of 30000 bytes
    When Python compresses it as raw DEFLATE at level 6
    Then PatLang raw-inflates it to the same bytes

  Scenario: Python's empty and one-byte streams inflate
    Given test data "one" of 0 bytes
    When Python compresses it with zlib at level 6
    Then PatLang zlib-decompresses it to the same bytes
    Given test data "one" of 1 bytes
    When Python compresses it with zlib at level 6
    Then PatLang zlib-decompresses it to the same bytes

  Scenario: Empty input in every mode
    Given test data "one" of 0 bytes
    Then in every mode PatLang's zlib stream decompresses in Python and in PatLang to the same bytes

  Scenario: One byte in every mode
    Given test data "one" of 1 bytes
    Then in every mode PatLang's zlib stream decompresses in Python and in PatLang to the same bytes

  Scenario: Highly repetitive data in every mode
    Given test data "repetitive" of 100000 bytes
    Then in every mode PatLang's zlib stream decompresses in Python and in PatLang to the same bytes

  Scenario: Random data in every mode
    Given test data "random" of 100000 bytes
    Then in every mode PatLang's zlib stream decompresses in Python and in PatLang to the same bytes

  Scenario: Text in every mode
    Given test data "text" of 100000 bytes
    Then in every mode PatLang's zlib stream decompresses in Python and in PatLang to the same bytes

  Scenario: Each mode writes its own block type
    Given test data "text" of 20000 bytes
    When PatLang compresses it with zlib in "stored" mode
    Then its first block is "stored"
    When PatLang compresses it with zlib in "fixed" mode
    Then its first block is "fixed"
    When PatLang compresses it with zlib in "dynamic" mode
    Then its first block is "dynamic"

  Scenario: LZ77 matching makes repetitive data small
    Given test data "repetitive" of 100000 bytes
    When PatLang compresses it with zlib in "fixed" mode
    Then the compressed size is at most 1 percent of the input
    When PatLang compresses it with zlib in "dynamic" mode
    Then the compressed size is at most 1 percent of the input

  Scenario: Dynamic Huffman beats fixed Huffman on text
    Given test data "text" of 100000 bytes
    Then the "dynamic" stream is smaller than the "fixed" one

  Scenario: PatLang's raw DEFLATE inflates in Python
    Given test data "mixed" of 100000 bytes
    When PatLang compresses it as raw DEFLATE in "dynamic" mode
    Then Python raw-inflates it to the same bytes

  Scenario: Over a megabyte, both ways
    Given test data "mixed" of 1300000 bytes
    When PatLang compresses it with zlib in "dynamic" mode
    Then Python zlib-decompresses it to the same bytes
    And PatLang zlib-decompresses it to the same bytes
    When Python compresses it with zlib at level 6
    Then PatLang zlib-decompresses it to the same bytes

  Scenario: A changed Adler-32 is reported
    Given test data "text" of 5000 bytes
    When Python compresses it with zlib at level 6
    And its last byte is changed
    Then PatLang zlib-decompression fails with "adler32 mismatch"

  Scenario: A truncated stream is reported
    Given test data "text" of 5000 bytes
    When Python compresses it with zlib at level 6
    And it is cut to half its length
    Then PatLang zlib-decompression fails with "truncated"

  Scenario: Block type 3 is reported
    Given the zlib stream bytes 120 156 7 0
    Then PatLang zlib-decompression fails with "bad block type"

  Scenario: A bad zlib header is reported
    Given the zlib stream bytes 120 155 3 0 0 0 0 1
    Then PatLang zlib-decompression fails with "bad zlib header"
