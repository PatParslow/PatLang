Feature: hash_string excluded from numeric-tower dynamic dispatch (self_hosting/lib/x64_runtime.patlang, GitHub #46)

  Scenario: hash_string("hello") matches the interpreter under the x64 backend
    Given the x64 backend compiles a program that calls print(hash_string("hello"))
    When the compiled program is run
    Then it prints "a430d84680aabd0b"
    And this exactly matches `pat --ir-run`'s own output for the same program

  Scenario: RED before the fix
    Given hash_string's own FNV-1a loop produces a huge intermediate value via
      runtime bitwise/arithmetic computation (never a Const literal), starting
      from the FNV offset basis (~1.4e19)
    And this backend's per-function numeric-tower dynamic dispatch only
      recognizes a large value as legitimate if it round-trips as a genuine
      48-bit fixnum or is already explicitly tagged (BigInt/Rational/Complex/
      Interval)
    When x64_util_selftest.patlang (which calls hash_string) was compiled via
      --x64 before this fix
    Then hash_string("hello") crashed with a segmentation fault, confirmed via
      a minimal isolated repro showing the underlying multiply silently
      returning 0 instead of the correct product

  Scenario: hash_string is excluded from dynamic-mode classification by exact name
    Given x64_func_is_tower_impl already excludes every rt_/mem_-prefixed
      function (genuine raw bit manipulation that must never be promoted)
    When hash_string is checked (a name matching neither prefix)
    Then it is ALSO excluded, by exact name, since it performs the same class
      of raw hashing arithmetic that must never enter the numeric tower
