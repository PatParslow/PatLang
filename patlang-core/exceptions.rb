# Patlang-specific exception classes for proper error handling

# Base exception for all Patlang errors
class PatlangError < StandardError
  attr_reader :original_error, :context

  def initialize(message, original_error: nil, context: {})
    super(message)
    @original_error = original_error
    @context = context
  end

  def simple_message
    @message || message
  end

  def detailed_message
    base = simple_message
    context_parts = []
    context_parts << "operator: #{@context[:operator]}" if @context[:operator]
    context_parts << "left: #{@context[:left_operand]}" if @context[:left_operand]
    context_parts << "right: #{@context[:right_operand]}" if @context[:right_operand]
    context_parts << "function: #{@context[:function]}" if @context[:function]
    context_parts << "at #{@context[:location]}" if @context[:location]
    context_parts << "operation: #{@context[:operation]}" if @context[:operation]
    
    context_parts.empty? ? base : "#{base} (#{context_parts.join(', ')})"
  end

  def to_s
    simple_message  # Default to user-friendly message
  end
end

# Parse-related errors
class ParseError < PatlangError
  attr_reader :line, :column, :position, :token

  def initialize(message, line: nil, column: nil, position: nil, token: nil, **kwargs)
    super(message, **kwargs)
    @line = line
    @column = column
    @position = position
    @token = token
  end

  def to_s
    if @line && @column
      "#{super} at line #{@line}, column #{@column}"
    elsif @position
      "#{super} at position #{@position}"
    else
      location = []
      location << "line #{@line}" if @line
      location << "column #{@column}" if @column
      location_str = location.empty? ? "" : " at #{location.join(', ')}"
      "#{super}#{location_str}"
    end
  end
end

# Logic programming errors
class LogicError < PatlangError
end

# Type constraint violations
class TypeConstraintViolation < PatlangError
  attr_reader :variable, :value, :constraint

  def initialize(variable, value, message, constraint: nil, **kwargs)
    @variable = variable
    @value = value
    @constraint = constraint
    super("Variable #{variable}: #{message}", **kwargs)
  end
end

# Reasoning mode errors
class ReasoningModeError < PatlangError
  def initialize(message = "Reasoning mode not enabled")
    super(message)
  end
end

# Goal resolution errors
class GoalResolutionError < PatlangError
end

# Query execution errors
class QueryError < LogicError
end

# Unification errors
class UnificationError < LogicError
end

# Runtime errors - general execution failures
class PatlangRuntimeError < PatlangError
  attr_reader :operation, :execution_context, :function_name, :line_number

  def initialize(message, operation: nil, execution_context: {}, function_name: nil, line_number: nil, **kwargs)
    @operation = operation
    @execution_context = execution_context
    @function_name = function_name
    @line_number = line_number
    
    # Add runtime context to base context
    runtime_context = kwargs[:context] || {}
    runtime_context[:operation] = operation if operation
    runtime_context[:function] = function_name if function_name
    runtime_context[:line] = line_number if line_number
    
    super(message, context: runtime_context, **kwargs)
  end
end

# Arithmetic errors - mathematical operation failures
class PatlangArithmeticError < PatlangError
  attr_reader :operator, :left_operand, :right_operand, :operation_type

  def initialize(message, operator: nil, left_operand: nil, right_operand: nil, operation_type: nil, **kwargs)
    @operator = operator
    @left_operand = left_operand
    @right_operand = right_operand
    @operation_type = operation_type
    
    # Add arithmetic context to base context
    arithmetic_context = kwargs[:context] || {}
    arithmetic_context[:operator] = operator if operator
    arithmetic_context[:left_operand] = left_operand unless left_operand.nil?
    arithmetic_context[:right_operand] = right_operand unless right_operand.nil?
    arithmetic_context[:operation_type] = operation_type if operation_type
    
    super(message, context: arithmetic_context, **kwargs)
  end

  def validate_operands
    return false if @left_operand.nil? || @right_operand.nil?
    return false unless @left_operand.is_a?(Numeric) && @right_operand.is_a?(Numeric)
    true
  end
end

# Division by zero - specific arithmetic error
class PatlangDivisionByZeroError < PatlangArithmeticError
  attr_reader :dividend

  def initialize(message = "Division by zero", dividend: nil, **kwargs)
    @dividend = dividend
    
    # Set default operator context if not provided
    kwargs[:operator] ||= "/"
    kwargs[:left_operand] ||= dividend if dividend
    kwargs[:right_operand] ||= 0
    
    super(message, **kwargs)
  end

  def validate_division
    !@right_operand.nil? && @right_operand == 0
  end
end

# Function errors - function-specific issues
class PatlangFunctionError < PatlangError
  attr_reader :function_name, :arguments, :function_context, :expected_params, :actual_params

  def initialize(message, function_name: nil, arguments: nil, function_context: {}, expected_params: nil, actual_params: nil, **kwargs)
    @function_name = function_name
    @arguments = arguments
    @function_context = function_context
    @expected_params = expected_params
    @actual_params = actual_params
    
    # Add function context to base context
    func_context = kwargs[:context] || {}
    func_context[:function] = function_name if function_name
    func_context[:expected_params] = expected_params if expected_params
    func_context[:actual_params] = actual_params if actual_params
    func_context[:arguments] = arguments&.map(&:class)&.join(', ') if arguments
    
    super(message, context: func_context, **kwargs)
  end
end

# Type errors - type-related violations
class PatlangTypeError < PatlangError
  attr_reader :expected_type, :actual_type, :value, :conversion_attempted

  def initialize(message, expected_type: nil, actual_type: nil, value: nil, conversion_attempted: nil, **kwargs)
    @expected_type = expected_type
    @actual_type = actual_type
    @value = value
    @conversion_attempted = conversion_attempted
    
    # Add type context to base context
    type_context = kwargs[:context] || {}
    type_context[:expected_type] = expected_type if expected_type
    type_context[:actual_type] = actual_type if actual_type
    type_context[:value] = value unless value.nil?
    type_context[:conversion_attempted] = conversion_attempted if conversion_attempted
    
    super(message, context: type_context, **kwargs)
  end
end

# Index errors - collection access issues
class PatlangIndexError < PatlangError
  attr_reader :index, :collection_size, :collection_type, :zero_based

  def initialize(message, index: nil, collection_size: nil, collection_type: nil, zero_based: false, **kwargs)
    @index = index
    @collection_size = collection_size
    @collection_type = collection_type
    @zero_based = zero_based
    
    # Add index context to base context
    index_context = kwargs[:context] || {}
    index_context[:index] = index unless index.nil?
    index_context[:collection_size] = collection_size if collection_size
    index_context[:collection_type] = collection_type if collection_type
    index_context[:zero_based] = zero_based
    
    super(message, context: index_context, **kwargs)
  end
end