Feature: passing contracts become queryable logic facts

  Scenario: A passing require/ensure check is recorded as contract_holds/2
    Given safe_divide(10, 2), which passes both its require and ensure checks
    When solve("contract_holds", ["safe_divide", "X"]) is called afterward
    Then it returns a NON-EMPTY list of solutions -- the passing checks are real, derivable facts in the SAME store rule_add/solve uses, not an invisible side effect

  This is the concrete bridge between PatLang's design-by-contract
  mechanism and its logic/inference engine: a function's contracts,
  once satisfied, are themselves usable as rule-body conjuncts or GOAP
  preconditions by anything reasoning over the fact store.

