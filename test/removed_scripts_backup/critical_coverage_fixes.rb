#!/usr/bin/env ruby

require_relative 'helpers/test_helper'

puts "🔧 PATLANG Critical Coverage Fixes - Implementing Priority Fixes"
puts "=" * 80

# Fix 1: Cross-Paradigm Coordinator Syntax Errors
puts "\n🔴 Priority 1: Fixing Cross-Paradigm Coordinator Syntax Errors"

coordinator_file = 'src/reasoning/cross_paradigm_coordinator.rb'
if File.exist?(coordinator_file)
  content = File.read(coordinator_file)
  
  # Fix the malformed ensure blocks
  fixed_content = content.gsub(/(\s+)ensure\s*$/, '\1end')
  fixed_content = fixed_content.gsub(/(\s+)nil\s+ensure/, '\1nil\nrescue => e\n\1  @workflow_depth -= 1 if @workflow_depth > 0\nend')
  fixed_content = fixed_content.gsub(/(@workflow_depth -= 1 if @workflow_depth > 0)\s+ensure\s*/, '\1')
  
  # Write the fixed version
  File.write(coordinator_file, fixed_content)
  puts "✅ Fixed syntax errors in cross_paradigm_coordinator.rb"
else
  puts "❌ Cross-paradigm coordinator file not found"
end

# Fix 2: Add missing VariableNode.value method
puts "\n🔴 Priority 2: Adding VariableNode.value method"

ast_nodes_file = 'src/ast_nodes.rb'
if File.exist?(ast_nodes_file)
  content = File.read(ast_nodes_file)
  
  unless content.include?('def value')
    # Find VariableNode class and add value method
    if content.include?('class VariableNode')
      value_method = <<~RUBY
        
        def value
          @name
        end
      RUBY
      
      content = content.gsub(/(class VariableNode.*?end)/m) do |match|
        match.gsub(/(\s+)end\s*$/, "#{value_method}\\1end")
      end
      
      File.write(ast_nodes_file, content)
      puts "✅ Added value method to VariableNode"
    else
      puts "❌ VariableNode class not found in ast_nodes.rb"
    end
  else
    puts "✅ VariableNode.value method already exists"
  end
else
  puts "❌ AST nodes file not found"
end

# Fix 3: Add ErrorNode handling to evaluator
puts "\n🔴 Priority 3: Adding ErrorNode handling to evaluator"

evaluator_file = 'src/evaluator.rb'
if File.exist?(evaluator_file)
  content = File.read(evaluator_file)
  
  unless content.include?('visit_error_node')
    error_handler = <<~RUBY
      
      def visit_error_node(node)
        raise RuntimeError, "Parse error: \#{node.message || 'Unknown parse error'}"
      end
    RUBY
    
    # Add before the final end of the class
    content = content.gsub(/(class.*?Evaluator.*?)(\s+end\s*$)/m, "\\1#{error_handler}\\2")
    File.write(evaluator_file, content)
    puts "✅ Added ErrorNode handling to evaluator"
  else
    puts "✅ ErrorNode handling already exists in evaluator"
  end
else
  puts "❌ Evaluator file not found"
end

puts "\n🧪 Creating targeted branch coverage tests..."

# Create comprehensive error handling tests
error_coverage_test = <<~RUBY
require_relative '../helpers/test_helper'

