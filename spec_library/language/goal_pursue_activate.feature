Feature: goal / pursue / activate / action_bind (declarative GOAP surface syntax)

  Scenario: pursue finds a real multi-step plan for a named goal
    Given `goal need_a_house { built(house) }`, with dep/built facts and 2 registered actions, requiring a genuine chain
    When `pursue need_a_house` is evaluated
    Then it returns a 3-step plan, the same search plan() itself performs

  Scenario: activate runs each bound closure and succeeds only if all do
    Given action_bind bound both actions to closures that both return true
    When `activate PLAN` is evaluated
    Then it returns true

  Scenario: a plan being found does NOT guarantee activating it succeeds
    Given the SAME plan is still findable, but one action is re-bound to a closure that now returns false for this specific case
    When pursue (finds the same plan again) then activate (runs it) are evaluated
    Then activate returns false -- stopping the moment the failing step runs, even though the planner still found a valid dependency chain

