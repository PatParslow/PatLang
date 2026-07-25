Feature: q (self_hosting/lib/html.patlang)

  Scenario: Returns a single double-quote byte
    Given no arguments
    When q is called
    Then the result is exactly one byte, chr(34)

  Scenario: Same name, independently declared elsewhere
    Given q is ALSO separately declared in codegen.patlang and html.patlang (PatLang has no namespacing)
    When each is verified independently
    Then both currently return byte-identical results -- confirmed by direct source comparison, not assumed

