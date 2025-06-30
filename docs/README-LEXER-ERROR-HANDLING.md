# ⚠️ CRITICAL: Lexer Error Handling Requirements ⚠️

## **NEVER CHANGE THE LEXER TO RAISE EXCEPTIONS!**

This is a **mandatory** architectural requirement for the Patlang lexer.

### Quick Reference

- **✅ CORRECT**: Return `UNKNOWN`, `AMBIGUOUS`, or `EOF` tokens
- **❌ FORBIDDEN**: Raise exceptions for unrecognized input
- **📖 Full Specification**: [`lexer-error-handling-specification.md`](development/lexer-error-handling-specification.md)

### Why This Matters

Previous developers have incorrectly changed the lexer to raise exceptions instead of returning tokens, breaking the parser's error recovery capabilities. This specification prevents that mistake.

### The Rule

```ruby
# ✅ CORRECT in lexer
def handle_unknown_character
  return Token.new(:UNKNOWN, @current_char, @position, @line, @column)
end

# ❌ WRONG - Never do this in the lexer
def handle_unknown_character
  raise SyntaxError, "Unexpected character: #{@current_char}"
end
```

### Testing Compliance

Run the specification compliance test:

```bash
ruby test/test_lexer_error_handling_specification.rb
```

### See Also

- **[Lexer Error Handling Specification](development/lexer-error-handling-specification.md)** - Complete technical specification
- **[Development Guidelines](development/development-guidelines.md)** - General development practices
- **[Language Reference](language/language-reference.md)** - Language specification

---

**This requirement is non-negotiable and must be followed by all contributors.**