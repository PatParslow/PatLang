require_relative 'token'

# AmbiguousToken class for handling tokens with multiple potential interpretations
class AmbiguousToken < Token
  attr_reader :possibilities

  def initialize(possibilities, position = 0, line = 1, column = 1)
    # Use the first possibility as the default type and value for compatibility
    first_possibility = possibilities.first
    super(first_possibility[:type], first_possibility[:value], position, line, column)
    
    @possibilities = possibilities
  end

  # Resolve to a specific token type if it matches one of the possibilities
  def resolve_to(target_type)
    possibility = @possibilities.find { |p| p[:type] == target_type }
    if possibility
      Token.new(possibility[:type], possibility[:value], @position, @line, @column)
    else
      nil
    end
  end

  # Get all possible token types
  def possible_types
    @possibilities.map { |p| p[:type] }
  end

  # Check if a specific type is a possibility
  def can_be?(token_type)
    possible_types.include?(token_type)
  end

  # Override to_s to show ambiguity
  def to_s
    types = @possibilities.map { |p| "#{p[:type]}(#{p[:value]})" }.join(', ')
    "AmbiguousToken[#{types}]"
  end

  def inspect
    to_s
  end

  # Check if this is an ambiguous token (for compatibility)
  def ambiguous?
    true
  end
end

# Add method to regular Token class for compatibility
class Token
  def ambiguous?
    false
  end
end