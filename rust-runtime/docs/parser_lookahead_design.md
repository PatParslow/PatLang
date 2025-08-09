# Patlang Parser Lookahead-Based Parsing Design

## Overview

This document outlines the planned changes for implementing robust lookahead-based parsing in Patlang, focusing on newline token handling, statement boundary detection, error recovery, and implications for regression testing and language design.

---

## 1. Lexer Emits All Newline Tokens

**Principle:**  
The lexer will always emit newline tokens (`NEWLINE`) wherever they occur in the source code. The parser, not the lexer, will decide whether to treat these tokens as significant (e.g., statement boundaries) or to ignore them (e.g., within multi-line constructs).

---

## 2. Rationale

- **Multi-line Constructs:**  
  By always emitting newlines, the parser can flexibly support multi-line strings, expressions, and other constructs without ambiguity.
- **Flexible Statement Boundaries:**  
  This approach allows the parser to distinguish between cases where newlines are meaningful (ending a statement) and where they are not (inside parentheses, brackets, or multi-line strings).
- **Simpler Lexer, Smarter Parser:**  
  The lexer remains simple and context-free, while the parser gains the power to interpret structure based on lookahead and context.

---

## 3. Statement Boundary Detection Using Lookahead

- **Lookahead for New Statement Starts:**  
  The parser will use lookahead to determine if a `NEWLINE` token should be treated as a statement boundary.  
  - If the token following a `NEWLINE` can start a new statement, the parser treats the newline as a boundary.
  - If not (e.g., inside a multi-line construct), the parser ignores the newline.
- **Example:**  
  ```
  let x = foo(
      1,
      2
  )
  let y = 3
  ```
  Here, the newlines inside the parentheses are ignored; the newline before `let y` is a statement boundary.

---

## 4. Error Recovery and Multi-line Constructs

- **Error Recovery:**  
  The parser can use newlines as synchronization points for error recovery. If a parsing error occurs, the parser can skip tokens until the next `NEWLINE` that starts a valid statement.
- **Multi-line Constructs:**  
  The parser will maintain context (e.g., inside parentheses, brackets, or strings) to decide when to ignore newlines. This enables robust parsing of multi-line expressions and blocks.

---

## 5. Implications for Regression Testing and Language Design

- **Regression Testing:**  
  - Tests must cover cases with significant and insignificant newlines.
  - Edge cases: multi-line strings, nested constructs, error recovery scenarios.
- **Language Design:**  
  - This approach enables more flexible and expressive syntax.
  - Future language features (e.g., optional semicolons, advanced block structures) are easier to support.

---

## 6. Summary

- Lexer always emits newlines.
- Parser uses lookahead to decide when newlines are significant.
- Enables robust multi-line constructs and error recovery.
- Supports flexible, future-proof language design.
