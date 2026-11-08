Feature: zip package: reading and writing zip archives
  Python's zipfile is the reference. A zip PatLang writes must open in
  Python with every CRC correct and give back the same names, methods and
  bytes; a zip Python writes must read in PatLang the same way. Names may
  use \uXXXX escapes here; they are written as UTF-8.

  Scenario: PatLang writes a zip Python reads
    Given a zip entry "hello.txt" of test data "text" of 5000 bytes, stored
    And a zip entry "data/random.bin" of test data "random" of 100000 bytes, deflated
    And a zip entry "empty.txt" of test data "one" of 0 bytes, deflated
    And a zip entry "one.bin" of test data "one" of 1 bytes, deflated
    And a zip entry "same.txt" of test data "repetitive" of 200000 bytes, deflated
    And a zip directory entry "data/"
    When PatLang writes the zip
    Then Python's zipfile finds every CRC correct
    And Python's zipfile gives back every entry's name, method and bytes

  Scenario: PatLang reads back the zip it wrote
    Given a zip entry "a.txt" of test data "text" of 3000 bytes, deflated
    And a zip entry "b.bin" of test data "random" of 3000 bytes, stored
    When PatLang writes the zip
    And PatLang reads it
    Then PatLang gives back every entry's name, method and bytes

  Scenario: PatLang reads a zip Python wrote
    Given Python writes a zip of "hello.txt=text:5000:stored,data/random.bin=random:100000:deflated,empty.txt=one:0:deflated,one.bin=one:1:deflated,same.txt=repetitive:200000:deflated,data/=dir"
    When PatLang reads it
    Then PatLang reads the entries Python's zipfile reads, with the same names, methods and bytes

  Scenario: An empty zip, both ways
    When PatLang writes the zip
    Then Python's zipfile finds every CRC correct
    And Python's zipfile gives back every entry's name, method and bytes
    Given Python writes a zip of ""
    When PatLang reads it
    Then PatLang reads 0 entries

  Scenario: UTF-8 names, both ways
    Given a zip entry "caf\u00e9/na\u00efve \u4e2d.txt" of test data "text" of 100 bytes, deflated
    When PatLang writes the zip
    Then Python's zipfile gives back every entry's name, method and bytes
    And Python's zipfile names the first entry with the UTF-8 bytes 636166c3a92f6e61c3af766520e4b8ad2e747874
    Given Python writes a zip of "caf\u00e9/\u00fcber.txt=text:100:deflated"
    When PatLang reads it
    Then PatLang reads the entries Python's zipfile reads, with the same names, methods and bytes
    And PatLang's first entry name has 13 characters, its sixth U+00fc

  Scenario: An archive comment and an entry's extra field are skipped over
    Given Python writes a zip of "x.txt=extra:2000:deflated,y.txt=text:10:stored" with the comment "made by Python"
    When PatLang reads it
    Then PatLang reads the entries Python's zipfile reads, with the same names, methods and bytes

  Scenario: Over a megabyte, both ways
    Given a zip entry "big/mixed.bin" of test data "mixed" of 1300000 bytes, deflated
    And a zip entry "big/same.bin" of test data "repetitive" of 1200000 bytes, deflated
    When PatLang writes the zip
    Then Python's zipfile finds every CRC correct
    And Python's zipfile gives back every entry's name, method and bytes
    Given Python writes a zip of "m.bin=mixed:1300000:deflated,r.bin=random:1100000:stored"
    When PatLang reads it
    Then PatLang reads the entries Python's zipfile reads, with the same names, methods and bytes

  Scenario: A changed byte in an entry's data is reported
    Given Python writes a zip of "a.txt=text:4000:stored,b.txt=text:4000:deflated"
    And the first data byte of entry "a.txt" is changed
    When PatLang reads it
    Then PatLang's read fails with "crc mismatch"

  Scenario: A truncated archive is reported
    Given Python writes a zip of "a.txt=text:4000:deflated"
    And it is cut to half its length
    When PatLang reads it
    Then PatLang's read fails with "no end of central directory"

  Scenario: Bytes that are not a zip are reported
    Given the archive bytes 80 75 1 2 3 4 5
    When PatLang reads it
    Then PatLang's read fails with "no end of central directory"
