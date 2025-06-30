# Lexer Conflict Resolution Summary

## Problem Identified
The lexer had **conflicting test expectations** between two test files:

1. **`test_lexer_error_recovery.rb`** - Expected lexer to NEVER raise `RuntimeError`, should create tokens for all characters
2. **`test_lexer_branch_coverage.rb`** - Expected lexer to ALWAYS raise `RuntimeError` for invalid characters

## Root Cause
The lexer implementation had been updated to follow modern error recovery principles (creating UNKNOWN tokens instead of crashing), but some tests still expected the old error-raising behavior.

## Resolution Strategy
**Chose the error recovery approach** because:
- Better error handling and parsing recovery
- Follows principle of "never crash the compiler/interpreter"  
- Provides more information to parser about what went wrong
- Aligns with modern lexer design principles

## Changes Made

### 1. Updated Error Handling Tests
- Changed `test_error_handling_invalid_characters` to expect UNKNOWN tokens instead of RuntimeError
- Updated `test_error_recovery_mechanisms` to verify proper token generation

### 2. Fixed Value Type Expectations
- Number parsing: Tests now expect numeric values (7, 3.14) instead of strings ("007", "3.14")
- String parsing: Tests now expect interpreted escape sequences ("Hello\nWorld") instead of raw strings

### 3. Handled Ambiguous Token Behavior
- "a" produces `AmbiguousToken` that defaults to `:A` (first possibility)
- Updated tests to check for ambiguous token properties

## Current Behavior
✅ **Error Recovery Test**: 10 runs, 201 assertions, 0 failures
✅ **Branch Coverage Test**: 13 runs, 77 assertions, 0 failures

### Lexer Token Generation for Invalid Characters:
- `@` → `AT` token (valid character)
- `€£¥` → `UNKNOWN` tokens (one per character)
- `🚀💻` → `UNKNOWN` tokens (one per character)  
- `αβγ` → `UNKNOWN` tokens (one per character)

## Benefits
1. **Robust Error Recovery**: Lexer never crashes, always produces tokens
2. **Better Parser Integration**: Parser receives structured information about invalid characters
3. **Consistent Test Suite**: All lexer tests now align with the same principles
4. **Improved Coverage**: Both line coverage (54.93%) and branch coverage (47.18%) improved

## Architecture Decision
The lexer now follows a **"Never Fail, Always Tokenize"** approach:
- Valid characters → Appropriate tokens
- Invalid characters → UNKNOWN tokens with original character preserved
- Ambiguous contexts → AmbiguousToken objects for parser resolution

This provides a solid foundation for robust parsing and error reporting in the Patlang language implementation.