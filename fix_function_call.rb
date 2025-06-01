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