require_relative '../../patlang-core/ast/ast_nodes'
require_relative '../../patlang-core/parser/parser'
require_relative '../../patlang-core/lexer/lexer'

# Evaluator class for traversing AST and computing arithmetic results
class Evaluator
  def initialize
    @variables = {}
    @functions = {}
    @scope_stack = []
    @return_value = nil
    @returned = false
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
    when StringNode
      visit_string_node(node)
    when IndexAccessNode
      visit_index_access_node(node)
    when MethodCallNode
      visit_method_call_node(node)
    when FunctionDefinitionNode
      visit_function_definition_node(node)
    when FunctionCallNode
      visit_function_call_node(node)
    when ReturnNode
      visit_return_node(node)
    when IncludeNode
      visit_include_node(node)
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

  def visit_assignment_node(node)
    value = evaluate(node.expression)
    set_variable(node.name, value)
    value
  end

  def visit_variable_node(node)
    get_variable(node.name)
  end

  def visit_boolean_node(node)
    node.value
  end

  def visit_string_node(node)
    node.value
  end

  def visit_include_node(node)
    filename = evaluate(node.expr)
    unless filename.is_a?(String)
      raise "IncludeNode: filename must be a String, got #{filename.inspect} (#{filename.class})"
    end
    raise "Included file not found: #{filename}" unless File.exist?(filename)
    source = File.read(filename)
    lexer = Lexer.new(source)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluate(ast)
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
      # Early return if we hit a return statement
      break if @returned
    end
    result
  end

  # Helper method to determine truthiness according to Patlang rules
  def is_truthy(value)
    value != false && value != nil
  end

  def visit_index_access_node(node)
    object_value = evaluate(node.object)
    index_value = evaluate(node.index)

    unless object_value.is_a?(String)
      raise "Index access is only supported for strings, got #{object_value.class}"
    end

    unless index_value.is_a?(Integer)
      raise "String index must be an integer, got #{index_value.class}"
    end

    # Convert from 1-based to 0-based indexing
    zero_based_index = index_value - 1

    # Support negative indexing (from end, still 1-based: -1 is last character)
    if index_value < 0
      zero_based_index = object_value.length + index_value
    end

    # Bounds checking (1-based indexing)
    if index_value == 0 || zero_based_index < 0 || zero_based_index >= object_value.length
      raise "String index #{evaluate(node.index)} out of bounds for string of length #{object_value.length} (1-based indexing)"
    end

    object_value[zero_based_index]
  end

  def visit_method_call_node(node)
    object_value = evaluate(node.object)

    if object_value.is_a?(String)
      handle_string_method(object_value, node)
    elsif object_value.is_a?(Numeric)
      handle_number_method(object_value, node)
    else
      raise "Method calls are only supported for strings and numbers, got #{object_value.class}"
    end
  end

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
      start_arg = evaluate(node.arguments[0])
      length_arg = evaluate(node.arguments[1])
      
      unless start_arg.is_a?(Integer)
        raise "String.substring start must be an integer, got #{start_arg.class}"
      end
      unless length_arg.is_a?(Integer)
        raise "String.substring length must be an integer, got #{length_arg.class}"
      end
      
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
      prefix_arg = evaluate(node.arguments[0])
      
      unless prefix_arg.is_a?(String)
        raise "String.starts_with prefix must be a string, got #{prefix_arg.class}"
      end
      
      object_value.start_with?(prefix_arg)
    when 'ends_with'
      if node.arguments.length != 1
        raise "String.ends_with method takes 1 argument (suffix), got #{node.arguments.length}"
      end
      suffix_arg = evaluate(node.arguments[0])
      
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

  # Function evaluation methods

  def visit_function_definition_node(node)
    # Check for function overloading validation
    if @functions.key?(node.name)
      existing_params = @functions[node.name][:parameters].length
      new_params = node.parameters.length
      if existing_params == new_params
        raise "Function '#{node.name}' with #{new_params} parameters already exists"
      end
    end

    # Store function definition in function registry
    function_key = "#{node.name}_#{node.parameters.length}"
    @functions[function_key] = {
      name: node.name,
      parameters: node.parameters,
      body: node.body,
      return_type: node.return_type
    }

    # Also store by just name for zero or single parameter lookups
    @functions[node.name] = @functions[function_key] if node.parameters.length <= 1

    # Return the function name for assignment purposes
    node.name
  end

  def visit_function_call_node(node)
    # Look up function by name and parameter count
    function_key = "#{node.function_name}_#{node.arguments.length}"
    function_def = @functions[function_key] || @functions[node.function_name]

    # If not found by exact match, search for any function with this name
    unless function_def
      matching_functions = @functions.select { |key, _| key.to_s.start_with?("#{node.function_name}_") }
      if matching_functions.any?
        # Take the first matching function to get parameter count for error message
        function_def = matching_functions.values.first
      end
    end

    unless function_def
      raise "Undefined function: #{node.function_name}"
    end

    # Parameter count validation
    expected_params = function_def[:parameters].length
    actual_args = node.arguments.length

    if actual_args != expected_params
      raise "Function '#{node.function_name}' expects #{expected_params} arguments, got #{actual_args}"
    end

    # Create new scope for function execution
    push_scope

    # Bind parameters to arguments
    function_def[:parameters].each_with_index do |param, index|
      arg_value = evaluate(node.arguments[index])
      set_variable(param.name, arg_value)
    end

    # Execute function body
    @returned = false
    @return_value = nil
    
    result = evaluate(function_def[:body])
    
    # Handle return value - use explicit return value if present, otherwise last expression
    final_result = @returned ? @return_value : result
    
    # Reset return state
    @returned = false
    @return_value = nil
    
    # Restore previous scope
    pop_scope

    final_result
  end

  def visit_return_node(node)
    @returned = true
    @return_value = node.expression ? evaluate(node.expression) : nil
    @return_value
  end

  # Scope management methods

  def push_scope
    @scope_stack.push(@variables.dup)
  end

  def pop_scope
    if @scope_stack.empty?
      raise "Cannot pop scope: scope stack is empty"
    end
    @variables = @scope_stack.pop
  end

  def set_variable(name, value)
    @variables[name] = value
  end

  def get_variable(name)
    # Look in current scope first, then up the scope stack
    return @variables[name] if @variables.key?(name)

    # Search through scope stack from most recent to oldest
    @scope_stack.reverse_each do |scope|
      return scope[name] if scope.key?(name)
    end

    raise "Undefined variable: #{name}"
  end

end