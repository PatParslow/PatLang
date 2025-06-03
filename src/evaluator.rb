require_relative 'ast_nodes'
require_relative 'evaluator/arithmetic_evaluator'
require_relative 'evaluator/string_evaluator'
require_relative 'evaluator/function_evaluator'
require_relative 'evaluator/scope_manager'

# Evaluator class for traversing AST with modular architecture
class Evaluator
  attr_reader :functions, :return_value, :returned, :variables
  attr_writer :return_value, :returned

  def initialize
    @scope_manager = EvaluatorModules::ScopeManager.new
    @variables = @scope_manager.variables  # Delegate to scope manager's variables
    @functions = {}
    @return_value = nil
    @returned = false
    
    # Initialize specialized evaluators
    @arithmetic_evaluator = EvaluatorModules::ArithmeticEvaluator.new(self)
    @string_evaluator = EvaluatorModules::StringEvaluator.new(self)
    @function_evaluator = EvaluatorModules::FunctionEvaluator.new(self)
  end

  def evaluate(node)
    case node
    when NumberNode
      @arithmetic_evaluator.visit_number_node(node)
    when BinaryOpNode
      @arithmetic_evaluator.visit_binary_op_node(node)
    when UnaryOpNode
      @arithmetic_evaluator.visit_unary_op_node(node)
    when AssignmentNode
      visit_assignment_node(node)
    when VariableNode
      visit_variable_node(node)
    when BooleanNode
      @arithmetic_evaluator.visit_boolean_node(node)
    when ComparisonNode
      @arithmetic_evaluator.visit_comparison_node(node)
    when IfNode
      visit_if_node(node)
    when WhileNode
      visit_while_node(node)
    when BlockNode
      visit_block_node(node)
    when StringNode
      @string_evaluator.visit_string_node(node)
    when IndexAccessNode
      @string_evaluator.visit_index_access_node(node)
    when MethodCallNode
      @string_evaluator.visit_method_call_node(node)
    when FunctionDefinitionNode
      @function_evaluator.visit_function_definition_node(node)
    when FunctionCallNode
      @function_evaluator.visit_function_call_node(node)
    when ReturnNode
      @function_evaluator.visit_return_node(node)
    else
      raise "Unknown node type: #{node.class}"
    end
  end

  # Delegate scope management methods
  def push_scope
    @scope_manager.push_scope
  end

  def pop_scope
    @scope_manager.pop_scope
  end

  def set_variable(name, value)
    @scope_manager.set_variable(name, value)
  end

  def get_variable(name)
    @scope_manager.get_variable(name)
  end

  private

  def visit_assignment_node(node)
    value = evaluate(node.expression)
    set_variable(node.name, value)
    value
  end

  def visit_variable_node(node)
    get_variable(node.name)
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
      # Early return if we hit a return statement
      break if @returned
    end
    result
  end

  # Helper method to determine truthiness according to Patlang rules
  def is_truthy(value)
    value != false && value != nil
  end
end