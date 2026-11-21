@language
Feature: a syntax definition extends the language for the program (spec 1.9)

  Scenario: a block in a defined syntax runs as what its rule says
    Given a syntax definition with trigger routes, and a rule giving a call for each line
    And a routes block with two lines
    When the program runs
    Then each line runs as that call, in order, and the statements after the block run

  Scenario: a definition holds in the files that come after it
    Given a file with a syntax definition, and a program that includes it and uses the syntax
    When the program runs
    Then the included file's definition expands the program's block

  Scenario: a definition need not start a line
    Given a syntax definition written on the same line as a statement before it
    And a block in that syntax
    When the program runs
    Then the statement runs, and the block runs as its rule says

  Scenario: a token's name is its own, and Symbol("text") is the step that matches the text
    Given a syntax definition with tokens named Symbol, Symbols and Manyfold, and a rule using them and Symbol("=>")
    When the program runs
    Then each bare name matches its token, and Symbol("=>") matches the arrow

  Scenario: AST.Name(args) gives a node
    Given rules and ordinary code using AST.Name(args), nested, in a closure, and with a variable named AST
    When the program runs
    Then each gives a list of the name and its arguments, a function can take it, and the variable keeps its meaning
