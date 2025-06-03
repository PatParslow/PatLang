require_relative '../ast_nodes'

# String evaluation module for handling string operations and methods
module EvaluatorModules
  class StringEvaluator
    def initialize(evaluator)
      @evaluator = evaluator
    end

    def visit_string_node(node)
      node.value
    end

    def visit_index_access_node(node)
      object_value = @evaluator.evaluate(node.object)
      index_value = @evaluator.evaluate(node.index)

      unless object_value.is_a?(String)
        raise "Index access is only supported for strings, got #{object_value.class}"
      end

      unless index_value.is_a?(Numeric)
        raise "String index must be a number, got #{index_value.class}"
      end

      # Convert to integer (check if it's a whole number)
      if index_value.is_a?(Float) && index_value != index_value.to_i
        raise "String index must be an integer, got #{index_value.class}"
      end
      
      index_value = index_value.to_i

      # Convert from 1-based to 0-based indexing
      zero_based_index = index_value - 1

      # Support negative indexing (from end, still 1-based: -1 is last character)
      if index_value < 0
        zero_based_index = object_value.length + index_value
      end

      # Bounds checking (1-based indexing)
      if index_value == 0 || zero_based_index < 0 || zero_based_index >= object_value.length
        raise "String index #{index_value} out of bounds for string of length #{object_value.length} (1-based indexing)"
      end

      object_value[zero_based_index]
    end

    def visit_method_call_node(node)
      object_value = @evaluator.evaluate(node.object)

      if object_value.is_a?(String)
        handle_string_method(object_value, node)
      elsif object_value.is_a?(Numeric)
        handle_number_method(object_value, node)
      else
        raise "Method calls are only supported for strings and numbers, got #{object_value.class}"
      end
    end

    private

    def handle_string_method(object_value, node)
      case node.method_name
      when 'length'
        if node.arguments.length != 0
          raise "String.length method takes no arguments, got #{node.arguments.length}"
        end
        object_value.length
      when 'substring'
        if node.arguments.length != 2
          raise "String.substring method takes 2 arguments (start, length), got #{node.arguments.length}"
        end
        start_arg = @evaluator.evaluate(node.arguments[0])
        length_arg = @evaluator.evaluate(node.arguments[1])
        
        unless start_arg.is_a?(Numeric)
          raise "String.substring start must be a number, got #{start_arg.class}"
        end
        unless length_arg.is_a?(Numeric)
          raise "String.substring length must be a number, got #{length_arg.class}"
        end

        # Convert to integer (check if they're whole numbers)
        if start_arg.is_a?(Float) && start_arg != start_arg.to_i
          raise "String.substring start must be an integer, got #{start_arg.class}"
        end
        if length_arg.is_a?(Float) && length_arg != length_arg.to_i
          raise "String.substring length must be an integer, got #{length_arg.class}"
        end
        
        start_arg = start_arg.to_i
        length_arg = length_arg.to_i
        
        # Handle empty string case
        if object_value.length == 0
          if start_arg == 1 && length_arg >= 0
            return ""
          else
            raise "String.substring start index #{start_arg} out of bounds for string of length #{object_value.length} (1-based indexing)"
          end
        end
        
        # Convert from 1-based to 0-based indexing for start
        zero_based_start = start_arg < 0 ? object_value.length + start_arg : start_arg - 1
        
        # Bounds checking (1-based indexing)
        if start_arg == 0 || zero_based_start < 0 || zero_based_start >= object_value.length
          raise "String.substring start index #{start_arg} out of bounds for string of length #{object_value.length} (1-based indexing)"
        end
        
        if length_arg < 0
          raise "String.substring length must be non-negative, got #{length_arg}"
        end
        
        # Extract substring with bounds checking
        end_index = zero_based_start + length_arg
        if end_index > object_value.length
          end_index = object_value.length
        end
        
        object_value[zero_based_start...end_index]
      when 'starts_with'
        if node.arguments.length != 1
          raise "String.starts_with method takes 1 argument (prefix), got #{node.arguments.length}"
        end
        prefix_arg = @evaluator.evaluate(node.arguments[0])
        
        unless prefix_arg.is_a?(String)
          raise "String.starts_with prefix must be a string, got #{prefix_arg.class}"
        end
        
        object_value.start_with?(prefix_arg)
      when 'ends_with'
        if node.arguments.length != 1
          raise "String.ends_with method takes 1 argument (suffix), got #{node.arguments.length}"
        end
        suffix_arg = @evaluator.evaluate(node.arguments[0])
        
        unless suffix_arg.is_a?(String)
          raise "String.ends_with suffix must be a string, got #{suffix_arg.class}"
        end
        
        object_value.end_with?(suffix_arg)
      when 'uppercase'
        if node.arguments.length != 0
          raise "String.uppercase method takes no arguments, got #{node.arguments.length}"
        end
        object_value.upcase
      when 'lowercase'
        if node.arguments.length != 0
          raise "String.lowercase method takes no arguments, got #{node.arguments.length}"
        end
        object_value.downcase
      when 'trim'
        if node.arguments.length != 0
          raise "String.trim method takes no arguments, got #{node.arguments.length}"
        end
        object_value.strip
      else
        raise "Unknown string method: #{node.method_name}"
      end
    end

    def handle_number_method(object_value, node)
      case node.method_name
      when 'length'
        if node.arguments.length != 0
          raise "Number.length method takes no arguments, got #{node.arguments.length}"
        end
        # Return the length of the string representation of the number
        object_value.to_s.length
      else
        raise "Unknown number method: #{node.method_name}"
      end
    end
  end
end