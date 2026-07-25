Feature: include (preprocessor directive)

  Scenario: include splices a file's functions into scope, transitively
    Given an entry script that includes includer.patlang, which itself includes a SIBLING file helper.patlang by bare filename
    When the entry script calls a function from includer.patlang that itself calls a function from helper.patlang
    Then it works -- confirming both the direct splice and the transitive one resolved correctly

  Note: include paths resolve relative to the INCLUDING file's own
  directory, not the entry script's directory -- helper.patlang's bare-
  filename include only works because it and includer.patlang are
  siblings; the entry script (elsewhere) correctly does NOT need to
  know helper.patlang exists at all.

