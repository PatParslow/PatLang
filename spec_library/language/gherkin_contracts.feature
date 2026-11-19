Feature: Gherkin-driven contract clauses for GOAP synthesis (require/ensure steps)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang). The programs drive the Gherkin
  runner's clause checking (lib/gherkin.patlang) directly.

  Scenario: A require/ensure clause checked against a hand-written function's own bound value
    Given the program
      """
      include "{lib}/gherkin.patlang"
      let c = ctx_new()
      ctx_set(c, "x", 5)
      ctx_contract_step(c, "require", "x < 10")
      ctx_contract_step(c, "ensure", "x < 20")
      print(ctx_failed(c))
      """
    When it runs interpreted and compiled
    Then both print
      """
        ok: require x < 10
        ok: ensure x < 20
      0
      """

  Scenario: A require/ensure clause checked against a GOAP-synthesized action's own binding
    Given the program
      """
      include "{lib}/gherkin.patlang"
      let c = ctx_new()
      action_add("scale", [["input", [logic_var("X")]]], [["scaled", [logic_var("X")]]], [], 1)
      rule_add("input", ["5"], [])
      ctx_contract_step(c, "require", "X < 10")
      ctx_contract_step(c, "ensure", "X < 20")
      let labels = plan_labels(plan([["scaled", ["5"]]]))
      print(labels)
      print(goap_verify_contracts(ctx_pending_contracts(c), labels))
      """
    When it runs interpreted and compiled
    Then both print
      """
        (deferred) require X < 10
        (deferred) ensure X < 20
      [scale(X=5)]
        ok: require X < 10 (from scale(X=5))
        ok: ensure X < 20 (from scale(X=5))
      true
      """

  Scenario: A synthesized candidate that violates its contract clause is correctly rejected, not silently accepted
    Given the program
      """
      include "{lib}/gherkin.patlang"
      let c = ctx_new()
      action_add("scale", [["input", [logic_var("X")]]], [["scaled", [logic_var("X")]]], [], 1)
      rule_add("input", ["15"], [])
      ctx_contract_step(c, "require", "X < 10")
      let labels = plan_labels(plan([["scaled", ["15"]]]))
      print(labels)
      print(goap_verify_contracts(ctx_pending_contracts(c), labels))
      """
    When it runs interpreted and compiled
    Then both print
      """
        (deferred) require X < 10
      [scale(X=15)]
        FAIL: require violated by synthesized plan: scale(X=15)
      false
      """

  Scenario: The contract-checking mechanism never becomes a runtime assertion itself
    Given the program
      """
      let src = read_file("self_hosting/lib/gherkin.patlang") + read_file("self_hosting/lib/gherkin_clauses.patlang")
      print(src.length > 0)
      print(str_contains(src, "contract_check("))
      """
    When it runs interpreted and compiled
    Then both print
      """
      true
      false
      """
