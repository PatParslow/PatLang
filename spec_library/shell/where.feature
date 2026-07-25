Feature: Windows where Command (native, resolves an executable's path via PATH)

  Scenario: Resolve a command that exists on PATH
    Given "findstr" is a real command available on PATH
    When the user runs `where findstr`
    Then it prints a path ending in "findstr.exe"

  Scenario: A nonexistent command name
    Given a command name that does not exist anywhere on PATH
    When the user runs `where <bogus-name>`
    Then it prints an error, and the output contains no ".exe" path

