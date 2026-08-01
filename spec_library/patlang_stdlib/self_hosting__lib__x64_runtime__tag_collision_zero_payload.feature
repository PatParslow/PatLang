Feature: print()/type_of() require nonzero payload before trusting a family tag match (self_hosting/lib/x64_runtime.patlang + codegen_x64.patlang, GitHub #48)

  Scenario: a plain int whose bits exactly match the BigInt tag prints as a plain int
    Given the x64 backend compiles a program that calls print(1 shl 60)
      (1152921504606846976, exactly the bare BigInt family tag with zero payload)
    When the compiled program is run
    Then it prints "1152921504606846976"
    And this exactly matches `pat --ir-run`'s own output for the same program

  Scenario: type_of agrees with print on the same value
    Given the x64 backend compiles a program that calls type_of(1 shl 60)
    When the compiled program is run
    Then it prints "int", not "bigint"

  Scenario: RED before the fix
    Given print()'s family-tag dispatch checked only the family-nibble bits,
      with no check on the payload
    And a genuinely tagged String/BigInt/Rational/Complex/Interval/List value
      always has a nonzero payload (a real heap address from rt_heap_alloc,
      which never returns 0)
    When `print(1 shl 60)` was compiled and run via --x64 before this fix
    Then it segfaulted -- the value was wrongly treated as a real tagged
      BigInt pointer, masked to address 0, and dereferenced
