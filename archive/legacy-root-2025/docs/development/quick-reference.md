# Development Quick Reference Guide

## Overview

This quick reference provides essential information for common development tasks in the Patlang project. Use this guide for quick lookups during development, troubleshooting, and feature implementation.

## Table of Contents

1. [Common Tasks Quick Guide](#common-tasks-quick-guide)
2. [Adding New Language Features](#adding-new-language-features)
3. [Testing and Verification](#testing-and-verification)
4. [Troubleshooting Guide](#troubleshooting-guide)
5. [File Locations Reference](#file-locations-reference)
6. [Command Cheat Sheet](#command-cheat-sheet)
7. [Error Patterns and Solutions](#error-patterns-and-solutions)

---

## Common Tasks Quick Guide

### Add a New Test Case

**Quick Steps:**
1. Identify the appropriate test file
2. Add test method following naming convention
3. Run test to verify it fails
4. Implement functionality
5. Verify test passes

```ruby
# Example: Adding a test for string concatenation
def test_string_concatenation
  code = '"hello" + " world"'
  result = @evaluator.evaluate(parse_expression(code))
  assert_equal "hello world", result
end
```

### Run Assessment Suite

**Command:**
```bash
ruby assessment_test.rb
```

**What it tests:**
- Basic arithmetic operations
- String operations  
- Function definitions and calls
- Control flow structures
- Error handling

### Verify Functionality After Changes

**Quick Verification Steps:**
```bash
# 1. Run specific component tests
ruby test/test_lexer.rb
ruby test/test_parser.rb  
ruby test/test_evaluator.rb

# 2. Run integration tests
ruby test/test_integration.rb

# 3. Run assessment
ruby assessment_test.rb

# 4. Test specific examples
ruby -I src -r patlang -e 'puts Patlang.evaluate("1 + 2 * 3")'
```

### Create Proper Documentation

**Steps:**
1. Update relevant documentation files
2. Add code examples
3. Update table of contents
4. Cross-reference related documents

**Documentation locations:**
- Core concepts: [`docs/language/`](../language/)
- Development guides: [`docs/development/`](.)
- Examples: [`docs/examples/`](../examples/)

---

## Adding New Language Features

### Complete Feature Implementation Checklist

**1. Design Phase:**
- [ ] Define syntax and semantics
- [ ] Identify required tokens
- [ ] Design AST node structure
- [ ] Plan parser integration
- [ ] Plan evaluator integration

**2. Implementation Phase:**
- [ ] Add token types (if needed)
- [ ] Create AST node classes
- [ ] Implement parser module
- [ ] Implement evaluator module
- [ ] Integrate with main components

**3. Testing Phase:**
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Add to assessment suite
- [ ] Test error cases
- [ ] Verify backward compatibility

**4. Documentation Phase:**
- [ ] Update language reference
- [ ] Add examples
- [ ] Update developer documentation
- [ ] Update quick reference

### Step-by-Step Implementation

**Step 1: Add Token Types**
```ruby
# In patlang-core/lexer/token.rb
module TokenTypes
  # ... existing types ...
  NEW_KEYWORD = :NEW_KEYWORD
end

# In patlang-core/lexer/lexer.rb  
KEYWORDS = {
  # ... existing keywords ...
  'new_keyword' => TokenTypes::NEW_KEYWORD
}.merge(KEYWORDS)
```

**Step 2: Create AST Node**
```ruby
# In patlang-core/ast/ast_nodes.rb
class NewFeatureNode < ASTNode
  attr_reader :feature_data
  
  def initialize(feature_data, **kwargs)
    super(:new_feature, **kwargs)
    @feature_data = feature_data
  end
end
```

**Step 3: Add Parser Module**
```ruby
# In patlang-core/parser/new_feature_parser.rb
module Patlang
  module ParserModules
    class NewFeatureParser
      def initialize(tokens)
        @tokens = tokens
        @current = 0
      end
      
      def parse_new_feature
        # Implementation
      end
    end
  end
end
```

**Step 4: Add Evaluator Module**
```ruby
# In patlang-core/evaluator/new_feature_evaluator.rb
module Patlang
  module EvaluatorModules
    class NewFeatureEvaluator
      def self.evaluate(node, context)
        # Implementation
      end
    end
  end
end
```

**Step 5: Integrate**
```ruby
# In patlang-core/parser/parser.rb
def parse_statement
  case peek.type
  when TokenTypes::NEW_KEYWORD
    @new_feature_parser.parse_new_feature
  # ... existing cases ...
  end
end

# In patlang-core/evaluator/evaluator.rb
def evaluate(node)
  case node.type
  when :new_feature
    EvaluatorModules::NewFeatureEvaluator.evaluate(node, self)
  # ... existing cases ...
  end
end
```

---

## Testing and Verification

### Test File Organization

**Test Structure:**
```
test/
├── test_helper.rb           # Common test setup
├── test_lexer.rb           # Lexer unit tests
├── test_parser.rb          # Parser unit tests  
├── test_evaluator.rb       # Evaluator unit tests
├── test_integration.rb     # Integration tests
├── test_[feature].rb       # Feature-specific tests
└── run_all_tests.rb        # Test runner
```

### Running Different Test Categories

**Unit Tests:**
```bash
# Individual components
ruby test/test_lexer.rb
ruby test/test_parser.rb
ruby test/test_evaluator.rb

# All unit tests
ruby test/run_all_tests.rb
```

**Integration Tests:**
```bash
# Parser-evaluator integration
ruby test/test_integration.rb

# Specific feature integration
ruby test/test_function_integration.rb
```

**Assessment Tests:**
```bash
# Complete functionality assessment
ruby assessment_test.rb

# Specific assessment categories
ruby test/test_regression_core.rb
```

### Test Naming Conventions

**Method Naming:**
```ruby
# Pattern: test_[component]_[functionality]_[scenario]
def test_lexer_tokenizes_integers_correctly
def test_parser_handles_nested_expressions
def test_evaluator_executes_function_calls
def test_integration_arithmetic_with_functions
```

### Verification Commands

**Quick Functionality Check:**
```bash
# Test basic operations
ruby -I src -r patlang -e 'puts Patlang.evaluate("2 + 3")'

# Test string operations  
ruby -I src -r patlang -e 'puts Patlang.evaluate("\"hello\" + \" world\"")'

# Test function calls
ruby -I src -r patlang -e '
  code = "function add(a, b) a + b end; add(3, 4)"
  puts Patlang.evaluate(code)
'
```

---

## Troubleshooting Guide

### Common Error Patterns and Solutions

**Lexer Errors:**

❌ **Problem:** Unexpected character errors
```
LexError: Unexpected character: @ at line 1, column 5
```
✅ **Solution:** Add character handling in [`lexer.rb`](../patlang-core/lexer/lexer.rb) `scan_token` method

❌ **Problem:** Unterminated string errors
```
LexError: Unterminated string at line 2
```
✅ **Solution:** Check string literal parsing logic, ensure proper quote handling

**Parser Errors:**

❌ **Problem:** Unexpected token errors
```
ParseError: Expected ')' after function arguments. Found IDENTIFIER
```
✅ **Solution:** Check token consumption order in parser methods, verify `match()` calls

❌ **Problem:** Precedence issues
```
# Input: 1 + 2 * 3
# Expected: 7, Got: 9
```
✅ **Solution:** Review operator precedence in [`expression_parser.rb`](../patlang-core/parser/expression_parser.rb)

**Evaluator Errors:**

❌ **Problem:** Undefined variable errors
```
UndefinedVariableError: Variable 'x' is not defined
```
✅ **Solution:** Check scope management, ensure variables are defined before use

❌ **Problem:** Type mismatch errors
```
TypeError: Operator + requires numeric operands
```
✅ **Solution:** Add type checking and conversion logic in evaluator modules

### Performance Issues

**Slow Parsing:**
- Check for unnecessary backtracking in parser
- Profile with `ruby -r profile script.rb`
- Use more efficient data structures for token storage

**Memory Usage:**
- Check for memory leaks in scope management
- Profile with `ruby -r objspace script.rb`
- Ensure proper cleanup in long-running processes

**Large File Processing:**
- Use streaming for large files
- Implement incremental parsing if needed
- Add progress reporting for long operations

### Platform Compatibility Issues

**Windows-Specific Issues:**
- Path separator problems: Use [`File.join()`](https://ruby-doc.org/core/File.html#method-c-join)
- Line ending issues: Handle both `\n` and `\r\n`
- Case sensitivity: Use consistent casing

**Cross-Platform File Operations:**
- Use [`FileUtils`](https://ruby-doc.org/stdlib/libdoc/fileutils/rdoc/FileUtils.html) instead of shell commands
- Avoid platform-specific paths
- Test on multiple platforms if possible

---

## File Locations Reference

### Core Implementation Files

**Main Components:**
```
src/
├── patlang.rb              # Main entry point
├── lexer.rb                # Tokenization logic
├── parser.rb               # Main parser coordination  
├── evaluator.rb            # Main evaluator coordination
├── ast_nodes.rb            # AST node definitions
└── token.rb                # Token class and types
```

**Parser Modules:**
```
patlang-core/parser/
├── expression_parser.rb    # Expression parsing
├── control_flow_parser.rb  # If, while, etc.
├── function_parser.rb      # Function definitions
└── token_resolver.rb       # Ambiguous token resolution
```

**Evaluator Modules:**
```
patlang-core/evaluator/
├── arithmetic_evaluator.rb # Math operations
├── function_evaluator.rb   # Function calls
├── string_evaluator.rb     # String operations
└── scope_manager.rb        # Variable scope
```

### Test Files

**Main Test Files:**
```
test/
├── test_helper.rb          # Test utilities
├── test_lexer.rb          # Lexer tests
├── test_parser.rb         # Parser tests
├── test_evaluator.rb      # Evaluator tests
├── test_integration.rb    # Integration tests
└── run_all_tests.rb       # Test runner
```

**Assessment Files:**
```
assessment_test.rb          # Main assessment
test/test_regression_core.rb # Regression tests
```

### Documentation Files

**Development Docs:**
```
docs/development/
├── development-guidelines.md    # General coding standards
├── mode-specific-guidelines.md  # Tool and mode practices
├── patlang-coding-standards.md  # Project-specific standards
├── quick-reference.md          # This file
└── developer-guide.md          # Comprehensive guide
```

**Language Docs:**
```
docs/language/
├── language-reference.md       # Complete language spec
├── syntax.md                  # Syntax rules
└── language-elements-as-objects.md # Core concepts
```

### Configuration Files

**Project Config:**
```
.gitignore                 # Git ignore rules
Gemfile                    # Ruby dependencies
README.md                  # Project overview
```

**Example Files:**
```
examples/
├── function_demo.pat      # Function examples
├── string_demo.pat        # String examples
└── control_flow_demo.pat  # Control flow examples
```

---

## Command Cheat Sheet

### Development Commands

**File Operations:**
```bash
# Create new file
touch src/new_module.rb

# Copy file  
cp src/old_file.rb src/new_file.rb

# Remove file
rm src/temporary_file.rb

# Create directory
mkdir -p src/new_directory
```

**Ruby-Specific:**
```bash
# Check syntax
ruby -c patlang-core/parser/parser.rb

# Run with debugging
ruby -d ruby-host/bootstrap/patlang_bootstrap.rb

# Load and test interactively
ruby -I src -r patlang
```

### Testing Commands

**Run All Tests:**
```bash
ruby test/run_all_tests.rb
```

**Run Specific Tests:**
```bash
ruby test/test_lexer.rb
ruby test/test_parser.rb
ruby test/test_evaluator.rb
ruby test/test_integration.rb
```

**Run Assessment:**
```bash
ruby assessment_test.rb
```

### Development Workflow

**Create Feature Branch:**
```bash
git checkout -b feature/new-feature-name
```

**Commit Changes:**
```bash
git add src/new_file.rb
git commit -m "feat: add new feature implementation"
```

**Run Verification:**
```bash
ruby test/run_all_tests.rb && ruby assessment_test.rb
```

### Interactive Testing

**Quick REPL:**
```bash
# Start Ruby with Patlang loaded
ruby -I src -r patlang

# Then in Ruby:
> Patlang.evaluate("1 + 2")
=> 3
```

**Test Specific Components:**
```bash
# Test lexer
ruby -I src -r lexer -e 'p Lexer.new("1 + 2").tokenize'

# Test parser  
ruby -I src -r parser -e '
  tokens = Lexer.new("1 + 2").tokenize
  p Parser.new(tokens).parse
'
```

---

## Error Patterns and Solutions

### Common Development Errors

**LoadError: cannot load such file**
```bash
# Problem: Incorrect require path
# Solution: Check require_relative paths, ensure file exists
ruby -I src script.rb  # Add src to load path
```

**NameError: uninitialized constant**
```ruby
# Problem: Class/module not loaded
# Solution: Add proper require statement
require_relative 'ast_nodes'
```

**NoMethodError: undefined method**
```ruby
# Problem: Method not defined or misspelled
# Solution: Check method name, ensure proper inheritance
```

### Parser-Specific Errors

**Infinite Recursion:**
```ruby
# Problem: Left-recursive grammar
def parse_expression
  parse_expression  # ❌ Infinite recursion
end

# Solution: Use iterative approach
def parse_expression
  expr = parse_primary
  while match(:PLUS)
    # Iterative parsing
  end
  expr
end
```

**Token Consumption Issues:**
```ruby
# Problem: Not advancing tokens
def parse_number
  if check(:INTEGER)
    # ❌ Missing advance()
    return current_token.value
  end
end

# Solution: Always advance after checking
def parse_number
  if check(:INTEGER)
    token = advance()  # ✅ Advance token
    return token.value
  end
end
```

### Testing Errors

**Test Setup Issues:**
```ruby
# Problem: Tests interfering with each other
# Solution: Proper setup/teardown
def setup
  @lexer = Lexer.new("")
  @parser = Parser.new([])
  @evaluator = Evaluator.new
end
```

**Assertion Failures:**
```ruby
# Problem: Unclear test failures
assert result == expected  # ❌ No error message

# Solution: Descriptive assertions
assert_equal expected, result, "Failed for input: #{input}"
```

---

## Quick Development Recipes

### Add New Operator

1. **Add token type:** Update [`TokenTypes`](../patlang-core/lexer/token.rb)
2. **Add lexer support:** Update [`Lexer`](../patlang-core/lexer/lexer.rb) `scan_token`
3. **Add AST support:** Update [`BinaryOpNode`](../patlang-core/ast/ast_nodes.rb) or create new node
4. **Add parser support:** Update [`ExpressionParser`](../patlang-core/parser/expression_parser.rb)
5. **Add evaluator support:** Update [`ArithmeticEvaluator`](../patlang-core/evaluator/arithmetic_evaluator.rb)
6. **Add tests:** Create test cases for new operator

### Add New Statement Type

1. **Add keyword token:** Update [`TokenTypes`](../patlang-core/lexer/token.rb) and [`KEYWORDS`](../patlang-core/lexer/lexer.rb)
2. **Create AST node:** Add new statement node in [`ast_nodes.rb`](../patlang-core/ast/ast_nodes.rb)
3. **Create parser module:** Add parser in [`parser/`](../patlang-core/parser/) directory
4. **Create evaluator module:** Add evaluator in [`evaluator/`](../patlang-core/evaluator/) directory
5. **Integrate:** Update main [`parser.rb`](../patlang-core/parser/parser.rb) and [`evaluator.rb`](../patlang-core/evaluator/evaluator.rb)
6. **Test:** Add comprehensive test coverage

### Debug Parser Issues

1. **Add debug output:**
```ruby
def parse_expression
  puts "Parsing expression, current token: #{peek}"
  # ... parsing logic
end
```

2. **Use minimal test case:**
```ruby
def test_debug_issue
  code = "1 + 2"  # Simplest failing case
  tokens = Lexer.new(code).tokenize
  puts "Tokens: #{tokens.map(&:type)}"
  ast = Parser.new(tokens).parse
  puts "AST: #{ast.inspect}"
end
```

3. **Step through execution:**
```ruby
require 'pry'
def problematic_method
  binding.pry  # Debugger breakpoint
  # ... method logic
end
```

---

## Summary

This quick reference provides essential commands, patterns, and solutions for Patlang development:

### Key Workflows:
1. **Feature Development**: Design → Implement → Test → Document
2. **Testing**: Unit → Integration → Assessment → Manual verification
3. **Debugging**: Minimal cases → Debug output → Step-through → Fix

### Essential Files:
- Core: [`patlang.rb`](../ruby-host/bootstrap/patlang_bootstrap.rb), [`lexer.rb`](../patlang-core/lexer/lexer.rb), [`parser.rb`](../patlang-core/parser/parser.rb), [`evaluator.rb`](../patlang-core/evaluator/evaluator.rb)
- Tests: [`run_all_tests.rb`](../test/run_all_tests.rb), [`assessment_test.rb`](../../assessment_test.rb)
- Docs: [`development-guidelines.md`](development-guidelines.md), [`patlang-coding-standards.md`](patlang-coding-standards.md)

### Quick Commands:
- Test: `ruby test/run_all_tests.rb`
- Assess: `ruby assessment_test.rb`
- Interactive: `ruby -I src -r patlang`
- Debug: Add `puts` statements or `require 'pry'; binding.pry`

For comprehensive information, refer to the full development guides:
- [`development-guidelines.md`](development-guidelines.md) - General coding standards
- [`mode-specific-guidelines.md`](mode-specific-guidelines.md) - Tool and workflow practices  
- [`patlang-coding-standards.md`](patlang-coding-standards.md) - Project-specific patterns
- [`developer-guide.md`](developer-guide.md) - Complete development guide