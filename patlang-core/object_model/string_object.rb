require_relative 'patlang_object'

# StringObject - Specialized object for string values with string operations
# 
# This class extends PatlangObject to provide string-specific behavior including
# string operations as methods with full event system integration.
class StringObject < PatlangObject
  
  def initialize(value)
    super(value.to_s, :string)
  end
  
  # String operations as object methods with events
  def concatenate(other)
    other_value = extract_string_value(other)
    result_value = @raw_value + other_value
    
    # Fire string operation event
    event_data = {
      operation: :concatenate,
      left_operand: @raw_value,
      right_operand: other_value,
      result: result_value,
      left_object_id: @object_id,
      right_object_id: other.is_a?(PatlangObject) ? other.object_id : nil,
      timestamp: Time.now
    }
    fire_event(:string_operation, event_data)
    EventSystem.fire_global_event(:string_operation, event_data)
    
    StringObject.new(result_value)
  end
  
  def repeat(times)
    times_value = times.is_a?(Numeric) ? times : times.to_i
    
    if times_value < 0
      fire_event(:string_error, {
        operation: :repeat,
        error: :negative_repetition,
        operand: @raw_value,
        times: times_value,
        object_id: @object_id,
        timestamp: Time.now
      })
      raise "Cannot repeat string negative times"
    end
    
    result_value = @raw_value * times_value
    
    event_data = {
      operation: :repeat,
      operand: @raw_value,
      times: times_value,
      result: result_value,
      object_id: @object_id,
      timestamp: Time.now
    }
    fire_event(:string_operation, event_data)
    EventSystem.fire_global_event(:string_operation, event_data)
    
    StringObject.new(result_value)
  end
  
  def substring(start_index, length = nil)
    start_idx = start_index.is_a?(Numeric) ? start_index.to_i : start_index.to_i
    
    if start_idx < 0 || start_idx >= @raw_value.length
      fire_event(:string_error, {
        operation: :substring,
        error: :index_out_of_bounds,
        operand: @raw_value,
        start_index: start_idx,
        length: length,
        object_id: @object_id,
        timestamp: Time.now
      })
      raise "String index out of bounds"
    end
    
    if length.nil?
      result_value = @raw_value[start_idx..-1]
    else
      len = length.is_a?(Numeric) ? length.to_i : length.to_i
      result_value = @raw_value[start_idx, len]
    end
    
    fire_event(:string_operation, {
      operation: :substring,
      operand: @raw_value,
      start_index: start_idx,
      length: length,
      result: result_value,
      object_id: @object_id,
      timestamp: Time.now
    })
    
    StringObject.new(result_value || "")
  end
  
  def char_at(index)
    idx = index.is_a?(Numeric) ? index.to_i : index.to_i
    
    if idx < 0 || idx >= @raw_value.length
      fire_event(:string_error, {
        operation: :char_at,
        error: :index_out_of_bounds,
        operand: @raw_value,
        index: idx,
        object_id: @object_id,
        timestamp: Time.now
      })
      raise "String index out of bounds"
    end
    
    result_value = @raw_value[idx]
    
    fire_event(:string_operation, {
      operation: :char_at,
      operand: @raw_value,
      index: idx,
      result: result_value,
      object_id: @object_id,
      timestamp: Time.now
    })
    
    StringObject.new(result_value)
  end
  
  def length
    result_value = @raw_value.length
    
    fire_event(:string_operation, {
      operation: :length,
      operand: @raw_value,
      result: result_value,
      object_id: @object_id,
      timestamp: Time.now
    })
    
    PatlangObject.create_number(result_value)
  end
  
  def upcase
    result_value = @raw_value.upcase
    
    fire_event(:string_operation, {
      operation: :upcase,
      operand: @raw_value,
      result: result_value,
      object_id: @object_id,
      timestamp: Time.now
    })
    
    StringObject.new(result_value)
  end
  
  def downcase
    result_value = @raw_value.downcase
    
    fire_event(:string_operation, {
      operation: :downcase,
      operand: @raw_value,
      result: result_value,
      object_id: @object_id,
      timestamp: Time.now
    })
    
    StringObject.new(result_value)
  end
  
  def strip
    result_value = @raw_value.strip
    
    fire_event(:string_operation, {
      operation: :strip,
      operand: @raw_value,
      result: result_value,
      object_id: @object_id,
      timestamp: Time.now
    })
    
    StringObject.new(result_value)
  end
  
  def reverse
    result_value = @raw_value.reverse
    
    fire_event(:string_operation, {
      operation: :reverse,
      operand: @raw_value,
      result: result_value,
      object_id: @object_id,
      timestamp: Time.now
    })
    
    StringObject.new(result_value)
  end
  
  # String comparison operations
  def equals(other)
    other_value = extract_string_value(other)
    result_value = @raw_value == other_value
    
    fire_event(:comparison_operation, {
      operation: :equals,
      left_operand: @raw_value,
      right_operand: other_value,
      result: result_value,
      left_object_id: @object_id,
      right_object_id: other.is_a?(PatlangObject) ? other.object_id : nil,
      timestamp: Time.now
    })
    
    PatlangObject.create_boolean(result_value)
  end
  
  def contains(substring)
    substring_value = extract_string_value(substring)
    result_value = @raw_value.include?(substring_value)
    
    fire_event(:string_operation, {
      operation: :contains,
      operand: @raw_value,
      substring: substring_value,
      result: result_value,
      object_id: @object_id,
      timestamp: Time.now
    })
    
    PatlangObject.create_boolean(result_value)
  end
  
  def starts_with(prefix)
    prefix_value = extract_string_value(prefix)
    result_value = @raw_value.start_with?(prefix_value)
    
    fire_event(:string_operation, {
      operation: :starts_with,
      operand: @raw_value,
      prefix: prefix_value,
      result: result_value,
      object_id: @object_id,
      timestamp: Time.now
    })
    
    PatlangObject.create_boolean(result_value)
  end
  
  def ends_with(suffix)
    suffix_value = extract_string_value(suffix)
    result_value = @raw_value.end_with?(suffix_value)
    
    fire_event(:string_operation, {
      operation: :ends_with,
      operand: @raw_value,
      suffix: suffix_value,
      result: result_value,
      object_id: @object_id,
      timestamp: Time.now
    })
    
    PatlangObject.create_boolean(result_value)
  end
  
  def split(delimiter = " ")
    delimiter_value = extract_string_value(delimiter)
    result_array = @raw_value.split(delimiter_value)
    
    fire_event(:string_operation, {
      operation: :split,
      operand: @raw_value,
      delimiter: delimiter_value,
      result: result_array,
      object_id: @object_id,
      timestamp: Time.now
    })
    
    # Return array of StringObjects
    result_array.map { |str| StringObject.new(str) }
  end
  
  # Convenience methods for common operations
  def +(other)
    concatenate(other)
  end
  
  def *(times)
    repeat(times)
  end
  
  def [](index, length = nil)
    if length.nil?
      char_at(index)
    else
      substring(index, length)
    end
  end
  
  def ==(other)
    if other.is_a?(StringObject)
      @raw_value == other.raw_value
    elsif other.is_a?(String)
      @raw_value == other
    else
      false
    end
  end
  
  def include?(substring)
    contains(substring).raw_value
  end
  
  def start_with?(prefix)
    starts_with(prefix).raw_value
  end
  
  def end_with?(suffix)
    ends_with(suffix).raw_value
  end
  
  def size
    length
  end
  
  # String representation
  def to_s
    @raw_value
  end
  
  def inspect
    "StringObject(id=#{@object_id}, value=#{@raw_value.inspect})"
  end
  
  # Convert to number if possible
  def to_number
    begin
      result = Float(@raw_value)
      fire_event(:type_conversion, {
        operation: :string_to_number,
        operand: @raw_value,
        result: result,
        object_id: @object_id,
        timestamp: Time.now
      })
      result
    rescue ArgumentError
      fire_event(:conversion_error, {
        operation: :string_to_number,
        error: :invalid_number_format,
        operand: @raw_value,
        object_id: @object_id,
        timestamp: Time.now
      })
      raise "Cannot convert string '#{@raw_value}' to number"
    end
  end
  
  # Convert to boolean (empty string is false, non-empty is true)
  def to_boolean
    result = !@raw_value.empty?
    
    fire_event(:type_conversion, {
      operation: :string_to_boolean,
      operand: @raw_value,
      result: result,
      object_id: @object_id,
      timestamp: Time.now
    })
    
    result
  end
  
  private
  
  def extract_string_value(other)
    case other
    when StringObject
      other.raw_value
    when String
      other
    when PatlangObject
      other.to_string
    else
      other.to_s
    end
  end
end