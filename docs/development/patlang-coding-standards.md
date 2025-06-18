# Patlang Coding Standards

## Overview

This document establishes coding standards specific to the Patlang interpreter implementation. These standards ensure consistency in how we structure parser modules, AST nodes, evaluator components, and maintain the overall architecture of the language interpreter.

## Table of Contents

1. [Patlang-Specific Patterns](#patlang-specific-patterns)
2. [AST Node Standards](#ast-node-standards)
3. [Parser Module Organization](#parser-module-organization)
4. [Evaluator Module Organization](#evaluator-module-organization)
5. [Token and Lexer Patterns](#token-and-lexer-patterns)
6. [Error Message Standards](#error-message-standards)
7. [Architecture Guidelines](#architecture-guidelines)
8. [Integration Testing Patterns](#integration-testing-patterns)

---

## Patlang-Specific Patterns

### Module Namespace Structure

**Follow Consistent Namespacing:**
```ruby
# ✅ GOOD: Clear module hierarchy
module Patlang
  # Core components
  class Lexer; end
  class Parser; end
  class Evaluator; end
  
  # Specialized modules
  module ParserModules
    class ExpressionParser; end
    class ControlFlowParser; end
    class FunctionParser; end
  end
  
  module EvaluatorModules
    class ArithmeticEvaluator; end
    class FunctionEvaluator; end
    class StringEvaluator; end
  end
end
```

### Require Statement Organization

**Structured Loading for Patlang Components:**
```ruby
# ✅ GOOD: Organized requires for Patlang
# Core components first
require_relative 'ast_nodes'
require_relative 'token'
require_relative 'lexer'
require_relative 'parser'
require_relative 'evaluator'

# Parser modules (alphabetical order)
require_relative 'parser/control_flow_parser'
require_relative 'parser/expression_parser'
require_relative 'parser/function_parser'
require_relative 'parser/token_resolver'

# Evaluator modules (alphabetical order)
require_relative 'evaluator/arithmetic_evaluator'
require_relative 'evaluator/function_evaluator'
require_relative 'evaluator/scope_manager'
require_relative 'evaluator/string_evaluator'
```

### File Organization Standards

**Patlang Project Structure:**
```
src/
├── patlang.rb              # Main entry point
├── ast_nodes.rb            # All AST node definitions
├── token.rb                # Token class and types
├── lexer.rb                # Tokenization logic
├── parser.rb               # Main parser coordination
├── evaluator.rb            # Main evaluator coordination
├── parser/                 # Parser modules
│   ├── expression_parser.rb
│   ├── control_flow_parser.rb
│   ├── function_parser.rb
│   └── token_resolver.rb
├── evaluator/              # Evaluator modules
│   ├── arithmetic_evaluator.rb
│   ├── function_evaluator.rb
│   ├── string_evaluator.rb
│   └── scope_manager.rb
└── archive/                # Backup versions
    ├── parser_backup.rb
    └── evaluator_old.rb
```

---

## AST Node Standards

### AST Node Creation Patterns

**Consistent Node Inheritance:**
```ruby
# ✅ GOOD: Standard AST node pattern
class ASTNode
  attr_reader :type, :line, :column
  
  def initialize(type, line: nil, column: nil)
    @type = type
    @line = line
    @column = column
  end
  
  def accept(visitor)
    visitor.visit(self)
  end
end

# Specific node types
class LiteralNode < ASTNode
  attr_reader :value
  
  def initialize(value, **kwargs)
    super(:literal, **kwargs)
    @value = value
  end
end

class BinaryOpNode < ASTNode
  attr_reader :left, :operator, :right
  
  def initialize(left, operator, right, **kwargs)
    super(:binary_op, **kwargs)
    @left = left
    @operator = operator
    @right = right
  end
end
```

### Node Type Conventions

**Standardized Node Types:**
```ruby
# ✅ GOOD: Consistent node type naming
NODE_TYPES = {
  # Literals
  :integer_literal => IntegerLiteralNode,
  :float_literal => FloatLiteralNode,
  :string_literal => StringLiteralNode,
  :boolean_literal => BooleanLiteralNode,
  
  # Expressions
  :binary_expression => BinaryExpressionNode,
  :unary_expression => UnaryExpressionNode,
  :function_call => FunctionCallNode,
  :variable_access => VariableAccessNode,
  
  # Statements
  :assignment => AssignmentNode,
  :if_statement => IfStatementNode,
  :while_loop => WhileLoopNode,
  :function_definition => FunctionDefinitionNode
}.freeze
```

### AST Node Validation

**Built-in Validation Patterns:**
```ruby
# ✅ GOOD: Node validation
class BinaryExpressionNode < ASTNode
  VALID_OPERATORS = [:+, :-, :*, :/, :==, :!=, :<, :>, :<=, :>=].freeze
  
  def initialize(left, operator, right, **kwargs)
    super(:binary_expression, **kwargs)
    validate_operator(operator)
    validate_operands(left, right)
    
    @left = left
    @operator = operator
    @right = right
  end
  
  private
  
  def validate_operator(operator)
    unless VALID_OPERATORS.include?(operator)
      raise ArgumentError, "Invalid operator: #{operator}"
    end
  end
  
  def validate_operands(left, right)
    unless left.is_a?(ASTNode) && right.is_a?(ASTNode)
      raise ArgumentError, "Operands must be AST nodes"
    end
  end
end
```

---

## Parser Module Organization

### Parser Module Structure

**Follow Patlang Parser Patterns:**
```ruby
# ✅ GOOD: Standard parser module pattern
module Patlang
  module ParserModules
    class ExpressionParser
      def initialize(tokens)
        @tokens = tokens
        @current = 0
      end
      
      def parse
        parse_expression
      end
      
      private
      
      def parse_expression
        parse_equality
      end
      
      def parse_equality
        expr = parse_comparison
        
        while match(:EQUAL_EQUAL, :BANG_EQUAL)
          operator = previous.type
          right = parse_comparison
          expr = BinaryExpressionNode.new(expr, operator, right)
        end
        
        expr
      end
      
      def parse_comparison
        # Implementation following precedence rules
      end
      
      # Standard helper methods
      def match(*types)
        types.any? { |type| check(type) && advance }
      end
      
      def check(type)
        return false if at_end?
        peek.type == type
      end
      
      def advance
        @current += 1 unless at_end?
        previous
      end
      
      def at_end?
        @current >= @tokens.length
      end
      
      def peek
        @tokens[@current]
      end
      
      def previous
        @tokens[@current - 1]
      end
    end
  end
end
```

### Parser Integration Patterns

**Module Coordination:**
```ruby
# ✅ GOOD: Parser module integration
class Parser
  def initialize(tokens)
    @tokens = tokens
    @expression_parser = ParserModules::ExpressionParser.new(tokens)
    @control_flow_parser = ParserModules::ControlFlowParser.new(tokens)
    @function_parser = ParserModules::FunctionParser.new(tokens)
  end
  
  def parse
    statements = []
    
    while !at_end?
      stmt = parse_statement
      statements << stmt if stmt
    end
    
    statements
  end
  
  private
  
  def parse_statement
    case peek.type
    when :IF
      @control_flow_parser.parse_if_statement
    when :WHILE
      @control_flow_parser.parse_while_statement
    when :FUNCTION
      @function_parser.parse_function_definition
    else
      @expression_parser.parse_expression_statement
    end
  end
end
```

### Token Resolution Patterns

**Centralized Token Handling:**
```ruby
# ✅ GOOD: Token resolver pattern
module Patlang
  module ParserModules
    class TokenResolver
      def self.resolve_ambiguous_token(token, context)
        case token.value
        when 'if'
          context.expecting_keyword? ? Token.new(:IF, 'if') : Token.new(:IDENTIFIER, 'if')
        when '('
          context.in_function_call? ? Token.new(:LPAREN_CALL, '(') : Token.new(:LPAREN, '(')
        else
          token
        end
      end
      
      def self.determine_context(tokens, position)
        # Context analysis logic
        Context.new(tokens, position)
      end
    end
    
    class Context
      def initialize(tokens, position)
        @tokens = tokens
        @position = position
      end
      
      def expecting_keyword?
        # Logic to determine if we're expecting a keyword
      end
      
      def in_function_call?
        # Logic to determine if we're in a function call context
      end
    end
  end
end
```

---

## Evaluator Module Organization

### Evaluator Module Structure

**Standard Evaluator Pattern:**
```ruby
# ✅ GOOD: Evaluator module pattern
module Patlang
  module EvaluatorModules
    class ArithmeticEvaluator
      def self.evaluate(node, context)
        case node.operator
        when :+
          add(node.left, node.right, context)
        when :-
          subtract(node.left, node.right, context)
        when :*
          multiply(node.left, node.right, context)
        when :/
          divide(node.left, node.right, context)
        else
          raise EvaluationError, "Unknown arithmetic operator: #{node.operator}"
        end
      end
      
      private
      
      def self.add(left, right, context)
        left_val = context.evaluate(left)
        right_val = context.evaluate(right)
        
        validate_numeric_operands(left_val, right_val, :+)
        left_val + right_val
      end
      
      def self.validate_numeric_operands(left, right, operator)
        unless numeric?(left) && numeric?(right)
          raise TypeError, "Operator #{operator} requires numeric operands"
        end
      end
      
      def self.numeric?(value)
        value.is_a?(Numeric)
      end
    end
  end
end
```

### Scope Management Patterns

**Consistent Scope Handling:**
```ruby
# ✅ GOOD: Scope manager pattern
module Patlang
  module EvaluatorModules
    class ScopeManager
      def initialize
        @scopes = [{}]  # Global scope starts empty
      end
      
      def define_variable(name, value)
        current_scope[name] = value
      end
      
      def get_variable(name)
        @scopes.reverse_each do |scope|
          return scope[name] if scope.key?(name)
        end
        
        raise UndefinedVariableError, "Variable '#{name}' is not defined"
      end
      
      def enter_scope
        @scopes.push({})
      end
      
      def exit_scope
        raise RuntimeError, "Cannot exit global scope" if @scopes.length <= 1
        @scopes.pop
      end
      
      def in_scope
        enter_scope
        yield
      ensure
        exit_scope
      end
      
      private
      
      def current_scope
        @scopes.last
      end
    end
  end
end
```

### Evaluator Integration

**Main Evaluator Coordination:**
```ruby
# ✅ GOOD: Evaluator integration pattern
class Evaluator
  def initialize
    @scope_manager = EvaluatorModules::ScopeManager.new
    setup_builtin_functions
  end
  
  def evaluate(node)
    case node.type
    when :integer_literal, :float_literal, :string_literal
      node.value
    when :binary_expression
      evaluate_binary_expression(node)
    when :function_call
      EvaluatorModules::FunctionEvaluator.evaluate(node, self)
    when :assignment
      evaluate_assignment(node)
    else
      raise EvaluationError, "Unknown node type: #{node.type}"
    end
  end
  
  private
  
  def evaluate_binary_expression(node)
    case node.operator
    when :+, :-, :*, :/
      EvaluatorModules::ArithmeticEvaluator.evaluate(node, self)
    when :==, :!=, :<, :>, :<=, :>=
      EvaluatorModules::ComparisonEvaluator.evaluate(node, self)
    else
      raise EvaluationError, "Unknown binary operator: #{node.operator}"
    end
  end
  
  def setup_builtin_functions
    @scope_manager.define_variable('print', BuiltinFunction.new('print') { |arg| puts arg })
    @scope_manager.define_variable('input', BuiltinFunction.new('input') { gets.chomp })
  end
end
```

---

## Token and Lexer Patterns

### Token Class Standards

**Consistent Token Structure:**
```ruby
# ✅ GOOD: Standard token pattern
class Token
  attr_reader :type, :value, :line, :column
  
  def initialize(type, value, line: nil, column: nil)
    @type = type
    @value = value
    @line = line
    @column = column
  end
  
  def ==(other)
    other.is_a?(Token) && 
      type == other.type && 
      value == other.value
  end
  
  def to_s
    "Token(#{type}, #{value.inspect})"
  end
  
  def inspect
    to_s
  end
end

# Token type constants
module TokenTypes
  # Literals
  INTEGER = :INTEGER
  FLOAT = :FLOAT
  STRING = :STRING
  TRUE = :TRUE
  FALSE = :FALSE
  
  # Identifiers and keywords
  IDENTIFIER = :IDENTIFIER
  IF = :IF
  WHILE = :WHILE
  FUNCTION = :FUNCTION
  
  # Operators
  PLUS = :PLUS
  MINUS = :MINUS
  MULTIPLY = :MULTIPLY
  DIVIDE = :DIVIDE
  
  # Punctuation
  LPAREN = :LPAREN
  RPAREN = :RPAREN
  LBRACE = :LBRACE
  RBRACE = :RBRACE
  
  # Special
  EOF = :EOF
  NEWLINE = :NEWLINE
end
```

### Lexer Pattern Standards

**Consistent Lexer Structure:**
```ruby
# ✅ GOOD: Standard lexer pattern
class Lexer
  KEYWORDS = {
    'if' => TokenTypes::IF,
    'while' => TokenTypes::WHILE,
    'function' => TokenTypes::FUNCTION,
    'true' => TokenTypes::TRUE,
    'false' => TokenTypes::FALSE
  }.freeze
  
  def initialize(source)
    @source = source
    @tokens = []
    @current = 0
    @line = 1
    @column = 1
  end
  
  def tokenize
    while !at_end?
      @start = @current
      scan_token
    end
    
    @tokens << Token.new(TokenTypes::EOF, nil, line: @line, column: @column)
    @tokens
  end
  
  private
  
  def scan_token
    char = advance
    
    case char
    when ' ', '\r', '\t'
      # Ignore whitespace
    when '\n'
      @line += 1
      @column = 1
      @tokens << Token.new(TokenTypes::NEWLINE, '\n', line: @line - 1)
    when '+'
      add_token(TokenTypes::PLUS)
    when '-'
      add_token(TokenTypes::MINUS)
    when '*'
      add_token(TokenTypes::MULTIPLY)
    when '/'
      add_token(TokenTypes::DIVIDE)
    when '('
      add_token(TokenTypes::LPAREN)
    when ')'
      add_token(TokenTypes::RPAREN)
    when '"'
      string_literal
    else
      if digit?(char)
        number_literal
      elsif alpha?(char)
        identifier
      else
        raise LexError, "Unexpected character: #{char} at line #{@line}, column #{@column}"
      end
    end
  end
  
  def string_literal
    while peek != '"' && !at_end?
      @line += 1 if peek == '\n'
      advance
    end
    
    raise LexError, "Unterminated string at line #{@line}" if at_end?
    
    # Consume closing "
    advance
    
    # Get string value without quotes
    value = @source[@start + 1...@current - 1]
    add_token(TokenTypes::STRING, value)
  end
  
  def number_literal
    while digit?(peek)
      advance
    end
    
    # Look for decimal point
    if peek == '.' && digit?(peek_next)
      advance  # Consume '.'
      while digit?(peek)
        advance
      end
      
      value = @source[@start...@current].to_f
      add_token(TokenTypes::FLOAT, value)
    else
      value = @source[@start...@current].to_i
      add_token(TokenTypes::INTEGER, value)
    end
  end
  
  def identifier
    while alphanumeric?(peek)
      advance
    end
    
    text = @source[@start...@current]
    type = KEYWORDS[text] || TokenTypes::IDENTIFIER
    add_token(type, text)
  end
  
  # Helper methods
  def advance
    char = @source[@current]
    @current += 1
    @column += 1
    char
  end
  
  def peek
    return '\0' if at_end?
    @source[@current]
  end
  
  def peek_next
    return '\0' if @current + 1 >= @source.length
    @source[@current + 1]
  end
  
  def at_end?
    @current >= @source.length
  end
  
  def digit?(char)
    char >= '0' && char <= '9'
  end
  
  def alpha?(char)
    (char >= 'a' && char <= 'z') ||
    (char >= 'A' && char <= 'Z') ||
    char == '_'
  end
  
  def alphanumeric?(char)
    alpha?(char) || digit?(char)
  end
  
  def add_token(type, value = nil)
    @tokens << Token.new(type, value, line: @line, column: @column - (@current - @start))
  end
end
```

---

## Error Message Standards

### Consistent Error Formatting

**Standardized Error Messages:**
```ruby
# ✅ GOOD: Consistent error formatting
module Patlang
  class Error < StandardError
    attr_reader :line, :column, :component
    
    def initialize(message, line: nil, column: nil, component: nil)
      @line = line
      @column = column
      @component = component
      
      formatted_message = format_error_message(message)
      super(formatted_message)
    end
    
    private
    
    def format_error_message(message)
      parts = []
      parts << "[#{component}]" if component
      parts << "Line #{line}" if line
      parts << "Column #{column}" if column
      parts << message
      
      parts.join(" ")
    end
  end
  
  # Specific error types
  class LexError < Error
    def initialize(message, **kwargs)
      super(message, component: "Lexer", **kwargs)
    end
  end
  
  class ParseError < Error
    def initialize(message, **kwargs)
      super(message, component: "Parser", **kwargs)
    end
  end
  
  class EvaluationError < Error
    def initialize(message, **kwargs)
      super(message, component: "Evaluator", **kwargs)
    end
  end
end
```

### Context-Rich Error Messages

**Provide Helpful Error Context:**
```ruby
# ✅ GOOD: Helpful error messages
def parse_function_call(name_token)
  unless match(TokenTypes::LPAREN)
    raise ParseError.new(
      "Expected '(' after function name '#{name_token.value}'",
      line: name_token.line,
      column: name_token.column
    )
  end
  
  arguments = []
  
  unless check(TokenTypes::RPAREN)
    loop do
      arguments << parse_expression
      break unless match(TokenTypes::COMMA)
    end
  end
  
  unless match(TokenTypes::RPAREN)
    raise ParseError.new(
      "Expected ')' after function arguments. Found #{peek.type}",
      line: peek.line,
      column: peek.column
    )
  end
  
  FunctionCallNode.new(name_token.value, arguments)
end
```

### Error Recovery Strategies

**Graceful Error Handling:**
```ruby
# ✅ GOOD: Error recovery in parser
def parse_statement
  begin
    parse_primary_statement
  rescue ParseError => e
    puts "Parse error: #{e.message}"
    
    # Attempt to synchronize to next statement
    synchronize
    
    # Return error node to continue parsing
    ErrorNode.new(e.message, line: e.line, column: e.column)
  end
end

def synchronize
  advance
  
  while !at_end?
    return if previous.type == TokenTypes::NEWLINE
    
    case peek.type
    when TokenTypes::IF, TokenTypes::WHILE, TokenTypes::FUNCTION
      return
    end
    
    advance
  end
end
```

---

## Architecture Guidelines

### Extension Patterns

**How to Add New Language Features:**

1. **Add New Token Types (if needed):**
```ruby
# In token.rb
module TokenTypes
  # ... existing types ...
  MATCH = :MATCH      # New token type
  CASE = :CASE        # New token type
end

# In lexer.rb
KEYWORDS = {
  # ... existing keywords ...
  'match' => TokenTypes::MATCH,
  'case' => TokenTypes::CASE
}.merge(KEYWORDS)
```

2. **Create New AST Node Types:**
```ruby
# In ast_nodes.rb
class MatchNode < ASTNode
  attr_reader :expression, :cases
  
  def initialize(expression, cases, **kwargs)
    super(:match, **kwargs)
    @expression = expression
    @cases = cases
  end
end

class CaseNode < ASTNode
  attr_reader :pattern, :body
  
  def initialize(pattern, body, **kwargs)
    super(:case, **kwargs)
    @pattern = pattern
    @body = body
  end
end
```

3. **Add Parser Module:**
```ruby
# In parser/pattern_parser.rb
module Patlang
  module ParserModules
    class PatternParser
      def initialize(tokens)
        @tokens = tokens
        @current = 0
      end
      
      def parse_match_statement
        # Implementation
      end
    end
  end
end
```

4. **Add Evaluator Module:**
```ruby
# In evaluator/pattern_evaluator.rb
module Patlang
  module EvaluatorModules
    class PatternEvaluator
      def self.evaluate(node, context)
        # Implementation
      end
    end
  end
end
```

5. **Integrate into Main Components:**
```ruby
# In parser.rb
def parse_statement
  case peek.type
  when TokenTypes::MATCH
    @pattern_parser.parse_match_statement
  # ... existing cases ...
  end
end

# In evaluator.rb
def evaluate(node)
  case node.type
  when :match
    EvaluatorModules::PatternEvaluator.evaluate(node, self)
  # ... existing cases ...
  end
end
```

### Module Dependency Management

**Clean Dependencies:**
```ruby
# ✅ GOOD: Clear dependency management
module Patlang
  # Define load order
  def self.load_components
    require_relative 'ast_nodes'
    require_relative 'token'
    require_relative 'lexer'
    
    # Load parser modules before main parser
    load_parser_modules
    require_relative 'parser'
    
    # Load evaluator modules before main evaluator
    load_evaluator_modules
    require_relative 'evaluator'
  end
  
  def self.load_parser_modules
    %w[
      parser/token_resolver
      parser/expression_parser
      parser/control_flow_parser
      parser/function_parser
    ].each { |mod| require_relative mod }
  end
  
  def self.load_evaluator_modules
    %w[
      evaluator/scope_manager
      evaluator/arithmetic_evaluator
      evaluator/function_evaluator
      evaluator/string_evaluator
    ].each { |mod| require_relative mod }
  end
end
```

---

## Integration Testing Patterns

### End-to-End Testing

**Complete Pipeline Testing:**
```ruby
# ✅ GOOD: End-to-end test pattern
class TestPatlangIntegration < Minitest::Test
  def test_complete_pipeline
    source = <<~PATLANG
      function greet(name)
        "Hello, " + name + "!"
      end
      
      result = greet("World")
      print(result)
    PATLANG
    
    # Test complete pipeline
    lexer = Lexer.new(source)
    tokens = lexer.tokenize
    
    parser = Parser.new(tokens)
    ast = parser.parse
    
    evaluator = Evaluator.new
    output = capture_stdout do
      evaluator.evaluate_program(ast)
    end
    
    assert_equal "Hello, World!\n", output
  end
  
  def test_error_propagation
    source = "undefined_function()"
    
    lexer = Lexer.new(source)
    tokens = lexer.tokenize
    
    parser = Parser.new(tokens)
    ast = parser.parse
    
    evaluator = Evaluator.new
    
    error = assert_raises(EvaluationError) do
      evaluator.evaluate_program(ast)
    end
    
    assert_includes error.message, "undefined_function"
    assert_includes error.message, "Evaluator"
  end
  
  private
  
  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end
```

### Component Integration Testing

**Module Interaction Testing:**
```ruby
# ✅ GOOD: Component integration tests
class TestParserEvaluatorIntegration < Minitest::Test
  def test_expression_parsing_and_evaluation
    test_cases = [
      { source: "1 + 2", expected: 3 },
      { source: "3 * 4 + 5", expected: 17 },
      { source: '"hello" + " world"', expected: "hello world" },
      { source: "true == false", expected: false }
    ]
    
    test_cases.each do |test_case|
      tokens = Lexer.new(test_case[:source]).tokenize
      ast = Parser.new(tokens).parse.first
      result = Evaluator.new.evaluate(ast)
      
      assert_equal test_case[:expected], result,
                   "Failed for expression: #{test_case[:source]}"
    end
  end
  
  def test_function_definition_and_call
    source = <<~PATLANG
      function add(a, b)
        a + b
      end
      
      add(3, 4)
    PATLANG
    
    tokens = Lexer.new(source).tokenize
    statements = Parser.new(tokens).parse
    
    evaluator = Evaluator.new
    
    # Evaluate function definition
    evaluator.evaluate(statements[0])
    
    # Evaluate function call
    result = evaluator.evaluate(statements[1])
    
    assert_equal 7, result
  end
end
```

---

## Summary

Patlang-specific coding standards ensure consistency and maintainability across the interpreter implementation:

### Key Standards:

1. **Module Organization**: Use [`ParserModules`](../src/parser) and [`EvaluatorModules`](../src/evaluator) namespaces
2. **AST Nodes**: Inherit from [`ASTNode`](../patlang-core/ast/ast_nodes.rb) with consistent patterns
3. **Error Handling**: Use project-specific error types with rich context
4. **Token Management**: Follow [`TokenTypes`](../patlang-core/lexer/token.rb) constants and [`Token`](../patlang-core/lexer/token.rb) class patterns
5. **Integration**: Test complete pipelines and component interactions

### Architecture Principles:

- **Separation of Concerns**: Keep lexer, parser, and evaluator responsibilities clear
- **Extensibility**: Design for easy addition of new language features
- **Error Recovery**: Provide helpful error messages and recovery strategies
- **Testing**: Maintain comprehensive integration test coverage

### Extension Guidelines:

- Add token types in [`token.rb`](../patlang-core/lexer/token.rb)
- Create AST nodes in [`ast_nodes.rb`](../patlang-core/ast/ast_nodes.rb)
- Build parser modules in [`parser/`](../src/parser) directory
- Build evaluator modules in [`evaluator/`](../src/evaluator) directory
- Update main [`parser.rb`](../patlang-core/parser/parser.rb) and [`evaluator.rb`](../patlang-core/evaluator/evaluator.rb) for integration

Refer to [`development-guidelines.md`](development-guidelines.md) for general coding standards and [`mode-specific-guidelines.md`](mode-specific-guidelines.md) for development workflow practices.