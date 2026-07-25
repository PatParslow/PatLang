Feature: nl (self_hosting/lib/html.patlang)

  Scenario: Returns a single newline byte
    Given no arguments
    When nl is called
    Then the result is exactly one byte, chr(10)

  Scenario: Same name, independently declared elsewhere
    Given nl is ALSO separately declared in codegen.patlang, html.patlang, and transpile_ruby.patlang (PatLang has no namespacing)
    When each is verified independently
    Then all three currently return byte-identical results -- confirmed by direct source comparison, not assumed

