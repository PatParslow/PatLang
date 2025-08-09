# Statement boundaries in the Rust parser

Newlines are treated as whitespace, not as hard statement terminators. Semicolons are optional separators. The parser infers the end of a statement when either:

- An explicit semicolon `;` is present, or
- The next token can start a statement (and there is at least a newline separating them), or
- The current syntactic construct closes (e.g., `)` or `}`), which ends the statement inside.

When putting multiple statements on the same line, add a semicolon between them. Without a semicolon, a newline must separate two statements.

Continuation across lines is allowed when more input is expected:

- After a binary operator (+, -, *, /, %)
- Inside parentheses for grouping or call arguments
- Between tokens inside function parameter lists
- Inside blocks delimited by `{` and `}`

Examples:

- Multiple statements on one line (requires `;`): `let x = 1; let y = 2`
- Statement split across lines:
  ```
  let x =
  1 +
  2
  ```
- Parenthesized grouping across lines:
  ```
  let x = (1
   + 2)
  ```
- Multiline call arguments:
  ```
  print(
    1,
    2,
    3
  )
  ```
- Inside blocks and parameter lists, newlines are ignored as separators; `)` or `}` closes the construct.

Error hints: When a required token is missing, the parser returns `ParserError::ExpectedToken` with a short suggestion, e.g.,
"Add ';' or a newline between statements" or "Close the call with ')'". Line numbers are tracked to aid debugging.
