require_relative 'ast_nodes'

# Evaluator class for traversing AST and computing arithmetic results
class Evaluator
  def initialize
    @variables = {}
  end

  def evaluate(node)
    case node
    when NumberNode
      visit_number_node(node)
    when BinaryOpNode
      visit_binary_op_node(node)
    when AssignmentNode
      visit_assignment_node(node)
    when VariableNode
      visit_variable_node(node)
    when BooleanNode
      visit_boolean_node(node)
    when ComparisonNode
      visit_comparison_node(node)
    when IfNode
      visit_if_node(node)
    when WhileNode
      visit_while_node(node)
    when BlockNode
      visit_block_node(node)
    else
      raise "Unknown node type: #{node.class}"
    end
  end

  private

  def visit_number_node(node)
    node.value
  end

  def visit_binary_op_node(node)
    left_value = evaluate(node.left)
    right_value = evaluate(node.right)

    case node.operator
    when '+'
      left_value + right_value
    when '-'
      left_value - right_value
    when '*'
      left_value * right_value
    when '/'
      if right_value == 0
        raise "Division by zero"
      end
      left_value.to_f / right_value
    else
      raise "Unknown operator: #{node.operator}"
    end
  end

  def visit_assignment_node(node)
    value = evaluate(node.expression)
    @variables[node.name] = value
    value
  end

  def visit_variable_node(node)
    unless @variables.key?(node.name)
      raise "Undefined variable: #{node.name}"
    end
    @variables[node.name]
  end

  def visit_boolean_node(node)
    node.value
  end

  def visit_comparison_node(node)
    left_value = evaluate(node.left)
    right_value = evaluate(node.right)

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

  def visit_if_node(node)
    condition_value = evaluate(node.condition)
    
    # Implement Patlang truthiness: false and nil are falsy, everything else is truthy
    if is_truthy(condition_value)
      evaluate(node.then_body)
    elsif node.else_body
      evaluate(node.else_body)
    else
      nil
    end
  end

  def visit_while_node(node)
    result = nil
    loop_count = 0
    max_iterations = 10000  # Infinite loop protection
    
    while is_truthy(evaluate(node.condition))
      loop_count += 1
      if loop_count > max_iterations
        raise "Maximum loop iterations exceeded (#{max_iterations}). Possible infinite loop."
      end
      
      result = evaluate(node.body)
    end
    
    result
  end

  def visit_block_node(node)
    result = nil
    node.statements.each do |statement|
      result = evaluate(statement)
    end
    result
  end

  # Helper method to determine truthiness according to Patlang rules
  def is_truthy(value)
    value != false && value != nil
  end
end