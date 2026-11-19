Feature: resolve package: choosing one version per package
  From a requested package and constraint, the resolver walks the
  dependencies transitively and chooses one version of each package that
  satisfies every requirer, newer versions first. When no choice works it
  reports the package it could not choose, each requirer with its
  constraints from the facts, and the versions available. Each resolution
  runs in a process of its own, since the rule store has no retraction.

  Scenario: zip takes the newest 0.1.x deflate
    When resolving "zip" from "basic"
    Then the choice is "deflate 0.1.5, zip 0.1.0"

  Scenario: pdf takes deflate 0.2.0
    When resolving "pdf" from "basic"
    Then the choice is "deflate 0.2.0, pdf 0.1.0"

  Scenario: A bare request takes the newest version
    When resolving "deflate" from "basic"
    Then the choice is "deflate 0.2.0"

  Scenario: A requested constraint narrows the choice
    When resolving "deflate" "< 0.2.0" from "basic"
    Then the choice is "deflate 0.1.5"
    When resolving "deflate" "= 0.1.0" from "basic"
    Then the choice is "deflate 0.1.0"
    When resolving "deflate" ">= 0.1.0, <= 0.1.5" from "basic"
    Then the choice is "deflate 0.1.5"
    When resolving "deflate" "> 0.1.0, < 0.2.0" from "basic"
    Then the choice is "deflate 0.1.5"

  Scenario: A request no version meets
    When resolving "deflate" "> 0.2.0" from "basic"
    Then resolution fails on "deflate"
    And the conflict has 1 requirer
    And the conflict lists "requirer the request: > 0.2.0"
    And the conflict lists "available 0.2.0, 0.1.5, 0.1.0"

  Scenario: Two requirers that cannot agree
    When resolving "office" from "basic"
    Then resolution fails on "deflate"
    And the conflict has 2 requirers
    And the conflict lists "requirer zip 0.1.0: >= 0.1.0, < 0.2.0"
    And the conflict lists "requirer pdf 0.1.0: >= 0.2.0"
    And the conflict lists "available 0.2.0, 0.1.5, 0.1.0"

  Scenario: A diamond backs off the newest left to agree on base
    When resolving "app" from "diamond"
    Then the choice is "app 1.0.0, base 1.2.0, left 1.0.0, right 1.0.0"

  Scenario: A diamond's corner on its own takes the newest
    When resolving "left" from "diamond"
    Then the choice is "base 2.0.0, left 2.0.0"

  Scenario: A cycle resolves
    When resolving "a" from "cycle"
    Then the choice is "a 1.0.0, b 1.0.0"

  Scenario: A cycle that cannot close
    When resolving "a" from "cycle_conflict"
    Then resolution fails on "a"
    And the conflict has 2 requirers
    And the conflict lists "requirer the request: >= 0.0.0"
    And the conflict lists "requirer b 1.0.0: >= 2.0.0"
    And the conflict lists "available 1.0.0"

  Scenario: A dependency nobody provides
    When resolving "m" from "missing"
    Then resolution fails on "ghost"
    And the conflict has 1 requirer
    And the conflict lists "requirer m 1.0.0: >= 1.0.0"
    And the conflict lists "available none"

  Scenario: A requested package nobody provides
    When resolving "nothing" from "basic"
    Then resolution fails on "nothing"
    And the conflict lists "requirer the request: >= 0.0.0"
    And the conflict lists "available none"

  Scenario: A malformed request constraint is refused
    When resolving "deflate" "~ 0.1.0" from "basic"
    Then the output is "error request: constraint '~ 0.1.0' has no operator =, >=, >, <= or <"

  Scenario: A malformed manifest in the universe is refused
    When resolving "x" from "malformed"
    Then the output starts with "error packages/resolve/spec/fixtures/malformed/bad_bound.pkg line 5:"

  Scenario: A universe path that does not exist is refused
    When resolving "zip" from "no_such_universe"
    Then the output is "error packages/resolve/spec/fixtures/no_such_universe line 0: no such file or directory"

  Scenario: The real packages resolve
    When resolving "zip" from the real packages
    Then the choice is "deflate 0.2.0, zip 0.2.0"
    When resolving "sha256" from the real packages
    Then the choice is "sha256 0.1.1"
    When resolving "zip" "> 0.2.0" from the real packages
    Then resolution fails on "zip"
    And the conflict lists "available 0.2.0"
