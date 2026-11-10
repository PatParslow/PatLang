Feature: using blocks choose the store the logic forms use

  Scenario: Inside a using block the logic forms read and write the block's store
    Given `let kb = logic_store_new()` and `using kb as logic do ... end` holding a rule declaration, rule_add, fact, solve, query and plan
    When the block runs
    Then each of them used kb, and the default store holds none of their facts

  Scenario: An inner using block's store shadows the outer one until it ends
    Given `using outer as logic do` with `using inner as logic do ... end` inside it, each adding a fact
    When solve is called in the inner block and again after it ends
    Then the inner block reads only inner, and after it ends the outer block reads only outer

  Scenario: An explicit store wins over the block's
    Given a using block holding `rule ... in NAME.`, rule_add_to and solve_in
    When those forms run inside the block
    Then each used the store it names, not the block's

  Scenario: A named function called inside a using block uses the default store
    Given a function that calls solve, called from inside `using kb as logic do ... end`
    When the function runs
    Then it reads the default store, since the block's store is not in its own text

  Scenario: A closure made inside a using block keeps its store after the block ends
    Given a closure calling solve, made inside `using kb as logic do ... end`
    When the closure is called after the block ends
    Then it reads kb

  Scenario: rules_clear inside a using block empties the block's store only
    Given facts in the default store and in kb
    When rules_clear() runs inside `using kb as logic do ... end`
    Then kb is empty and the default store keeps its facts
