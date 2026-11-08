Feature: resolve package: version order and the rules over it
  Versions are MAJOR.MINOR.PATCH, compared as numbers field by field. The
  resolver compares every pair of the versions and bounds it knows in
  PatLang and asserts version_order facts; satisfies and dep_candidate are
  rules over them.

  Scenario: Versions compare numerically, field by field
    Then version "0.1.0" compares lt to "0.2.0"
    And version "0.2.0" compares gt to "0.1.0"
    And version "0.1.0" compares eq to "0.1.0"
    And version "1.10.0" compares gt to "1.9.0"
    And version "0.1.10" compares gt to "0.1.9"
    And version "2.0.0" compares gt to "1.99.99"
    And version "0.0.1" compares lt to "0.1.0"
    And version "123456789012345678901234567890.0.0" compares gt to "123456789012345678901234567889.9.9"

  Scenario: Texts that are not versions
    Then "1.2" is not a version
    And "1.2.3.4" is not a version
    And "01.2.3" is not a version
    And "1.2.3-beta" is not a version
    And "1..3" is not a version
    And "v1.2.3" is not a version
    And "1.2.3." is not a version
    And "0.0.0" is a version
    And "10.0.200" is a version

  Scenario: Every pair of known versions becomes a version_order fact
    Given the universe "basic"
    When its facts are listed
    Then there are 9 "version_order" facts
    And the facts include "version_order 0.1.5 0.2.0 lt"
    And the facts include "version_order 0.2.0 0.1.5 gt"
    And the facts include "version_order 0.1.0 0.1.0 eq"
    And there are 6 "pkg_available" facts
    And there are 5 "pkg_requires" facts
    And the facts include "pkg_requires zip 0.1.0 deflate lt 0.2.0"
    And the facts include "pkg_requires office 0.1.0 zip ge 0.1.0"

  Scenario: satisfies follows the operators
    Given the universe "basic"
    When its facts are listed
    Then the facts include "satisfies 0.1.5 lt 0.2.0"
    And the facts do not include "satisfies 0.2.0 lt 0.2.0"
    And the facts include "satisfies 0.2.0 le 0.2.0"
    And the facts include "satisfies 0.2.0 ge 0.2.0"
    And the facts do not include "satisfies 0.2.0 gt 0.2.0"
    And the facts include "satisfies 0.1.5 eq 0.1.5"
    And the facts do not include "satisfies 0.1.5 eq 0.1.0"

  Scenario: dep_candidate gives one solution per constraint a version meets
    Given the universe "basic"
    When its facts are listed
    Then the facts include "dep_candidate zip 0.1.0 deflate 0.1.5" 2 times
    And the facts include "dep_candidate zip 0.1.0 deflate 0.1.0" 2 times
    And the facts include "dep_candidate zip 0.1.0 deflate 0.2.0" 1 times
    And the facts include "dep_candidate pdf 0.1.0 deflate 0.2.0" 1 times
    And the facts do not include "dep_candidate pdf 0.1.0 deflate 0.1.5"
