Feature: alternate block delimiters (do/end vs then/end vs { })

  Scenario: while accepts do...end as an alternative to { }
    Given `while i < 2 do ... end`
    When evaluated
    Then it behaves identically to the brace form

  Scenario: closures accept do...end too
    Given `|x| do return x * 2 end`
    When called
    Then it behaves identically to `|x| { return x * 2 }`

  Scenario: if does NOT support do...end -- its alternate form uses 'then', not 'do'
    Given `if true do ... end`
    When parsed
    Then it is a PARSE ERROR ("Start the 'if' block with '{'")
    Given `if true then ... end` instead
    When parsed
    Then it works -- if's Ruby-style alternate form is then/elif/else/end, never do/end

