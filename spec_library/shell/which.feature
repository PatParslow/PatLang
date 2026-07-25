Feature: which Command (Git/MSYS, resolves an executable's path via PATH)

  Scenario: Resolve a command that exists on PATH
    Given "findstr" is a real command available on PATH
    When the user runs `which findstr`
    Then it prints a POSIX-style path containing "/findstr" (no ".exe" suffix -- this is Git's MSYS which, not native Windows)

  Scenario: A nonexistent command name
    Given a command name that does not exist anywhere on PATH
    When the user runs `which <bogus-name>`
    Then it prints "no <bogus-name> in (...)" -- this MSYS build's own specific not-found message, which echoes the searched-for name as part of the error text

