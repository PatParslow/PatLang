require_relative '../ast/ast_nodes'
require_relative '../object_model/number_object'
require_relative '../object_model/string_object'
require_relative '../object_model/patlang_object'

# Object-based evaluation module for handling value objects with events
module EvaluatorModules
  class ObjectEvaluator
    attr_accessor :object_mode_enabled
    
    def initialize(evaluator)
      @evaluator = evaluator
      @object_mode_enabled = false  # Dual-mode operation: starts in compatibility mode
    end
    
    def enable_object_mode
      @object_mode_enabled = true
    end
    
    def disable_object_mode
      @object_mode_enabled = false
    end
    
    def visit_number_node(node)
      if @object_mode_enabled
        NumberObject.new(node.value)
      else
        node.value  # Backward compatibility
      end
    end
    
    def visit_string_node(node)
      puts "[DIAGNOSTIC] ObjectEvaluator: visit_string_node called with value=#{node.value.inspect}, object_mode_enabled=#{@object_mode_enabled.inspect}"
      if @object_mode_enabled
        result = StringObject.new(node.value)
      else
        result = node.value  # Backward compatibility
      end
      puts "[DIAGNOSTIC] ObjectEvaluator: returning #{result.inspect}"
      result
    end
    
    def visit_binary_op_node(node)
      left_value = @evaluator.evaluate(node.left)
      right_value = @evaluator.evaluate(node.right)
      
      if @object_mode_enabled
        # Object-based arithmetic with events
        perform_object_binary_operation(left_value, right_value, node.operator)
      else
        # Legacy arithmetic evaluation for backward compatibility
        perform_legacy_binary_operation(left_value, right_value, node.operator)
      end
    end
    
    def visit_unary_op_node(node)
      operand_value = @evaluator.evaluate(node.operand)
      
      if @object_mode_enabled
        # Object-based unary operations with events
        perform_object_unary_operation(operand_value, node.operator)
      else
        # Legacy unary evaluation for backward compatibility
        perform_legacy_unary_operation(operand_value, node.operator)
      end
    end
    
    def visit_comparison_node(node)
      left_value = @evaluator.evaluate(node.left)
      right_value = @evaluator.evaluate(node.right)
      
      if @object_mode_enabled
        # Object-based comparison with events
        perform_object_comparison(left_value, right_value, node.operator)
      else
        # Legacy comparison evaluation
        perform_legacy_comparison(left_value, right_value, node.operator)
      end
    end
    
    def visit_boolean_node(node)
      if @object_mode_enabled
        PatlangObject.create_boolean(node.value)
      else
        node.value  # Backward compatibility
      end
    end
    
    private
    
    def perform_object_binary_operation(left_value, right_value, operator)
      # Ensure values are wrapped as objects
      left_obj = ensure_object(left_value)
      right_obj = ensure_object(right_value)
      
      # Handle both symbol and string operators
      operator = operator.to_s.downcase
      
      case operator
      when '+', 'plus'
        if left_obj.is_a?(StringObject) || right_obj.is_a?(StringObject)
          # String concatenation - convert both to strings
          left_str = left_obj.is_a?(StringObject) ? left_obj : StringObject.new(left_obj.to_string)
          right_str = right_obj.is_a?(StringObject) ? right_obj : StringObject.new(right_obj.to_string)
          left_str.concatenate(right_str)
        elsif left_obj.is_a?(NumberObject) && right_obj.is_a?(NumberObject)
          left_obj.add(right_obj)
        else
          # Mixed types - try numeric addition
          left_num = ensure_number_object(left_obj)
          right_num = ensure_number_object(right_obj)
          left_num.add(right_num)
        end
      when '-', 'minus'
        left_num = ensure_number_object(left_obj)
        right_num = ensure_number_object(right_obj)
        left_num.subtract(right_num)
      when '*', 'multiply', 'star'
        if left_obj.is_a?(StringObject) && right_obj.is_a?(NumberObject)
          left_obj.repeat(right_obj.raw_value)
        elsif left_obj.is_a?(NumberObject) && right_obj.is_a?(StringObject)
          right_obj.repeat(left_obj.raw_value)
        else
          left_num = ensure_number_object(left_obj)
          right_num = ensure_number_object(right_obj)
          left_num.multiply(right_num)
        end
      when '/', 'divide', 'slash'
        left_num = ensure_number_object(left_obj)
        right_num = ensure_number_object(right_obj)
        left_num.divide(right_num)
      when '%', 'modulo'
        left_num = ensure_number_object(left_obj)
        right_num = ensure_number_object(right_obj)
        left_num.modulo(right_num)
      when '**', 'power'
        left_num = ensure_number_object(left_obj)
        right_num = ensure_number_object(right_obj)
        left_num.power(right_num)
      when '==', 'equal'
        if left_obj.class == right_obj.class
          left_obj.equals(right_obj)
        else
          PatlangObject.create_boolean(left_obj.raw_value == right_obj.raw_value)
        end
      when '!=', 'not_equal'
        result = if left_obj.class == right_obj.class
          left_obj.equals(right_obj)
        else
          PatlangObject.create_boolean(left_obj.raw_value == right_obj.raw_value)
        end
        PatlangObject.create_boolean(!result.raw_value)
      when '<', 'less_than', 'less'
        if left_obj.is_a?(NumberObject) && right_obj.is_a?(NumberObject)
          left_obj.less_than(right_obj)
        else
          left_num = ensure_number_object(left_obj)
          right_num = ensure_number_object(right_obj)
          left_num.less_than(right_num)
        end
      when '>', 'greater_than', 'greater'
        if left_obj.is_a?(NumberObject) && right_obj.is_a?(NumberObject)
          left_obj.greater_than(right_obj)
        else
          left_num = ensure_number_object(left_obj)
          right_num = ensure_number_object(right_obj)
          left_num.greater_than(right_num)
        end
      when '<=', 'less_equal'
        if left_obj.is_a?(NumberObject) && right_obj.is_a?(NumberObject)
          left_obj.less_than_or_equal(right_obj)
        else
          left_num = ensure_number_object(left_obj)
          right_num = ensure_number_object(right_obj)
          left_num.less_than_or_equal(right_num)
        end
      when '>=', 'greater_equal'
        if left_obj.is_a?(NumberObject) && right_obj.is_a?(NumberObject)
          left_obj.greater_than_or_equal(right_obj)
        else
          left_num = ensure_number_object(left_obj)
          right_num = ensure_number_object(right_obj)
          left_num.greater_than_or_equal(right_num)
        end
      else
        raise "Unknown operator: #{operator}"
      end
    end
    
    def perform_object_unary_operation(operand_value, operator)
      operand_obj = ensure_object(operand_value)
      
      case operator.to_s.downcase
      when '-', 'minus'
        operand_num = ensure_number_object(operand_obj)
        operand_num.negate
      when '+', 'plus'
        # Unary plus just returns the number
        ensure_number_object(operand_obj)
      else
        raise "Unknown unary operator: #{operator}"
      end
    end
    
    def perform_object_comparison(left_value, right_value, operator)
      left_obj = ensure_object(left_value)
      right_obj = ensure_object(right_value)
      
      case operator
      when '=='
        if left_obj.class == right_obj.class
          left_obj.equals(right_obj)
        else
          PatlangObject.create_boolean(left_obj.raw_value == right_obj.raw_value)
        end
      when '!='
        result = if left_obj.class == right_obj.class
          left_obj.equals(right_obj)
        else
          PatlangObject.create_boolean(left_obj.raw_value == right_obj.raw_value)
        end
        PatlangObject.create_boolean(!result.raw_value)
      when '<'
        if left_obj.is_a?(NumberObject) && right_obj.is_a?(NumberObject)
          left_obj.less_than(right_obj)
        else
          left_num = ensure_number_object(left_obj)
          right_num = ensure_number_object(right_obj)
          left_num.less_than(right_num)
        end
      when '>'
        if left_obj.is_a?(NumberObject) && right_obj.is_a?(NumberObject)
          left_obj.greater_than(right_obj)
        else
          left_num = ensure_number_object(left_obj)
          right_num = ensure_number_object(right_obj)
          left_num.greater_than(right_num)
        end
      when '<='
        if left_obj.is_a?(NumberObject) && right_obj.is_a?(NumberObject)
          left_obj.less_than_or_equal(right_obj)
        else
          left_num = ensure_number_object(left_obj)
          right_num = ensure_number_object(right_obj)
          left_num.less_than_or_equal(right_num)
        end
      when '>='
        if left_obj.is_a?(NumberObject) && right_obj.is_a?(NumberObject)
          left_obj.greater_than_or_equal(right_obj)
        else
          left_num = ensure_number_object(left_obj)
          right_num = ensure_number_object(right_obj)
          left_num.greater_than_or_equal(right_num)
        end
      else
        raise "Unknown comparison operator: #{operator}"
      end
    end
    
    def perform_legacy_binary_operation(left_value, right_value, operator)
      # Handle both symbol and string operators
      operator = operator.to_s.downcase
      
      case operator
      when '+', 'plus'
        # String concatenation with auto-conversion
        if left_value.is_a?(String) || right_value.is_a?(String)
          convert_to_string(left_value) + convert_to_string(right_value)
        else
          left_value + right_value
        end
      when '-', 'minus'
        left_value - right_value
      when '*', 'multiply', 'star'
        left_value * right_value
      when '/', 'divide', 'slash'
        if right_value == 0
          raise "Division by zero"
        end
        left_value.to_f / right_value
      when '%', 'modulo'
        left_value % right_value
      when '==', 'equal'
        left_value == right_value
      when '!=', 'not_equal'
        left_value != right_value
      when '<', 'less_than', 'less'
        left_value < right_value
      when '>', 'greater_than', 'greater'
        left_value > right_value
      when '<=', 'less_equal'
        left_value <= right_value
      when '>=', 'greater_equal'
        left_value >= right_value
      else
        raise "Unknown operator: #{operator}"
      end
    end
    
    def perform_legacy_unary_operation(operand_value, operator)
      case operator.to_s.downcase
      when '-', 'minus'
        -operand_value
      else
        raise "Unknown unary operator: #{operator}"
      end
    end
    
    def perform_legacy_comparison(left_value, right_value, operator)
      case operator
      when '=='
        left_value == right_value
      when '!='
        left_value != right_value
      when '<'
        left_value < right_value
      when '>'
        left_value > right_value
      when '<='
        left_value <= right_value
      when '>='
        left_value >= right_value
      else
        raise "Unknown comparison operator: #{operator}"
      end
    end
    
    def ensure_object(value)
      case value
      when PatlangObject
        value
      when Numeric
        NumberObject.new(value)
      when String
        StringObject.new(value)
      when TrueClass, FalseClass
        PatlangObject.create_boolean(value)
      when NilClass
        PatlangObject.create_nil
      else
        PatlangObject.wrap(value)
      end
    end
    
    def ensure_number_object(obj)
      case obj
      when NumberObject
        obj
      when PatlangObject
        NumberObject.new(obj.to_number)
      when Numeric
        NumberObject.new(obj)
      else
        NumberObject.new(obj.to_f)
      end
    end
    
    # Convert values to strings for concatenation, handling integers specially
    def convert_to_string(value)
      case value
      when Integer
        value.to_s
      when Float
        # Only show decimal places if they're non-zero
        value == value.to_i ? value.to_i.to_s : value.to_s
      else
        value.to_s
      end
    end
  end
end