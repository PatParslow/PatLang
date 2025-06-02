# Development Guidelines and Best Practices

## Overview

This document establishes comprehensive development guidelines for maintaining the Patlang codebase. These guidelines ensure code quality, platform compatibility, and consistent development practices across different modes and team members.

## Table of Contents

1. [Code Quality Standards](#code-quality-standards)
2. [Platform-Agnostic Practices](#platform-agnostic-practices)
3. [Ruby-Specific Best Practices](#ruby-specific-best-practices)
4. [File and Module Organization](#file-and-module-organization)
5. [Testing Requirements](#testing-requirements)
6. [Documentation Standards](#documentation-standards)
7. [Error Handling Patterns](#error-handling-patterns)
8. [Performance Guidelines](#performance-guidelines)

---

## Code Quality Standards

### File Size Limits

**Recommended Limits:**
- **Maximum 200 lines per file** (excluding comments and blank lines)
- **Maximum 20 lines per method/function**
- **Maximum 5 parameters per method**

**When to Split Files:**
```ruby
# ❌ BAD: Large monolithic file
# src/parser.rb (500+ lines)
class Parser
  # 50+ methods handling all parsing logic
end

# ✅ GOOD: Modular approach
# src/parser.rb (main entry point)
# src/parser/expression_parser.rb
# src/parser/control_flow_parser.rb  
# src/parser/function_parser.rb
```

### Method Size Guidelines

**Keep Methods Focused:**
```ruby
# ❌ BAD: Large, complex method
def evaluate_expression(node)
  case node.type
  when :binary_operation
    # 30+ lines of complex logic
  when :function_call
    # 25+ lines of function handling
  when :assignment
    # 20+ lines of assignment logic
  end
end

# ✅ GOOD: Focused, single-responsibility methods
def evaluate_expression(node)
  case node.type
  when :binary_operation then evaluate_binary_operation(node)
  when :function_call then evaluate_function_call(node)
  when :assignment then evaluate_assignment(node)
  else raise UnsupportedNodeError, "Unknown node type: #{node.type}"
  end
end

def evaluate_binary_operation(node)
  # 5-10 lines of focused logic
end
```

### Code Complexity Metrics

**Cyclomatic Complexity:**
- **Maximum 10** per method
- **Target 5 or less** for most methods
- Use guard clauses to reduce nesting

```ruby
# ❌ BAD: High complexity
def process_token(token)
  if token
    if token.valid?
      if token.type == :identifier
        if current_scope.has_variable?(token.value)
          # nested logic
        else
          # more nested logic
        end
      end
    end
  end
end

# ✅ GOOD: Low complexity with guard clauses
def process_token(token)
  return unless token&.valid?
  return unless token.type == :identifier
  
  if current_scope.has_variable?(token.value)
    handle_existing_variable(token)
  else
    handle_new_variable(token)
  end
end
```

---

## Platform-Agnostic Practices

### File Operations Priority

**Use Ruby Methods Over Shell Commands:**
```ruby
# ❌ BAD: Platform-specific shell commands
system("mkdir -p #{directory}")
`echo "#{content}" > #{filename}`
File.read(filename).split("\n")

# ✅ GOOD: Ruby file operations
FileUtils.mkdir_p(directory)
File.write(filename, content)
File.readlines(filename, chomp: true)
```

### Path Handling

**Cross-Platform Path Construction:**
```ruby
# ❌ BAD: Platform-specific paths
path = "src/parser/modules.rb"           # Unix-style
path = "src\\parser\\modules.rb"         # Windows-style
path = ENV['HOME'] + "/patlang/src"      # Unix-specific

# ✅ GOOD: Cross-platform paths
path = File.join("src", "parser", "modules.rb")
path = File.expand_path("src", __dir__)
path = Pathname.new(__dir__).join("src", "parser", "modules.rb")
```

### Avoid Platform-Specific Commands

**File Tool Preferences:**
```ruby
# ❌ BAD: Shell-dependent operations
system("cp file1.rb file2.rb")           # Unix
system("copy file1.rb file2.rb")         # Windows
`find . -name "*.rb" | wc -l`

# ✅ GOOD: Ruby alternatives
FileUtils.cp("file1.rb", "file2.rb")
Dir.glob("**/*.rb").count
```

### Environment Variables and Configuration

```ruby
# ✅ GOOD: Cross-platform environment handling
class Configuration
  def self.home_directory
    ENV['HOME'] || ENV['USERPROFILE'] || Dir.home
  end
  
  def self.path_separator
    File::PATH_SEPARATOR
  end
  
  def self.file_separator
    File::SEPARATOR
  end
end
```

---

## Ruby-Specific Best Practices

### Module Organization and Namespacing

**Consistent Namespace Patterns:**
```ruby
# ✅ GOOD: Clear module hierarchy
module Patlang
  module Parser
    module Modules
      class ExpressionParser
        # Implementation
      end
    end
  end
  
  module Evaluator
    module Modules
      class ArithmeticEvaluator
        # Implementation
      end
    end
  end
end
```

### Require Statement Organization

**Structured Require Loading:**
```ruby
# ✅ GOOD: Organized require statements
# Standard library requires first
require 'json'
require 'pathname'
require 'fileutils'

# Third-party gems second
require 'minitest/autorun'

# Project-specific requires last, grouped by functionality
require_relative 'ast_nodes'
require_relative 'token'

# Parser modules
require_relative 'parser/expression_parser'
require_relative 'parser/control_flow_parser'
require_relative 'parser/function_parser'

# Evaluator modules
require_relative 'evaluator/arithmetic_evaluator'
require_relative 'evaluator/function_evaluator'
```

### Error Handling Patterns

**Consistent Error Types:**
```ruby
# ✅ GOOD: Custom error hierarchy
module Patlang
  class Error < StandardError; end
  
  class SyntaxError < Error; end
  class ParseError < Error; end
  class EvaluationError < Error; end
  class TypeMismatchError < Error; end
  
  # Specific error classes
  class UndefinedVariableError < EvaluationError; end
  class FunctionNotFoundError < EvaluationError; end
end

# Usage in methods
def evaluate_variable(name)
  return @variables[name] if @variables.key?(name)
  
  raise UndefinedVariableError, "Variable '#{name}' is not defined"
end
```

### Method Naming and Conventions

**Clear, Descriptive Names:**
```ruby
# ❌ BAD: Unclear naming
def proc(n)
  # What does this do?
end

def handle_stuff(x, y)
  # Too generic
end

# ✅ GOOD: Descriptive naming
def evaluate_binary_expression(node)
  # Clear purpose
end

def validate_function_parameters(expected_params, actual_args)
  # Intent is obvious
end
```

---

## File and Module Organization

### Directory Structure Standards

**Recommended Project Layout:**
```
src/
├── patlang.rb                    # Main entry point
├── ast_nodes.rb                  # Core AST definitions
├── lexer.rb                      # Tokenization
├── parser.rb                     # Main parser
├── evaluator.rb                  # Main evaluator
├── token.rb                      # Token definitions
├── parser/                       # Parser modules
│   ├── expression_parser.rb
│   ├── control_flow_parser.rb
│   ├── function_parser.rb
│   └── token_resolver.rb
├── evaluator/                    # Evaluator modules
│   ├── arithmetic_evaluator.rb
│   ├── function_evaluator.rb
│   ├── string_evaluator.rb
│   └── scope_manager.rb
└── archive/                      # Backup/old versions
    ├── parser_backup.rb
    └── evaluator_old.rb
```

### File Naming Conventions

**Consistent Naming Patterns:**
- Use `snake_case` for all file names
- Module files end with `_module.rb` or live in directories
- Test files mirror source structure: `test/test_[component].rb`
- Archive/backup files include descriptive suffix: `_backup.rb`, `_old.rb`

### Module Loading Patterns

**Explicit Dependencies:**
```ruby
# ✅ GOOD: Clear dependency management
module Patlang
  module Parser
    autoload :ExpressionParser, 'parser/expression_parser'
    autoload :ControlFlowParser, 'parser/control_flow_parser'
    autoload :FunctionParser, 'parser/function_parser'
  end
end

# Or explicit loading with error handling
def require_parser_modules
  %w[
    parser/expression_parser
    parser/control_flow_parser
    parser/function_parser
  ].each do |module_path|
    require_relative module_path
  rescue LoadError => e
    raise LoadError, "Failed to load #{module_path}: #{e.message}"
  end
end
```

---

## Testing Requirements

### Test Coverage Standards

**Minimum Coverage Requirements:**
- **90% line coverage** for all production code
- **100% coverage** for critical path methods
- **Edge case coverage** for all public APIs

### Test Organization

**Test File Structure:**
```ruby
# test/test_[component].rb
require_relative 'test_helper'

class TestComponent < Minitest::Test
  def setup
    # Common setup for all tests
  end
  
  def test_basic_functionality
    # Test the happy path
  end
  
  def test_edge_cases
    # Test boundary conditions
  end
  
  def test_error_conditions
    # Test error handling
  end
  
  def teardown
    # Cleanup if needed
  end
end
```

### Test Naming Conventions

**Descriptive Test Names:**
```ruby
# ✅ GOOD: Clear test intentions
def test_evaluates_simple_arithmetic_expressions
  # Tests basic math: 1 + 2 = 3
end

def test_handles_undefined_variable_access_gracefully
  # Tests error handling for missing variables
end

def test_function_calls_with_correct_parameter_count
  # Tests valid function invocation
end
```

---

## Documentation Standards

### Method Documentation

**Required Documentation Elements:**
```ruby
# ✅ GOOD: Comprehensive method documentation
##
# Evaluates a binary expression node and returns the result.
#
# @param node [ASTNode] The binary expression node to evaluate
# @return [Object] The result of the binary operation
# @raise [TypeMismatchError] When operand types are incompatible
# @raise [UndefinedOperatorError] When operator is not supported
#
# @example
#   node = BinaryOpNode.new(:+, IntegerNode.new(1), IntegerNode.new(2))
#   evaluator.evaluate_binary_expression(node) #=> 3
#
def evaluate_binary_expression(node)
  left = evaluate(node.left)
  right = evaluate(node.right)
  apply_operator(node.operator, left, right)
end
```

### Code Comments

**When to Comment:**
```ruby
# ✅ GOOD: Explain complex logic
def resolve_operator_precedence(tokens)
  # Use Dijkstra's Shunting Yard algorithm for precedence resolution
  # This ensures mathematical operator precedence is correctly handled
  output_queue = []
  operator_stack = []
  
  tokens.each do |token|
    # Process each token according to algorithm rules
    if token.operand?
      output_queue << token
    elsif token.operator?
      # Handle operator precedence and associativity
      while should_pop_operator?(operator_stack.last, token)
        output_queue << operator_stack.pop
      end
      operator_stack << token
    end
  end
  
  output_queue + operator_stack.reverse
end
```

---

## Error Handling Patterns

### Consistent Error Messages

**Error Message Format:**
```ruby
# ✅ GOOD: Informative error messages
class ValidationError < StandardError
  def initialize(component, issue, suggestion = nil)
    message = "#{component}: #{issue}"
    message += ". #{suggestion}" if suggestion
    super(message)
  end
end

# Usage
raise ValidationError.new(
  "Function parameter validation",
  "Expected 2 arguments but received 3",
  "Check function definition for correct parameter count"
)
```

### Error Recovery Strategies

**Graceful Degradation:**
```ruby
def parse_with_recovery(tokens)
  begin
    parse_expression(tokens)
  rescue ParseError => e
    # Log error for debugging
    logger.warn "Parse error: #{e.message}"
    
    # Attempt recovery
    skip_to_statement_boundary(tokens)
    
    # Return error node for partial parsing
    ErrorNode.new(e.message, tokens.current_position)
  end
end
```

---

## Performance Guidelines

### Memory Management

**Avoid Memory Leaks:**
```ruby
# ✅ GOOD: Proper cleanup
class ScopeManager
  def initialize
    @scopes = []
  end
  
  def enter_scope
    @scopes.push({})
  end
  
  def exit_scope
    @scopes.pop  # Clean up scope data
  end
  
  def cleanup
    @scopes.clear  # Explicit cleanup for long-running processes
  end
end
```

### Algorithm Complexity

**Choose Appropriate Data Structures:**
```ruby
# ❌ BAD: Linear search for frequent lookups
@variables = []

def find_variable(name)
  @variables.find { |var| var.name == name }  # O(n)
end

# ✅ GOOD: Hash lookup for frequent access
@variables = {}

def find_variable(name)
  @variables[name]  # O(1)
end
```

### Lazy Loading Patterns

**Load Resources on Demand:**
```ruby
class ModuleLoader
  def initialize
    @loaded_modules = {}
  end
  
  def get_module(name)
    @loaded_modules[name] ||= load_module(name)
  end
  
  private
  
  def load_module(name)
    # Expensive loading operation
    require_relative "modules/#{name}"
    Object.const_get("Patlang::Modules::#{name.camelize}")
  end
end
```

---

## Summary

These development guidelines provide a foundation for maintaining high-quality, consistent code across the Patlang project. Key principles:

1. **Maintainability**: Keep files and methods small and focused
2. **Portability**: Use Ruby methods over platform-specific commands
3. **Consistency**: Follow established patterns and naming conventions
4. **Quality**: Maintain high test coverage and comprehensive documentation
5. **Performance**: Consider memory usage and algorithm complexity

Refer to [`mode-specific-guidelines.md`](mode-specific-guidelines.md) for mode-specific development practices and [`patlang-coding-standards.md`](patlang-coding-standards.md) for project-specific coding standards.