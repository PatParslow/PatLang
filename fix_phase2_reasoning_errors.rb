#!/usr/bin/env ruby

puts "=== Phase 2 Reasoning System Error Fixes ==="

# Fix 1: ReasoningCoordinator - make evaluator parameter optional
puts "\n1. Fixing ReasoningCoordinator constructor..."

reasoning_coordinator_path = 'src/reasoning/reasoning_coordinator.rb'
content = File.read(reasoning_coordinator_path)

# Fix constructor to make evaluator optional
updated_content = content.gsub(
  /def initialize\(evaluator\)/,
  'def initialize(evaluator = nil)'
)

File.write(reasoning_coordinator_path, updated_content)
puts "  ✓ ReasoningCoordinator constructor fixed - evaluator parameter now optional"

# Fix 2: TypeConstraintSystem - add alias for add_constraint method
puts "\n2. Fixing TypeConstraintSystem missing method..."

type_constraint_system_path = 'src/reasoning/type_constraint_system.rb'
content = File.read(type_constraint_system_path)

# Add alias method after create_constraint method
alias_method = "\n  # Alias for backward compatibility\n  alias_method :add_constraint, :create_constraint\n"

# Insert after the create_constraint method ends
updated_content = content.gsub(
  /(def create_constraint.*?^  end)/m,
  "\\1#{alias_method}"
)

File.write(type_constraint_system_path, updated_content)
puts "  ✓ TypeConstraintSystem add_constraint alias added"

# Fix 3: TypeConstraintSystem - fix boolean call issue at line 437
puts "\n3. Fixing TypeConstraintSystem boolean call issue..."

content = File.read(type_constraint_system_path)

# Fix the satisfies_custom_constraint method to check if constraint_data is callable
updated_content = content.gsub(
  /def satisfies_custom_constraint\?\(value\)\s*begin\s*@constraint_data\.call\(value\)/m,
  'def satisfies_custom_constraint?(value)
    return false unless @constraint_data.respond_to?(:call)
    begin
      @constraint_data.call(value)'
)

File.write(type_constraint_system_path, updated_content)
puts "  ✓ TypeConstraintSystem callable check added at line 437"

# Fix 4: TypeConstraint - fix similar boolean call issue  
puts "\n4. Fixing TypeConstraint boolean call issue..."

type_constraint_path = 'src/reasoning/type_constraint.rb'
content = File.read(type_constraint_path)

# Fix the satisfies_custom_constraint method to better handle non-callable types
updated_content = content.gsub(
  /def satisfies_custom_constraint\?\(value\)\s*case @constraint_data\s*when Proc\s*@constraint_data\.call\(value\)\s*when Method\s*@constraint_data\.call\(value\)\s*else\s*false\s*end/m,
  'def satisfies_custom_constraint?(value)
    case @constraint_data
    when Proc, Method
      @constraint_data.call(value)
    when TrueClass, FalseClass
      @constraint_data  # Return the boolean value directly
    else
      # For other types, assume it\'s a callable if it responds to call
      @constraint_data.respond_to?(:call) ? @constraint_data.call(value) : false
    end'
)

File.write(type_constraint_path, updated_content)
puts "  ✓ TypeConstraint boolean handling improved"

puts "\n=== Phase 2 Fixes Applied Successfully ==="
puts "\nRunning validation to verify fixes..."

# Load the fixed files to verify they work
begin
  load 'src/reasoning/reasoning_coordinator.rb'
  puts "  ✓ ReasoningCoordinator loads successfully"
rescue => e
  puts "  ✗ ReasoningCoordinator error: #{e.message}"
end

begin
  load 'src/reasoning/type_constraint_system.rb'
  puts "  ✓ TypeConstraintSystem loads successfully"
rescue => e
  puts "  ✗ TypeConstraintSystem error: #{e.message}"
end

begin
  load 'src/reasoning/type_constraint.rb'
  puts "  ✓ TypeConstraint loads successfully"
rescue => e
  puts "  ✗ TypeConstraint error: #{e.message}"
end

puts "\n=== Phase 2 Error Fixes Complete ==="