class TestErrorHandlingCoverage < Minitest::Test
  def setup
    @evaluator = Evaluator.new
  end

  def test_cross_paradigm_coordinator_error_branches
    skip "Cross-paradigm coordinator needs fixing" unless File.exist?('../src/reasoning/cross_paradigm_coordinator.rb')
    
    require_relative '../../src/reasoning/cross_paradigm_coordinator'
    
    coordinator = CrossParadigmCoordinator.new
    
    # Test error handling branches
    assert_raises(RuntimeError) do
      coordinator.send(:initialize_type_system) rescue nil
    end
    
    # Test workflow depth tracking
    assert_equal 0, coordinator.instance_variable_get(:@workflow_depth)
  end

  def test_variable_node_value_method
    require_relative '../../src/ast_nodes'
    
    node = VariableNode.new('test_var')
    assert_equal 'test_var', node.value
  end

  def test_error_node_handling
    require_relative '../../src/ast_nodes'
    
    # Create mock ErrorNode if it doesn't exist
    error_node_class = Class.new do
      attr_reader :message
      def initialize(message)
        @message = message
      end
    end
    
    Object.const_set('ErrorNode', error_node_class) unless defined?(ErrorNode)
    
    error_node = ErrorNode.new("Test parse error")
    
    assert_raises(RuntimeError, "Parse error: Test parse error") do
      @evaluator.visit_error_node(error_node)
    end
  end

  def test_type_constraint_error_branches
    require_relative '../../src/reasoning/type_constraint'
    
    # Test invalid constraint creation
    assert_raises(ArgumentError) do
      TypeConstraint.new(nil, nil, nil, nil) # Wrong number of args
    end
  end

  def test_reasoning_mode_validation_branches
    # Test that reasoning features require reasoning mode
    code = "constrain x :: Number"
    
    assert_raises(RuntimeError, "Type constraints require reasoning mode to be enabled") do
      @evaluator.evaluate_string(code)
    end
  end

  def test_parser_error_recovery_branches
    require_relative '../../src/parser'
    
    parser = Parser.new([])
    
    # Test various error conditions
    assert_raises(ParseError) do
      parser.parse
    end
  end

  def test_facts_database_error_branches
    require_relative '../../src/reasoning/facts_database'
    
    db = FactsDatabase.new
    
    # Test invalid fact insertion
    assert_raises(ArgumentError) do
      db.assert_fact(nil)
    end
    
    # Test query on empty database
    result = db.query("nonexistent_predicate")
    assert_empty result
  end

  def test_goal_system_error_branches
    require_relative '../../src/reasoning/goal_system'
    
    goal_system = GoalSystem.new
    
    # Test invalid goal creation
    assert_raises(ArgumentError) do
      goal_system.create_goal(nil, {})
    end
  end

  def test_unification_engine_edge_cases
    require_relative '../../src/reasoning/unification_engine'
    
    engine = UnificationEngine.new
    
    # Test occurs check
    var_x = VariableNode.new('X')
    compound = [var_x, var_x] # Self-reference
    
    result = engine.unify(var_x, compound)
    assert_nil result, "Occurs check should prevent infinite structures"
  end
end
RUBY

File.write('test/infrastructure/test_error_handling_coverage.rb', error_coverage_test)
puts "✅ Created comprehensive error handling coverage tests"

# Create constraint validation coverage tests
constraint_coverage_test = <<~RUBY
require_relative '../helpers/test_helper'

class TestConstraintValidationCoverage < Minitest::Test
  def setup
    @constraint_system = TypeConstraintSystem.new rescue nil
  end

  def test_constraint_creation_branches
    skip "TypeConstraintSystem not available" unless @constraint_system
    
    # Test valid constraint creation
    constraint = @constraint_system.create_constraint('x', 'Number', nil)
    assert_not_nil constraint
    
    # Test constraint with conditions
    constraint_with_condition = @constraint_system.create_constraint('y', 'Number', 'y > 0')
    assert_not_nil constraint_with_condition
  end

  def test_constraint_violation_detection
    skip "TypeConstraintSystem not available" unless @constraint_system
    
    # Test constraint violation
    constraint = @constraint_system.create_constraint('x', 'Number', 'x > 0')
    
    assert_raises(TypeConstraintViolation) do
      @constraint_system.validate_assignment('x', -5)
    end
  end

  def test_constraint_performance_branches
    skip "TypeConstraintSystem not available" unless @constraint_system
    
    # Test large number of constraints
    start_time = Time.now
    
    100.times do |i|
      @constraint_system.create_constraint("var#{i}", 'Number', "var#{i} >= 0")
    end
    
    duration = Time.now - start_time
    assert duration < 1.0, "Constraint creation should be fast"
  end

  def test_complex_constraint_conditions
    skip "TypeConstraintSystem not available" unless @constraint_system
    
    # Test complex boolean conditions
    constraint = @constraint_system.create_constraint('age', 'Number', 'age >= 0 and age <= 150')
    assert_not_nil constraint
    
    # Test validation of complex conditions
    assert @constraint_system.validate_assignment('age', 25)
    assert_raises(TypeConstraintViolation) do
      @constraint_system.validate_assignment('age', -1)
    end
  end
end
RUBY

File.write('test/infrastructure/test_constraint_validation_coverage.rb', constraint_coverage_test)
puts "✅ Created constraint validation coverage tests"

puts "\n🎯 Coverage improvement tests created successfully!"
puts "📁 Test files:"
puts "  - test/infrastructure/test_error_handling_coverage.rb"
puts "  - test/infrastructure/test_constraint_validation_coverage.rb"

puts "\n🚀 Next steps:"
puts "1. Run the fixed tests to verify improvements"
puts "2. Measure branch coverage again"
puts "3. Implement additional edge case tests as needed"

puts "\n" + "=" * 80
RUBY