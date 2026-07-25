Feature: closures (|params| { body } literal, free-variable capture)

  Scenario: A closure captures a free variable from its enclosing scope
    Given `let base = 10` then `let add_to_base = |x| { return base + x }`
    When add_to_base(5) is called
    Then the result is 15

  Scenario: A closure can be called through a variable it's assigned to
    Given `let f = add_to_base`
    When f(5) is called
    Then it behaves identically to calling add_to_base(5) directly

  Scenario: Closures returned from a function each capture their OWN value independently
    Given a function `outer(n)` that creates and returns `|x| { return x + n }`
    When add10 = outer(10) and add20 = outer(20) are both created, then called with 1
    Then add10(1)=11 and add20(1)=21 -- each closure keeps its own captured n from its OWN call to outer, not a shared/overwritten one

