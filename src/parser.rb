require_relative 'token'
require_relative 'ast_nodes'
require_relative 'ambiguous_token'
require_relative 'exceptions'
require_relative 'parser/token_resolver'
require_relative 'parser/expression_parser'
require_relative 'parser/function_parser'
require_relative 'parser/control_flow_parser'
require_relative 'parser/type_constraint_parser'
require_relative 'parser/parser_timeout_protection'
require_relative 'object_model/event_system'

# Parser class for parsing Patlang source code with modular architecture
require_relative 'hash_extensions'
class Parser
  include EventSystem::EventCapable
  include ParserModules::TimeoutProtection
  attr_reader :current_token, :current_token_index, :collected_errors

  def initialize(tokens_or_lexer)
    # Initialize event system
    initialize_event_system
    
    # Initialize error collection for comprehensive error recovery
    @collected_errors = []
    
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
    @type_constraint_parser = ParserModules::TypeConstraintParser.new(self)
  end

  # Collect error information for comprehensive error reporting
  def collect_error(error_info)
    @collected_errors << error_info
    puts "[Parser ERROR COLLECTION] #{error_info[:message]} at position #{error_info[:position]}"
  end

  # Get all collected errors for comprehensive reporting
  def get_all_errors
    @collected_errors
  end

  # Check if any errors were collected during parsing
  def has_errors?
    !@collected_errors.empty?
  end

  def error(message = "Parse error")
    if @current_token
      raise ParseError.new(
        "#{message} at token #{@current_token}",
        line: @current_token.line,
        column: @current_token.column,
        position: @current_token.position,
        token: @current_token
      )
    else
      raise ParseError.new(message)
    end
  end
  
  # Raise RuntimeError for critical syntax errors that should not be recovered from
  def syntax_error(message = "Syntax error")
    raise RuntimeError, message
  end
  
  # Safe error method that returns an ErrorNode instead of raising
  def safe_error(message = "Parse error")
    ErrorNode.new(message)
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
  
  # Safe eat method that doesn't raise errors
  def safe_eat(expected_type)
    if @current_token && @current_token.type == expected_type
      advance
      true
    else
      false
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

  # Enhanced parse method with comprehensive timeout protection
  def parse
    with_parse_timeout(15.0, "main parse operation") do
      @tokens = @token_resolver.resolve_all_ambiguous_tokens
      @current_token_index = 0
      @current_token = @tokens[0] if @tokens.length > 0
      program
    end
  rescue EmergencyTimeout::TimeoutError => e
    safe_error("Parser timeout: #{e.message}")
  end

  # Grammar: program → statement* with loop protection
  def program
    statements = []
    circuit_breaker = create_circuit_breaker(1000)
    
    while @current_token && @current_token.type != :EOF
      circuit_breaker.check_iteration(@current_token_index)
      
      # Store position before parsing statement
      pre_statement_position = @current_token_index
      
      stmt = statement
      statements << stmt if stmt
      
      # Critical protection: ensure position advances after each statement
      if @current_token_index == pre_statement_position && @current_token
        puts "[Parser WARNING] Statement parsing did not advance token position, forcing advance"
        advance # Force advancement to prevent infinite loop
      end
    end
    
    return statements.length == 1 ? statements[0] : BlockNode.new(statements)
  rescue EmergencyTimeout::TimeoutError => e
    safe_error("Program parsing timeout: #{e.message}")
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
    when :QUERY_PREFIX
      return parse_prolog_query
    when :RULE
      return parse_rule
    when :FACT
      return parse_fact
    when :PURSUE
      return parse_pursue
    when :IDENTIFIER
      # CRITICAL FIX: Check for type annotation and assignment BEFORE falling through to expression
      if peek(1)&.type == :DOUBLE_COLON
        return @type_constraint_parser.parse_type_annotation
      elsif peek(1)&.type == :COLON
        return @type_constraint_parser.parse_typed_assignment
      elsif peek(1)&.type == :ASSIGN || peek(1)&.type == :IS
        return parse_assignment
      elsif is_property_assignment?
        return parse_property_assignment
      else
        return expression
      end
    else
      return expression
    end
  end

  # Grammar: assignment → IDENTIFIER ('=' | 'is') expression | MAKE IDENTIFIER (('=' | 'is') | '') expression
  def parse_assignment
    begin
      if @current_token.type == :MAKE
        # Handle "make variable ..." patterns
        eat(:MAKE)
        
        # Error recovery: check for missing identifier
        if @current_token.nil? || @current_token.type != :IDENTIFIER
          return safe_error("Expected identifier after 'make'")
        end
        
        var_name = @current_token.value
        eat(:IDENTIFIER)
        
        # MAKE can be followed by assignment operator OR directly by expression
        if @current_token&.type == :ASSIGN || @current_token&.type == :IS
          # "make y = 17" or "make y is 17" (though "make y is 17" is discouraged)
          if @current_token.type == :ASSIGN
            eat(:ASSIGN)
          else
            eat(:IS)
          end
        end
        # If no assignment operator, proceed directly to expression: "make y 17"
        
        # Error recovery: check for missing value
        if @current_token.nil?
          return safe_error("Expected value after variable declaration")
        end
        
        value = expression
        return AssignmentNode.new(var_name, value || safe_error("Missing assignment value"))
        
      elsif @current_token.type == :IDENTIFIER
        # Handle "variable is/= ..." patterns
        var_name = @current_token.value
        eat(:IDENTIFIER)
        
        # IDENTIFIER must be followed by assignment operator
        if @current_token&.type == :ASSIGN
          eat(:ASSIGN)
        elsif @current_token&.type == :IS
          eat(:IS)
        else
          return safe_error("Expected '=' or 'is' after identifier for assignment")
        end
        
        # Error recovery: check for missing value
        if @current_token.nil?
          syntax_error("Expected value after assignment operator")
        end
        
        value = expression
        # Check if expression parsing failed with critical error
        if value.is_a?(ErrorNode) && value.message.include?("Unexpected end of input")
          syntax_error("Expected value after assignment operator")
        end
        return AssignmentNode.new(var_name, value || safe_error("Missing assignment value"))
      else
        return safe_error("Expected IDENTIFIER or MAKE for variable assignment")
      end
    rescue ParseError => e
      return safe_error("Assignment parse error: #{e.message}")
    end
  end

  # Check if current position looks like a property assignment: obj.prop = value
  def is_property_assignment?
    return false unless @current_token.type == :IDENTIFIER
    return false unless peek(1)&.type == :DOT
    return false unless peek(2)&.type == :IDENTIFIER
    return peek(3)&.type == :ASSIGN || peek(3)&.type == :IS
  end

  # Parse property assignment: obj.prop = value
  def parse_property_assignment
    # Parse the object reference
    object_name = @current_token.value
    eat(:IDENTIFIER)
    eat(:DOT)
    
    # Parse the property name
    property_name = @current_token.value
    eat(:IDENTIFIER)
    
    # Parse the assignment operator
    if @current_token.type == :ASSIGN
      eat(:ASSIGN)
    elsif @current_token.type == :IS
      eat(:IS)
    else
      error("Expected '=' or 'is' for property assignment")
    end
    
    # Parse the value expression
    value = expression
    
    # Create a PropertyAssignmentNode
    return PropertyAssignmentNode.new(object_name, property_name, value)
  end

  # Delegate expression parsing to the specialized parser with error recovery
  def expression
    begin
      @expression_parser.expression
    rescue ParseError => e
      safe_error("Expression parse error: #{e.message}")
    end
  end

  # Delegate function call parsing to the specialized parser
  def parse_function_call
    @function_parser.parse_function_call
  end

  # Parse reasoning mode control: reasoning mode on/off
  def parse_reasoning_mode
    begin
      eat(:REASONING)
      
      if @current_token.nil?
        return safe_error("Expected 'mode' after 'reasoning'")
      end
      
      eat(:MODE)
      
      if @current_token.nil?
        return safe_error("Expected 'on' or 'off' after 'reasoning mode'")
      end
      
      if @current_token.type == :ON
        eat(:ON)
        ReasoningModeNode.new(true)
      elsif @current_token.type == :OFF
        eat(:OFF)
        ReasoningModeNode.new(false)
      else
        safe_error("Expected 'on' or 'off' after 'reasoning mode'")
      end
    rescue ParseError => e
      safe_error("Reasoning mode parse error: #{e.message}")
    end
  end

  # Parse constraint declaration: constrain x :: Number where x > 0
  # Enhanced to support dotted expressions: constrain obj.field :: Type
  def parse_constraint
    begin
      eat(:CONSTRAIN)
      
      if @current_token.nil?
        return safe_error("Expected variable after 'constrain'")
      end
      
      # Parse variable expression (can be simple identifier or dotted expression)
      variable_expr = parse_constraint_variable
      
      # If parse_constraint_variable failed, return error
      if variable_expr.nil?
        return safe_error("Invalid constraint variable")
      end
      
      if @current_token.nil? || @current_token.type != :DOUBLE_COLON
        return safe_error("Expected '::' after constraint variable")
      end
      
      eat(:DOUBLE_COLON)
      
      if @current_token.nil? || @current_token.type != :IDENTIFIER
        return safe_error("Expected type after '::'")
      end
      
      constraint_type = @current_token.value
      eat(:IDENTIFIER)
      
      conditions = nil
      if @current_token&.type == :WHERE
        eat(:WHERE)
        
        if @current_token.nil?
          return safe_error("Expected condition after 'where'")
        end
        
        conditions = expression
      end
      
      # Create TypeConstraintNode with proper parameters
      TypeConstraintNode.new(variable_expr, constraint_type, nil, conditions)
    rescue ParseError => e
      safe_error("Constraint parse error: #{e.message}")
    end
  end

  # Parse constraint variable which can be:
  # - Simple identifier: x
  # - Dotted expression: obj.field, user.name.length
  def parse_constraint_variable
    begin
      if @current_token.nil? || @current_token.type != :IDENTIFIER
        return nil # Signal error to caller
      end
      
      # Start with base identifier
      base = @current_token.value
      eat(:IDENTIFIER)
      
      # Check for dot notation
      if @current_token&.type == :DOT
        # Build dotted expression string (keep as string for dotted expressions)
        result = base
        while @current_token&.type == :DOT
          eat(:DOT)
          
          if @current_token.nil? || @current_token.type != :IDENTIFIER
            return nil # Signal error to caller
          end
          
          field = @current_token.value
          eat(:IDENTIFIER)
          result += ".#{field}"
        end
        return result
      else
        # Return symbol for simple variable names
        return base.to_sym
      end
    rescue ParseError => e
      nil # Signal error to caller
    end
  end

  # Parse goal declaration: goal find_answer { postcondition: answer > 0 }
  def parse_goal
    begin
      eat(:GOAL)
      
      if @current_token.nil? || @current_token.type != :IDENTIFIER
        return safe_error("Expected goal name after 'goal'")
      end
      
      goal_name = @current_token.value
      eat(:IDENTIFIER)
      
      parameters = []
      if @current_token&.type == :LPAREN
        eat(:LPAREN)
        while @current_token&.type != :RPAREN
          if @current_token.nil?
            return safe_error("Incomplete goal parameters - missing closing parenthesis")
          end
          
          if @current_token.type == :IDENTIFIER
            parameters << @current_token.value
            eat(:IDENTIFIER)
            if @current_token&.type == :COMMA
              eat(:COMMA)
            end
          else
            break
          end
        end
        
        if @current_token&.type == :RPAREN
          eat(:RPAREN)
        else
          return safe_error("Missing closing parenthesis in goal parameters")
        end
      end
      
      # Initialize goal attributes matching GoalNode constructor
      preconditions = []
      postconditions = []
      strategies = []
      
      if @current_token&.type == :LBRACE
        eat(:LBRACE)
        
        while @current_token&.type != :RBRACE
          if @current_token.nil?
            return safe_error("Incomplete goal body - missing closing brace")
          end
          
          case @current_token.type
          when :PRECONDITION
            eat(:PRECONDITION)
            if safe_eat(:COLON)
              precondition_expr = expression
              preconditions << precondition_expr if precondition_expr
            else
              return safe_error("Expected ':' after precondition")
            end
          when :POSTCONDITION
            eat(:POSTCONDITION)
            if safe_eat(:COLON)
              postcondition_expr = expression
              postconditions << postcondition_expr if postcondition_expr
            else
              return safe_error("Expected ':' after postcondition")
            end
          when :STRATEGY
            eat(:STRATEGY)
            if safe_eat(:COLON) && @current_token&.type == :IDENTIFIER
              strategies << @current_token.value.to_sym
              eat(:IDENTIFIER)
            else
              return safe_error("Expected strategy name after 'strategy:'")
            end
          when :IDENTIFIER
            # Handle keywords as identifiers for extended goal syntax
            keyword = @current_token.value.to_s
            eat(:IDENTIFIER)
            
            if !safe_eat(:COLON)
              return safe_error("Expected ':' after goal keyword '#{keyword}'")
            end
            
            case keyword
            when "strategies"
              if @current_token&.type == :LBRACKET
                parsed_strategies = parse_array_literal || []
                strategies.concat(parsed_strategies)
              elsif @current_token&.type == :STRING
                strategies << @current_token.value.to_sym
                eat(:STRING)
              else
                return safe_error("Expected array or string for strategies")
              end
            else
              # Skip unknown keywords gracefully
              expression # Parse and ignore unknown expressions
            end
          else
            break
          end
          
          if @current_token&.type == :COMMA
            eat(:COMMA)
          end
        end
        
        if @current_token&.type == :RBRACE
          eat(:RBRACE)
        else
          return safe_error("Missing closing brace in goal body")
        end
      end
      
      # Create GoalNode with description as first parameter to match constructor
      GoalNode.new(goal_name, preconditions, postconditions, strategies)
    rescue ParseError => e
      safe_error("Goal parse error: #{e.message}")
    end
  end

  # Helper method to parse array literals like [item1, item2, item3]
  def parse_array_literal
    begin
      array = []
      eat(:LBRACKET)
      
      while @current_token&.type != :RBRACKET
        if @current_token.nil?
          return nil # Signal error to caller
        end
        
        if @current_token.type == :IDENTIFIER
          array << @current_token.value.to_sym
          eat(:IDENTIFIER)
        elsif @current_token.type == :STRING
          array << @current_token.value
          eat(:STRING)
        else
          return nil # Signal error to caller
        end
        
        if @current_token&.type == :COMMA
          eat(:COMMA)
        end
      end
      
      if @current_token&.type == :RBRACKET
        eat(:RBRACKET)
      else
        return nil # Signal error to caller
      end
      
      array
    rescue ParseError => e
      nil # Signal error to caller
    end
  end

  # Helper method to parse hash literals like {key: value, key2: value2}
  def parse_hash_literal
    begin
      hash = {}
      eat(:LBRACE)
      
      while @current_token&.type != :RBRACE
        if @current_token.nil?
          return nil # Signal error to caller
        end
        
        # Parse key
        if @current_token.type == :IDENTIFIER
          key = @current_token.value
          eat(:IDENTIFIER)
        else
          return nil # Signal error to caller
        end
        
        if !safe_eat(:COLON)
          return nil # Signal error to caller
        end
        
        # Parse value
        if @current_token&.type == :STRING
          value = @current_token.value
          eat(:STRING)
        elsif @current_token&.type == :IDENTIFIER
          value = @current_token.value
          eat(:IDENTIFIER)
        else
          return nil # Signal error to caller
        end
        
        hash[key.to_sym] = value
        
        if @current_token&.type == :COMMA
          eat(:COMMA)
        end
      end
      
      if @current_token&.type == :RBRACE
        eat(:RBRACE)
      else
        return nil # Signal error to caller
      end
      
      hash
    rescue ParseError => e
      nil # Signal error to caller
    end
  end

  # Parse assert statement: assert fact(likes(alice, bob))
  def parse_assert
    begin
      eat(:ASSERT)
      
      if @current_token.nil?
        return safe_error("Expected expression after 'assert'")
      end
      
      fact = expression
      AssertNode.new(fact || safe_error("Missing assertion expression"))
    rescue ParseError => e
      safe_error("Assert parse error: #{e.message}")
    end
  end

  # Parse query: query likes(X, bob)
  def parse_query
    begin
      eat(:QUERY)
      
      if @current_token.nil?
        return safe_error("Expected pattern after 'query'")
      end
      
      pattern = expression
      QueryNode.new(pattern || safe_error("Missing query pattern"))
    rescue ParseError => e
      safe_error("Query parse error: #{e.message}")
    end
  end

  # Parse rule definition: rule head if body OR rule head :- body
  def parse_rule
    begin
      eat(:RULE)
      
      if @current_token.nil?
        return safe_error("Expected rule head after 'rule'")
      end
      
      head = expression
      
      # Support both "if" and ":-" syntax
      if @current_token&.type == :IF
        eat(:IF)
        
        if @current_token.nil?
          return safe_error("Expected rule body after 'if'")
        end
        
        body = expression
        LogicRuleNode.new(head || safe_error("Missing rule head"), body || safe_error("Missing rule body"))
      elsif @current_token&.type == :COLON && peek(1)&.type == :MINUS
        eat(:COLON)
        eat(:MINUS)
        
        if @current_token.nil?
          return safe_error("Expected rule body after ':-'")
        end
        
        body = expression
        LogicRuleNode.new(head || safe_error("Missing rule head"), body || safe_error("Missing rule body"))
      else
        safe_error("Expected 'if' or ':-' after rule head")
      end
    rescue ParseError => e
      safe_error("Rule parse error: #{e.message}")
    end
  end

  # Parse pursue statement: pursue find_answer
  def parse_pursue
    begin
      eat(:PURSUE)
      
      if @current_token.nil? || @current_token.type != :IDENTIFIER
        return safe_error("Expected goal name after 'pursue'")
      end
      
      goal_name = @current_token.value
      eat(:IDENTIFIER)
      
      arguments = []
      if @current_token&.type == :LPAREN
        eat(:LPAREN)
        while @current_token&.type != :RPAREN
          if @current_token.nil?
            return safe_error("Incomplete pursue arguments - missing closing parenthesis")
          end
          
          arg = expression
          arguments << arg if arg
          
          if @current_token&.type == :COMMA
            eat(:COMMA)
          end
        end
        
        if @current_token&.type == :RPAREN
          eat(:RPAREN)
        else
          return safe_error("Missing closing parenthesis in pursue arguments")
        end
      end
      
      PursueNode.new(goal_name, arguments)
    rescue ParseError => e
      safe_error("Pursue parse error: #{e.message}")
    end
  end

  # Parse Prolog-style query: ?- parent(john, mary)
  def parse_prolog_query
    begin
      eat(:QUERY_PREFIX)
      
      if @current_token.nil?
        return safe_error("Expected query pattern after '?-'")
      end
      
      goal_term = expression
      
      # Extract variables from the goal term (simplified - just look for uppercase identifiers)
      variables = extract_variables_from_expression(goal_term)
      
      QueryNode.new(goal_term || safe_error("Missing query pattern"), variables, :prolog)
    rescue ParseError => e
      safe_error("Prolog query parse error: #{e.message}")
    end
  end

  # Parse fact declaration: fact parent(john, mary)
  def parse_fact
    begin
      eat(:FACT)
      
      if @current_token.nil?
        return safe_error("Expected fact expression after 'fact'")
      end
      
      fact_expr = expression
      
      # Create a LogicRuleNode with no body (facts are rules without conditions)
      LogicRuleNode.new(fact_expr || safe_error("Missing fact expression"), nil, :fact)
    rescue ParseError => e
      safe_error("Fact parse error: #{e.message}")
    end
  end

  private

  # Helper method to extract variables from expressions (simplified implementation)
  def extract_variables_from_expression(expr)
    variables = []
    
    case expr
    when VariableNode
      # Check if variable name starts with uppercase (Prolog convention)
      if expr.name =~ /^[A-Z]/
        variables << expr.name.to_sym
      end
    when FunctionCallNode
      # Extract variables from function arguments
      expr.arguments.each do |arg|
        variables.concat(extract_variables_from_expression(arg))
      end
    when BinaryOpNode
      # Extract variables from both sides
      variables.concat(extract_variables_from_expression(expr.left))
      variables.concat(extract_variables_from_expression(expr.right))
    end
    
    variables.uniq
  end
end
# Parser constants
STATEMENT_KEYWORDS = %w[def if while for class module].freeze
EXPRESSION_KEYWORDS = %w[true false nil].freeze
OPERATORS = %w[+ - * / % == != < > <= >= && || !].freeze
