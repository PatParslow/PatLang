# Lexer Error Handling Specification

## Critical Implementation Rule

**⚠️ CRITICAL: The lexer MUST NEVER raise exceptions for unrecognized input or parsing issues.**

This specification defines the mandatory error handling behavior for the Patlang lexer to prevent incorrect implementations that change the lexer to raise exceptions instead of returning tokens.

## Table of Contents

1. [Core Principle](#core-principle)
2. [Mandatory Behavior](#mandatory-behavior)
3. [Exception Rules](#exception-rules)
4. [Implementation Examples](#implementation-examples)
5. [Testing Requirements](#testing-requirements)
6. [Common Mistakes to Avoid](#common-mistakes-to-avoid)

---

## Core Principle

The Patlang lexer follows a **"Never Fail, Always Token"** principle:

- **Never throw exceptions** for unrecognized characters or invalid syntax
- **Always return a token** (UNKNOWN, AMBIGUOUS, or EOF)
- **Continue processing** after encountering invalid input
- **Only raise exceptions** for genuine system errors (IO failures, memory issues)

This design ensures robust parsing and enables error recovery at the parser level.

---

## Mandatory Behavior

### 1. Unrecognized Characters

When the lexer encounters characters it doesn't recognize:

```ruby
# ✅ CORRECT: Return UNKNOWN token and continue
def error
  start_line, start_column = @line, @column
  char = @current_char
  advance  # Move past the unknown character
  Token.new(Token::TOKEN_TYPES[:UNKNOWN], char, @position - 1, start_line, start_column)
end
```

```ruby
# ❌ WRONG: Never do this
def error
  raise SyntaxError, "Unexpected character: #{@current_char}"
end
```

### 2. Invalid Token Sequences

For invalid but partially recognizable input:

```ruby
# Example: Unterminated string
if @current_char != quote_type
  # ✅ CORRECT: Return special token type
  return Token.new(:UNTERMINATED_STRING, value, start_position, start_line, start_column)
end

# ❌ WRONG: Never do this
if @current_char != quote_type
  raise SyntaxError, "Unterminated string literal"
end
```

### 3. End of File Handling

Always return EOF token when input is exhausted:

```ruby
# ✅ CORRECT: Always return EOF token
def get_next_token
  # ... token processing ...
  Token.new(Token::TOKEN_TYPES[:EOF], nil, @position, @line, @column)
end
```

### 4. Ambiguous Token Resolution

For contextually ambiguous tokens, return AmbiguousToken:

```ruby
# ✅ CORRECT: Let parser resolve ambiguity
if result == 'make'
  possibilities = [
    { type: Token::TOKEN_TYPES[:MAKE], value: result },
    { type: Token::TOKEN_TYPES[:IDENTIFIER], value: result }
  ]
  return AmbiguousToken.new(possibilities, start_position, start_line, start_column)
end
```

---

## Exception Rules

### When Exceptions ARE Allowed

Exceptions should **only** be raised for:

1. **System IO Errors**: File not found, permission denied, disk full
2. **Memory Errors**: Out of memory, stack overflow
3. **Internal Logic Errors**: Programming bugs in the lexer itself
4. **Resource Exhaustion**: System resource limits exceeded

```ruby
# ✅ ACCEPTABLE: System-level errors
begin
  @text = File.read(filename)
rescue IOError => e
  raise LexerIOError, "Cannot read source file: #{e.message}"
end
```

### When Exceptions Are FORBIDDEN

**Never raise exceptions for**:

1. **Unrecognized characters**: `@`, `~`, `$`, etc.
2. **Invalid token sequences**: Unterminated strings, malformed numbers
3. **Syntax errors**: Missing operators, invalid combinations
4. **Encoding issues**: Non-UTF8 characters (handle gracefully)

```ruby
# ❌ FORBIDDEN: Never raise for parsing issues
case @current_char
when '$'
  raise SyntaxError, "Invalid character '$'"  # WRONG!
when '~'
  raise TokenizationError, "Unsupported operator '~'"  # WRONG!
end

# ✅ CORRECT: Return UNKNOWN tokens
case @current_char
when '$', '~'
  return error  # Returns UNKNOWN token
end
```

---

## Implementation Examples

### Example 1: Handling Invalid Characters

```ruby
# Input: "hello $ world"
# Expected tokens: [IDENTIFIER("hello"), UNKNOWN("$"), IDENTIFIER("world"), EOF]

def get_next_token
  # ... existing code ...
  
  else
    if alpha?(@current_char)
      return read_identifier
    else
      # ✅ CORRECT: Handle invalid characters gracefully
      return error
    end
  end
end
```

### Example 2: Malformed Number Literals

```ruby
# Input: "123.45.67"  (invalid: two decimal points)
# Expected: [NUMBER(123.45), UNKNOWN("."), NUMBER(67), EOF]

def read_number
  result = ''
  has_decimal = false
  
  while @current_char && (@current_char.match(/\d/) || (@current_char == '.' && !has_decimal && peek_char&.match(/\d/)))
    if @current_char == '.'
      if has_decimal
        # ✅ CORRECT: Stop at second decimal point, let error handling deal with it
        break
      end
      has_decimal = true
    end
    result += @current_char
    advance
  end
  
  has_decimal ? result.to_f : result.to_i
end
```

### Example 3: Unterminated String Recovery

```ruby
# Input: "hello world
# Expected: [UNTERMINATED_STRING("hello world"), EOF]

def tokenize_string(quote_type = '"')
  # ... process string content ...
  
  if @current_char != quote_type
    # ✅ CORRECT: Return special token instead of raising error
    return Token.new(:UNTERMINATED_STRING, value, start_position, start_line, start_column)
  end
  
  advance  # Skip closing quote
  Token.new(Token::TOKEN_TYPES[:STRING], value, start_position, start_line, start_column)
end
```

### Example 4: Escape Sequence Handling

```ruby
# Input: "hello\x world"  (invalid escape sequence)
# Expected: Process gracefully, don't crash

def tokenize_string(quote_type = '"')
  # ... 
  if @current_char == '\\'
    advance
    if @current_char
      case @current_char
      when 'n', 't', 'r', '\\', '"', "'"
        # Handle known escape sequences
      else
        # ✅ CORRECT: Handle unknown escape sequences gracefully
        value += @current_char  # Include the character literally
      end
      advance
    else
      # ✅ CORRECT: Handle incomplete escape at end of input
      return Token.new(:UNTERMINATED_STRING, value, start_position, start_line, start_column)
    end
  end
end
```

---

## Testing Requirements

### Required Test Cases

Every lexer implementation must pass these tests:

```ruby
# Test 1: Unknown characters
def test_unknown_characters
  tokens = lexer.tokenize("hello $ world")
  assert_equal :IDENTIFIER, tokens[0].type
  assert_equal :UNKNOWN, tokens[1].type
  assert_equal "$", tokens[1].value
  assert_equal :IDENTIFIER, tokens[2].type
end

# Test 2: Unterminated strings
def test_unterminated_string
  tokens = lexer.tokenize('"hello world')
  assert_equal :UNTERMINATED_STRING, tokens[0].type
  assert_equal "hello world", tokens[0].value
end

# Test 3: Invalid escape sequences
def test_invalid_escape_sequence
  tokens = lexer.tokenize('"hello\\x world"')
  assert_equal :STRING, tokens[0].type
  # Should not raise exception
end

# Test 4: Multiple invalid characters
def test_multiple_invalid_characters
  tokens = lexer.tokenize("@ # $ % ^")
  # Should return UNKNOWN tokens, not raise exceptions
  assert tokens.all? { |t| t.type == :UNKNOWN || t.type == :EOF }
end

# Test 5: Mixed valid and invalid
def test_mixed_valid_invalid
  tokens = lexer.tokenize("x = $ + y")
  expected_types = [:IDENTIFIER, :ASSIGN, :UNKNOWN, :PLUS, :IDENTIFIER, :EOF]
  actual_types = tokens.map(&:type)
  assert_equal expected_types, actual_types
end
```

### Performance Tests

```ruby
# Test: Lexer doesn't crash on large invalid input
def test_large_invalid_input
  large_input = "$" * 10000
  tokens = lexer.tokenize(large_input)
  assert_equal 10001, tokens.length  # 10000 UNKNOWN + 1 EOF
  assert tokens[0...-1].all? { |t| t.type == :UNKNOWN }
end
```

---

## Common Mistakes to Avoid

### Mistake 1: Raising Exceptions for Unknown Characters

```ruby
# ❌ WRONG
case @current_char
when '$'
  raise "Invalid character $"
end

# ✅ CORRECT
case @current_char
when '$'
  return error  # Returns UNKNOWN token
end
```

### Mistake 2: Stopping Lexing on Errors

```ruby
# ❌ WRONG: Stops processing
def get_next_token
  if invalid_character?(@current_char)
    raise SyntaxError, "Cannot continue"
  end
end

# ✅ CORRECT: Continues processing
def get_next_token
  if invalid_character?(@current_char)
    token = error  # Create UNKNOWN token
    return token   # Continue with next token
  end
end
```

### Mistake 3: Not Advancing Position on Errors

```ruby
# ❌ WRONG: Creates infinite loop
def error
  Token.new(:UNKNOWN, @current_char, @position, @line, @column)
  # Forgot to advance!
end

# ✅ CORRECT: Always advance
def error
  start_line, start_column = @line, @column
  char = @current_char
  advance  # CRITICAL: Move past the character
  Token.new(:UNKNOWN, char, @position - 1, start_line, start_column)
end
```

### Mistake 4: Inconsistent EOF Handling

```ruby
# ❌ WRONG: Sometimes returns nil
def get_next_token
  return nil if @current_char.nil?  # WRONG!
end

# ✅ CORRECT: Always returns EOF token
def get_next_token
  while @current_char
    # ... token processing ...
  end
  Token.new(Token::TOKEN_TYPES[:EOF], nil, @position, @line, @column)
end
```

---

## Developer Guidelines

### Code Review Checklist

When reviewing lexer changes, verify:

- [ ] No new exception raises for parsing issues
- [ ] All error paths return tokens
- [ ] Position advancement on errors
- [ ] Proper EOF token handling
- [ ] Test coverage for new error cases

### Adding New Token Types

When adding new token types:

1. **Define the token type** in Token::TOKEN_TYPES
2. **Handle recognition** in get_next_token
3. **Handle unrecognized variants** by returning UNKNOWN
4. **Add comprehensive tests** including edge cases
5. **Document the behavior** in this specification

### Maintenance Rules

- **Never change error() method** to raise exceptions
- **Never change EOF handling** to return nil
- **Always test with invalid input** before merging
- **Update this document** when adding new error cases

---

## Conclusion

The lexer's error handling behavior is a critical architectural decision that enables robust parsing and error recovery. Changing the lexer to raise exceptions for unrecognized input breaks this architecture and must be avoided.

**Remember**: The lexer's job is to tokenize input, not to validate syntax. Syntax validation happens at the parser level, which can make informed decisions about how to handle UNKNOWN tokens and recover from errors.

**This specification is mandatory** and must be followed by all contributors to prevent breaking the parsing architecture.