require_relative 'patlang_object'
require_relative 'event_system'
require_relative '../exceptions'

# NumberObject - Specialized object for numeric values with arithmetic operations
# 
# This class extends PatlangObject to provide number-specific behavior including
# arithmetic operations as methods with full event system integration.
class NumberObject < PatlangObject
  
  def initialize(value)
    super(value.to_f, :number)
  end
  
  # Arithmetic operations as object methods with events
  def add(other)
    other_value = extract_numeric_value(other)
    result_value = @raw_value + other_value
    
    # Fire arithmetic operation event
    event_data = {
      operation: :add,
      left_operand: @raw_value,
      right_operand: other_value,
      result: result_value,
      left_object_id: @object_id,
      right_object_id: other.is_a?(PatlangObject) ? other.object_id : nil,
      timestamp: Time.now
    }
    fire_event(:arithmetic_operation, event_data)
    EventSystem.fire_global_event(:arithmetic_operation, event_data)
    
    NumberObject.new(result_value)
  end
  
  def subtract(other)
    other_value = extract_numeric_value(other)
    result_value = @raw_value - other_value
    
    event_data = {
      operation: :subtract,
      left_operand: @raw_value,
      right_operand: other_value,
      result: result_value,
      left_object_id: @object_id,
      right_object_id: other.is_a?(PatlangObject) ? other.object_id : nil,
      timestamp: Time.now
    }
    fire_event(:arithmetic_operation, event_data)
    EventSystem.fire_global_event(:arithmetic_operation, event_data)
    
    NumberObject.new(result_value)
  end
  
  def multiply(other)
    other_value = extract_numeric_value(other)
    result_value = @raw_value * other_value
    
    event_data = {
      operation: :multiply,
      left_operand: @raw_value,
      right_operand: other_value,
      result: result_value,
      left_object_id: @object_id,
      right_object_id: other.is_a?(PatlangObject) ? other.object_id : nil,
      timestamp: Time.now
    }
    fire_event(:arithmetic_operation, event_data)
    EventSystem.fire_global_event(:arithmetic_operation, event_data)
    
    NumberObject.new(result_value)
  end
  
  def divide(other)
    other_value = extract_numeric_value(other)
    
    if other_value == 0
      error_data = {
        operation: :divide,
        error: :division_by_zero,
        left_operand: @raw_value,
        right_operand: other_value,
        object_id: @object_id,
        timestamp: Time.now
      }
      fire_event(:arithmetic_error, error_data)
      EventSystem.fire_global_event(:arithmetic_error, error_data)
      raise PatlangDivisionByZeroError.new(
        "Division by zero",
        operator: "/",
        left_operand: @raw_value,
        right_operand: other_value,
        dividend: @raw_value
      )
    end
    
    result_value = @raw_value / other_value
    
    event_data = {
      operation: :divide,
      left_operand: @raw_value,
      right_operand: other_value,
      result: result_value,
      left_object_id: @object_id,
      right_object_id: other.is_a?(PatlangObject) ? other.object_id : nil,
      timestamp: Time.now
    }
    fire_event(:arithmetic_operation, event_data)
    EventSystem.fire_global_event(:arithmetic_operation, event_data)
    
    NumberObject.new(result_value)
  end
  
  def modulo(other)
    other_value = extract_numeric_value(other)
    
    if other_value == 0
      error_data = {
        operation: :modulo,
        error: :division_by_zero,
        left_operand: @raw_value,
        right_operand: other_value,
        object_id: @object_id,
        timestamp: Time.now
      }
      fire_event(:arithmetic_error, error_data)
      EventSystem.fire_global_event(:arithmetic_error, error_data)
      raise "Division by zero in modulo operation"
    end
    
    result_value = @raw_value % other_value
    
    event_data = {
      operation: :modulo,
      left_operand: @raw_value,
      right_operand: other_value,
      result: result_value,
      left_object_id: @object_id,
      right_object_id: other.is_a?(PatlangObject) ? other.object_id : nil,
      timestamp: Time.now
    }
    fire_event(:arithmetic_operation, event_data)
    EventSystem.fire_global_event(:arithmetic_operation, event_data)
    
    NumberObject.new(result_value)
  end
  
  def power(other)
    other_value = extract_numeric_value(other)
    result_value = @raw_value ** other_value
    
    event_data = {
      operation: :power,
      left_operand: @raw_value,
      right_operand: other_value,
      result: result_value,
      left_object_id: @object_id,
      right_object_id: other.is_a?(PatlangObject) ? other.object_id : nil,
      timestamp: Time.now
    }
    fire_event(:arithmetic_operation, event_data)
    EventSystem.fire_global_event(:arithmetic_operation, event_data)
    
    NumberObject.new(result_value)
  end
  
  # Unary operations
  def negate
    result_value = -@raw_value
    
    event_data = {
      operation: :negate,
      operand: @raw_value,
      result: result_value,
      object_id: @object_id,
      timestamp: Time.now
    }
    fire_event(:unary_operation, event_data)
    EventSystem.fire_global_event(:unary_operation, event_data)
    
    NumberObject.new(result_value)
  end
  
  def absolute
    result_value = @raw_value.abs
    
    fire_event(:unary_operation, {
      operation: :absolute,
      operand: @raw_value,
      result: result_value,
      object_id: @object_id,
      timestamp: Time.now
    })
    
    NumberObject.new(result_value)
  end
  
  # Comparison operations
  def equals(other)
    other_value = extract_numeric_value(other)
    result_value = @raw_value == other_value
    
    event_data = {
      operation: :equals,
      left_operand: @raw_value,
      right_operand: other_value,
      result: result_value,
      left_object_id: @object_id,
      right_object_id: other.is_a?(PatlangObject) ? other.object_id : nil,
      timestamp: Time.now
    }
    fire_event(:comparison_operation, event_data)
    EventSystem.fire_global_event(:comparison_operation, event_data)
    
    PatlangObject.create_boolean(result_value)
  end
  
  def less_than(other)
    other_value = extract_numeric_value(other)
    result_value = @raw_value < other_value
    
    event_data = {
      operation: :less_than,
      left_operand: @raw_value,
      right_operand: other_value,
      result: result_value,
      left_object_id: @object_id,
      right_object_id: other.is_a?(PatlangObject) ? other.object_id : nil,
      timestamp: Time.now
    }
    fire_event(:comparison_operation, event_data)
    EventSystem.fire_global_event(:comparison_operation, event_data)
    
    PatlangObject.create_boolean(result_value)
  end
  
  def greater_than(other)
    other_value = extract_numeric_value(other)
    result_value = @raw_value > other_value
    
    fire_event(:comparison_operation, {
      operation: :greater_than,
      left_operand: @raw_value,
      right_operand: other_value,
      result: result_value,
      left_object_id: @object_id,
      right_object_id: other.is_a?(PatlangObject) ? other.object_id : nil,
      timestamp: Time.now
    })
    
    PatlangObject.create_boolean(result_value)
  end
  
  def less_than_or_equal(other)
    other_value = extract_numeric_value(other)
    result_value = @raw_value <= other_value
    
    fire_event(:comparison_operation, {
      operation: :less_than_or_equal,
      left_operand: @raw_value,
      right_operand: other_value,
      result: result_value,
      left_object_id: @object_id,
      right_object_id: other.is_a?(PatlangObject) ? other.object_id : nil,
      timestamp: Time.now
    })
    
    PatlangObject.create_boolean(result_value)
  end
  
  def greater_than_or_equal(other)
    other_value = extract_numeric_value(other)
    result_value = @raw_value >= other_value
    
    fire_event(:comparison_operation, {
      operation: :greater_than_or_equal,
      left_operand: @raw_value,
      right_operand: other_value,
      result: result_value,
      left_object_id: @object_id,
      right_object_id: other.is_a?(PatlangObject) ? other.object_id : nil,
      timestamp: Time.now
    })
    
    PatlangObject.create_boolean(result_value)
  end
  
  # Convenience methods for common operations
  def +(other)
    add(other)
  end
  
  def -(other)
    subtract(other)
  end
  
  def *(other)
    multiply(other)
  end
  
  def /(other)
    divide(other)
  end
  
  def %(other)
    modulo(other)
  end
  
  def **(other)
    power(other)
  end
  
  def -@
    negate
  end
  
  def ==(other)
    if other.is_a?(NumberObject)
      @raw_value == other.raw_value
    elsif other.is_a?(Numeric)
      @raw_value == other
    else
      false
    end
  end
  
  def <(other)
    other_value = extract_numeric_value(other)
    @raw_value < other_value
  end
  
  def >(other)
    other_value = extract_numeric_value(other)
    @raw_value > other_value
  end
  
  def <=(other)
    other_value = extract_numeric_value(other)
    @raw_value <= other_value
  end
  
  def >=(other)
    other_value = extract_numeric_value(other)
    @raw_value >= other_value
  end
  
  # String representation
  def to_s
    # Handle special float values first
    return "NaN" if @raw_value.respond_to?(:nan?) && @raw_value.nan?
    return "Infinity" if @raw_value == Float::INFINITY
    return "-Infinity" if @raw_value == -Float::INFINITY
    
    # Only show decimal places if they're non-zero
    begin
      @raw_value == @raw_value.to_i ? @raw_value.to_i.to_s : @raw_value.to_s
    rescue FloatDomainError
      # Fallback for any other special float cases
      @raw_value.to_s
    end
  end
  
  # String conversion for concatenation - delegate to intelligent to_s
  def to_string
    to_s
  end
  
  def inspect
    "NumberObject(id=#{@object_id}, value=#{@raw_value})"
  end
  
  private
  
  def extract_numeric_value(other)
    case other
    when NumberObject
      other.raw_value
    when Numeric
      other
    when PatlangObject
      other.to_number
    else
      raise ArgumentError, "Cannot perform arithmetic with #{other.class}"
    end
  end
end