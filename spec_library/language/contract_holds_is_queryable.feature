Feature: passing contracts become queryable logic facts

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: A passing require/ensure check is recorded as contract_holds/2
    Given the program
      """
      make a function called safe_divide takes a, b returns r
        require b != 0
        let r = a / b
        ensure (r * b) == a
        return r
      end
      print(safe_divide(10, 2))
      print(list_len(solve("contract_holds", ["safe_divide", logic_var("X")])) > 0)
      """
    When it runs interpreted and compiled
    Then both print
      """
      5
      true
      """

  This is the concrete bridge between PatLang's design-by-contract
  mechanism and its logic/inference engine: a function's contracts,
  once satisfied, are themselves usable as rule-body conjuncts or GOAP
  preconditions by anything reasoning over the fact store.
