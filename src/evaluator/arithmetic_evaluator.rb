require_relative '../ast_nodes'

# Arithmetic evaluation module for handling number and binary operations
module EvaluatorModules
  class ArithmeticEvaluator
    def initialize(evaluator)
      @evaluator = evaluator
    end

    def visit_number_node(node)
      node.value
    end

    def visit_binary_op_node(node)
      left_value = @evaluator.evaluate(node.left)
      right_value = @evaluator.evaluate(node.right)

      # Handle both symbol and string operators
      operator = node.operator.to_s.downcase
      
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
          raise ZeroDivisionError, "Division by zero"
        end
        left_value.to_f / right_value
      when '%', 'modulo'
        left_value % right_value
      when '^', 'power', 'exponent'
        # FIXED: Add exponentiation support
        left_value ** right_value
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
        raise "Unknown operator: #{node.operator}"
      end
    end

    def visit_unary_op_node(node)
      operand_value = @evaluator.evaluate(node.operand)
      
      case node.operator.to_s.downcase
      when '-', 'minus'
        -operand_value
      else
        raise "Unknown unary operator: #{node.operator}"
      end
    end

    def visit_comparison_node(node)
      left_value = @evaluator.evaluate(node.left)
      right_value = @evaluator.evaluate(node.right)

      case node.operator
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
        raise "Unknown comparison operator: #{node.operator}"
      end
    end

    def visit_boolean_node(node)
      node.value
    end

    private

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