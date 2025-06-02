require_relative '../ast_nodes'

# Function evaluation module for handling function definitions and calls
module EvaluatorModules
  class FunctionEvaluator
    def initialize(evaluator)
      @evaluator = evaluator
    end

    def visit_function_definition_node(node)
      # Check for function overloading validation
      if @evaluator.functions.key?(node.name)
        existing_params = @evaluator.functions[node.name][:parameters].length
        new_params = node.parameters.length
        if existing_params == new_params
          raise "Function '#{node.name}' with #{new_params} parameters already exists"
        end
      end

      # Store function definition in function registry
      function_key = "#{node.name}_#{node.parameters.length}"
      @evaluator.functions[function_key] = {
        name: node.name,
        parameters: node.parameters,
        body: node.body,
        return_type: node.return_type
      }

      # Also store by just name for zero or single parameter lookups
      @evaluator.functions[node.name] = @evaluator.functions[function_key] if node.parameters.length <= 1

      # Return the function name for assignment purposes
      node.name
    end

    def visit_function_call_node(node)
      # Look up function by name and parameter count
      function_key = "#{node.function_name}_#{node.arguments.length}"
      function_def = @evaluator.functions[function_key] || @evaluator.functions[node.function_name]

      # If not found by exact match, search for any function with this name
      unless function_def
        matching_functions = @evaluator.functions.select { |key, _| key.to_s.start_with?("#{node.function_name}_") }
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
      @evaluator.push_scope

      # Bind parameters to arguments
      function_def[:parameters].each_with_index do |param, index|
        arg_value = @evaluator.evaluate(node.arguments[index])
        @evaluator.set_variable(param.name, arg_value)
      end

      # Execute function body
      @evaluator.returned = false
      @evaluator.return_value = nil
      
      result = @evaluator.evaluate(function_def[:body])
      
      # Handle return value - use explicit return value if present, otherwise last expression
      final_result = @evaluator.returned ? @evaluator.return_value : result
      
      # Reset return state
      @evaluator.returned = false
      @evaluator.return_value = nil
      
      # Restore previous scope
      @evaluator.pop_scope

      final_result
    end

    def visit_return_node(node)
      @evaluator.returned = true
      @evaluator.return_value = node.expression ? @evaluator.evaluate(node.expression) : nil
      @evaluator.return_value
    end
  end
end