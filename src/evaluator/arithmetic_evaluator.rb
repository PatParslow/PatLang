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
          left_value.to_s + right_value.to_s
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
        raise "Unknown operator: #{node.operator}"
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
  end
end