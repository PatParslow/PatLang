require_relative 'token'
require_relative 'ast_nodes'
require_relative 'ambiguous_token'
require_relative 'parser/token_resolver'
require_relative 'parser/expression_parser'
require_relative 'parser/function_parser'
require_relative 'parser/control_flow_parser'

# Parser class for parsing Patlang source code with modular architecture
class Parser
  attr_reader :current_token

  def initialize(tokens_or_lexer)
    # Handle both tokens array and lexer object
    if tokens_or_lexer.is_a?(Lexer)
      @tokens = tokens_or_lexer.tokenize
    else
      @tokens = tokens_or_lexer
    end
    @current_token_index = 0
    @current_token = @tokens[@current_token_index]
    
    # Initialize specialized parsers
    @token_resolver = ParserModules::TokenResolver.new(@tokens)
    @expression_parser = ParserModules::ExpressionParser.new(self)
    @function_parser = ParserModules::FunctionParser.new(self)
    @control_flow_parser = ParserModules::ControlFlowParser.new(self)
  end

  def error(message = "Parse error")
    raise "#{message} at token #{@current_token}"
  end

  def advance
    @current_token_index += 1
    if @current_token_index < @tokens.length
      @current_token = @tokens[@current_token_index]
    else
      @current_token = nil
    end
  end

  def eat(expected_type)
    if @current_token && @current_token.type == expected_type
      advance
    else
      error("Expected #{expected_type}, got #{@current_token&.type}")
    end
  end

  def peek(offset = 1)
    peek_index = @current_token_index + offset
    if peek_index < @tokens.length
      @tokens[peek_index]
    else
      nil
    end
  end

  # Enhanced parse method with token resolution
  def parse
    @tokens = @token_resolver.resolve_all_ambiguous_tokens
    @current_token_index = 0
    @current_token = @tokens[0] if @tokens.length > 0
    program
  end

  # Grammar: program → statement*
  def program
    statements = []
    while @current_token && @current_token.type != :EOF
      stmt = statement
      statements << stmt if stmt
    end
    return statements.length == 1 ? statements[0] : BlockNode.new(statements)
  end

  # Grammar: statement → assignment | expression | function_definition | function_call | control_flow
  def statement
    return nil unless @current_token

    case @current_token.type
    when :MAKE
      # CRITICAL FIX: Check for assignment BEFORE falling through to function definition
      if peek(1)&.type == :ASSIGN || peek(1)&.type == :IS
        # "make var = value" or "make var is value"
        return parse_assignment
      elsif peek(1)&.type == :IDENTIFIER && 
            (peek(2)&.type == :ASSIGN || peek(2)&.type == :IS || 
             peek(2)&.type == :NUMBER || peek(2)&.type == :STRING || 
             peek(2)&.type == :IDENTIFIER || peek(2)&.type == :LPAREN ||
             peek(2)&.type == :EOF || peek(2) == nil)
        # "make var value" - elegant syntax without assignment operator
        return parse_assignment
      elsif (peek(1)&.type == :IDENTIFIER && peek(1)&.value == "a" &&
            peek(2)&.type == :FUNCTION) ||
            (peek(1)&.type == :FUNCTION)
        # This is a function definition: "make [a] function [called]..."
        return @function_parser.parse_function_definition
      else
        # This is a standalone make variable reference
        return expression
      end
    when :CALL
      return @function_parser.parse_function_call
    when :IF
      return @control_flow_parser.parse_if_statement
    when :WHILE
      return @control_flow_parser.parse_while_statement
    when :RETURN
      return @control_flow_parser.parse_return_statement
    when :PRINT
      return @control_flow_parser.parse_print_statement
    when :REASONING
      return parse_reasoning_mode
    when :CONSTRAIN
      return parse_constraint
    when :GOAL
      return parse_goal
    when :ASSERT
      return parse_assert
    when :QUERY
      return parse_query
    when :RULE
      return parse_rule
    when :PURSUE
      return parse_pursue
    when :IDENTIFIER
      # CRITICAL FIX: Check for assignment BEFORE falling through to expression
      if peek(1)&.type == :ASSIGN || peek(1)&.type == :IS
        return parse_assignment
      else
        return expression
      end
    else
      return expression
    end
  end

  # Grammar: assignment → IDENTIFIER ('=' | 'is') expression | MAKE IDENTIFIER (('=' | 'is') | '') expression
  def parse_assignment
    if @current_token.type == :MAKE
      # Handle "make variable ..." patterns
      eat(:MAKE)
      var_name = @current_token.value
      eat(:IDENTIFIER)
      
      # MAKE can be followed by assignment operator OR directly by expression
      if @current_token.type == :ASSIGN || @current_token.type == :IS
        # "make y = 17" or "make y is 17" (though "make y is 17" is discouraged)
        if @current_token.type == :ASSIGN
          eat(:ASSIGN)
        else
          eat(:IS)
        end
      end
      # If no assignment operator, proceed directly to expression: "make y 17"
      
      value = expression
      return AssignmentNode.new(var_name, value)
      
    elsif @current_token.type == :IDENTIFIER
      # Handle "variable is/= ..." patterns
      var_name = @current_token.value
      eat(:IDENTIFIER)
      
      # IDENTIFIER must be followed by assignment operator
      if @current_token.type == :ASSIGN
        eat(:ASSIGN)
      elsif @current_token.type == :IS
        eat(:IS)
      else
        error("Expected '=' or 'is' after identifier for assignment")
      end
      
      value = expression
      return AssignmentNode.new(var_name, value)
    else
      error("Expected IDENTIFIER or MAKE for variable assignment")
    end
  end

  # Delegate expression parsing to the specialized parser
  def expression
    @expression_parser.expression
  end

  # Delegate function call parsing to the specialized parser
  def parse_function_call
    @function_parser.parse_function_call
  end

  # Parse reasoning mode control: reasoning mode on/off
  def parse_reasoning_mode
    eat(:REASONING)
    eat(:MODE)
    
    if @current_token.type == :ON
      eat(:ON)
      ReasoningModeNode.new(true)
    elsif @current_token.type == :OFF
      eat(:OFF)
      ReasoningModeNode.new(false)
    else
      error("Expected 'on' or 'off' after 'reasoning mode'")
    end
  end

  # Parse constraint declaration: constrain x :: Number where x > 0
  def parse_constraint
    eat(:CONSTRAIN)
    
    variable = @current_token.value
    eat(:IDENTIFIER)
    
    eat(:DOUBLE_COLON)
    
    type = @current_token.value
    eat(:IDENTIFIER)
    
    conditions = nil
    if @current_token.type == :WHERE
      eat(:WHERE)
      conditions = expression
    end
    
    ConstraintNode.new(variable, type, conditions)
  end

  # Parse goal declaration: goal find_answer { postcondition: answer > 0 }
  def parse_goal
    eat(:GOAL)
    
    goal_name = @current_token.value
    eat(:IDENTIFIER)
    
    parameters = []
    if @current_token.type == :LPAREN
      eat(:LPAREN)
      while @current_token.type != :RPAREN
        parameters << @current_token.value
        eat(:IDENTIFIER)
        if @current_token.type == :COMMA
          eat(:COMMA)
        end
      end
      eat(:RPAREN)
    end
    
    precondition = nil
    postcondition = nil
    strategy = nil
    
    if @current_token.type == :LBRACE
      eat(:LBRACE)
      
      while @current_token.type != :RBRACE
        case @current_token.type
        when :PRECONDITION
          eat(:PRECONDITION)
          eat(:COLON)
          precondition = expression
        when :POSTCONDITION
          eat(:POSTCONDITION)
          eat(:COLON)
          postcondition = expression
        when :STRATEGY
          eat(:STRATEGY)
          eat(:COLON)
          strategy = @current_token.value
          eat(:IDENTIFIER)
        else
          error("Expected precondition, postcondition, or strategy in goal body")
        end
        
        if @current_token.type == :COMMA
          eat(:COMMA)
        end
      end
      
      eat(:RBRACE)
    end
    
    GoalNode.new(goal_name, parameters, precondition, postcondition, strategy)
  end

  # Parse assert statement: assert fact(likes(alice, bob))
  def parse_assert
    eat(:ASSERT)
    fact = expression
    AssertNode.new(fact)
  end

  # Parse query: query likes(X, bob)
  def parse_query
    eat(:QUERY)
    pattern = expression
    QueryNode.new(pattern)
  end

  # Parse rule definition: rule ancestor(X, Y) :- parent(X, Y)
  def parse_rule
    eat(:RULE)
    head = expression
    
    # Look for :- operator (we'll need to add this to the lexer)
    if @current_token.type == :COLON && peek(1)&.type == :MINUS
      eat(:COLON)
      eat(:MINUS)
      body = expression
      RuleNode.new(head, body)
    else
      error("Expected ':-' after rule head")
    end
  end

  # Parse pursue statement: pursue find_answer
  def parse_pursue
    eat(:PURSUE)
    goal_name = @current_token.value
    eat(:IDENTIFIER)
    
    arguments = []
    if @current_token.type == :LPAREN
      eat(:LPAREN)
      while @current_token.type != :RPAREN
        arguments << expression
        if @current_token.type == :COMMA
          eat(:COMMA)
        end
      end
      eat(:RPAREN)
    end
    
    PursueNode.new(goal_name, arguments)
  end
end