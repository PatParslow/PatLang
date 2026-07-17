#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to run the native PaTLang build tool using the actual PaTLang interpreter

require_relative '../patlang-core/lexer/lexer'
require_relative '../patlang-core/lexer/token'
require_relative '../patlang-core/parser/parser'
require_relative '../patlang-core/ast/ast_nodes'
require_relative '../patlang-core/evaluator/evaluator'
require_relative '../patlang-core/reasoning/reasoning_coordinator'
require_relative '../patlang-core/reasoning/form_validator'
require_relative '../patlang-core/reasoning/goal_system'
require_relative '../patlang-core/reasoning/facts_database'

class PaTLangBuildToolRunner
  def initialize
    @test_results = []
    puts "🚀 Testing Native PaTLang Build Tool with Real Interpreter"
    puts "=" * 60
  end
  
  def run_patlang_code(code, description = "PaTLang Code")
    puts "\n📝 #{description}"
    puts "-" * 40
    puts "Code:\n#{code.strip}"
    puts "-" * 40
    
    begin
      # Tokenize
      lexer = Lexer.new(code)
      tokens = lexer.tokenize
      
      # Parse
      parser = Parser.new(tokens)
      ast = parser.parse
      
      # Evaluate
      evaluator = Evaluator.new
      result = evaluator.evaluate(ast)
      
      puts "✅ Result: #{result}"
      @test_results << { test: description, status: :success, result: result }
      result
      
    rescue => e
      puts "❌ Error: #{e.message}"
      puts "   Backtrace: #{e.backtrace.first(3).join(' → ')}"
      @test_results << { test: description, status: :error, error: e.message }
      nil
    end
  end
  
  def test_basic_patlang_features
    test_section("Basic PaTLang Language Features")
    
    # Test basic arithmetic
    run_patlang_code("5 + 3", "Basic arithmetic")
    
    # Test variable assignment
    run_patlang_code("x = 10", "Variable assignment")
    
    # Test string operations
    run_patlang_code('"Hello " + "World"', "String concatenation")
    
    # Test function definition
    run_patlang_code('
make function double(n) {
  return n * 2
}
', "Function definition")
  end
  
  def test_reasoning_features
    test_section("Reasoning System Features")
    
    # Test reasoning mode
    run_patlang_code("reasoning mode on", "Enable reasoning mode")
    
    # Test fact assertion
    run_patlang_code("fact parent(john, mary)", "Assert fact")
    
    # Test constraint definition
    run_patlang_code("constrain x :: Number", "Type constraint")
  end
  
  def test_simplified_build_tool_concepts
    test_section("Simplified Build Tool Concepts")
    
    # Test simple target definition concept
    run_patlang_code('
target_name = "compile_main"
target_command = "gcc main.c -o main"
', "Build target variables")
    
    # Test dependency array
    run_patlang_code('
dependencies = ["compile_a", "compile_b"]
', "Dependency array")
    
    # Test basic goal-like structure
    run_patlang_code('
make function build_target(name) {
  return "Building: " + name
}
', "Build function definition")
    
    # Test calling the build function
    run_patlang_code('
result = call build_target("main")
', "Call build function")
  end
  
  def test_core_build_logic
    test_section("Core Build Logic")
    
    # Test dependency checking logic
    run_patlang_code('
make function has_dependency(target, dep) {
  if target == "main" and dep == "lib" then
    return true
  else
    return false
  end
}
', "Dependency checking function")
    
    # Test build status tracking
    run_patlang_code('
build_status = "pending"
if build_status == "pending" then
  build_status = "building"
end
', "Build status logic")
    
    # Test target execution simulation
    run_patlang_code('
make function execute_target(name, command) {
  return "Executed: " + command + " for " + name
}
', "Target execution function")
  end
  
  def create_minimal_build_tool
    test_section("Minimal Working Build Tool")
    
    # Create a very simple but functional build tool in PaTLang
    minimal_build_tool = '
# Minimal PaTLang Build Tool
make function create_build_tool() {
  return "PaTLang Build Tool initialized"
}

make function register_target(name, command) {
  return "Target " + name + " registered with command: " + command
}

make function build_target(name) {
  return "Building target: " + name + " - SUCCESS"
}

# Initialize the build tool
tool_status = call create_build_tool()

# Register some targets
compile_result = call register_target("compile", "gcc main.c")
link_result = call register_target("link", "gcc main.o -o app")

# Build the targets
build1 = call build_target("compile")
build2 = call build_target("link")
'
    
    run_patlang_code(minimal_build_tool, "Minimal Build Tool Implementation")
  end
  
  def test_section(name)
    puts "\n" + "=" * 60
    puts "🧪 #{name}"
    puts "=" * 60
  end
  
  def generate_final_report
    puts "\n" + "=" * 60
    puts "📊 FINAL TEST RESULTS"
    puts "=" * 60
    
    total = @test_results.length
    success = @test_results.count { |r| r[:status] == :success }
    errors = @test_results.count { |r| r[:status] == :error }
    
    puts "Total Tests: #{total}"
    puts "Successful: #{success}"
    puts "Errors: #{errors}"
    puts "Success Rate: #{((success.to_f / total) * 100).round(1)}%"
    
    if errors > 0
      puts "\n❌ Failed Tests:"
      @test_results.select { |r| r[:status] == :error }.each do |result|
        puts "   • #{result[:test]}: #{result[:error]}"
      end
    end
    
    puts "\n🎯 Assessment:"
    if success == total
      puts "✅ Perfect! The PaTLang interpreter fully supports our build tool concepts."
    elsif success > total * 0.8
      puts "🟢 Excellent! Most build tool concepts work with the PaTLang interpreter."
    elsif success > total * 0.5
      puts "🟡 Good! Core concepts work, some advanced features need development."
    else
      puts "🔴 Needs work! Basic language features need to be implemented first."
    end
    
    puts "\n🚀 Next Steps:"
    if success > total * 0.8
      puts "   → Implement full native PaTLang build tool"
      puts "   → Add advanced reasoning features"
      puts "   → Create production build tool demos"
    else
      puts "   → Focus on core language implementation"
      puts "   → Improve parser/evaluator capabilities"
      puts "   → Add missing language features"
    end
  end
  
  def run_all_tests
    test_basic_patlang_features
    test_reasoning_features  
    test_simplified_build_tool_concepts
    test_core_build_logic
    create_minimal_build_tool
    generate_final_report
  end
end

# Run the comprehensive test
if __FILE__ == $0
  runner = PaTLangBuildToolRunner.new
  runner.run_all_tests
end