Feature: resolve package: generated universes against the Python oracle
  spec/oracle.py generates universes of packages p0..p<N-1>, each version
  depending on the one before and up to two more. By default every
  constraint admits a witness version of its package, so the universe
  resolves; "tight" universes have no witness and mostly conflict. The
  oracle resolves without logic programming, from the same description,
  and checks a choice against the manifests on its own.

  Scenario: A generated universe of 30 packages resolves as the oracle's
    Given a generated universe of 30 packages from seed 1
    When resolving "p29" from the generated universe
    Then the output is the one the oracle gives
    And the oracle finds the choice consistent

  Scenario: A second generated universe of 30 packages
    Given a generated universe of 30 packages from seed 2
    When resolving "p29" from the generated universe
    Then the output is the one the oracle gives
    And the oracle finds the choice consistent

  Scenario: A generated universe of 60 packages
    Given a generated universe of 60 packages from seed 3
    When resolving "p59" from the generated universe
    Then the output is the one the oracle gives
    And the oracle finds the choice consistent

  Scenario: A package in the middle of a generated universe
    Given a generated universe of 30 packages from seed 4
    When resolving "p17" from the generated universe
    Then the output is the one the oracle gives
    And the oracle finds the choice consistent

  Scenario: Tight generated universes report the oracle's conflict
    Given a tight generated universe of 30 packages from seed 1
    When resolving "p29" from the generated universe
    Then the output is the one the oracle gives
    Given a tight generated universe of 30 packages from seed 2
    When resolving "p29" from the generated universe
    Then the output is the one the oracle gives
    Given a tight generated universe of 30 packages from seed 3
    When resolving "p29" from the generated universe
    Then the output is the one the oracle gives

  Scenario: Every version_order fact of a generated universe is right
    Given a generated universe of 30 packages from seed 1
    When the generated universe's facts are listed
    Then the oracle finds every version_order fact right
