# Patlang-specific exception classes for proper error handling

# Base exception for all Patlang errors
class PatlangError < StandardError
  attr_reader :original_error, :context

  def initialize(message, original_error: nil, context: {})
    super(message)
    @original_error = original_error
    @context = context
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

# Division by zero (inherit from standard ZeroDivisionError)
class PatlangZeroDivisionError < ZeroDivisionError
end