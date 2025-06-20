#!/usr/bin/env ruby

# PaTLang Phase 1 Self-Hosting Test Suite
# Comprehensive testing for the self-hosting evaluator implementation

require_relative 'ruby_bridge'
require 'minitest/autorun'
require 'minitest/reporters'

Minitest::Reporters.use! [Minitest::Reporters::ProgressReporter.new]

class Phase1SelfHostingTest < Minitest::Test
  def setup
    @bridge = PaTLangPhase1Bridge.new
    @test_results = {
      passed: 0,
      failed: 0,
      total: 0,
      errors: []
    }
  end
  
  def teardown
    @bridge.cleanup
    
    puts "\n=== Phase 1 Test Summary ==="
    puts "Total tests: #{@test_results[:total]}"
    puts "Passed: #{@test_results[:passed]}"
    puts "Failed: #{@test_results[:failed]}"
    puts "Success rate: #{(@test_results[:passed].to_f / @test_results[:total] * 100).round(2)}%"
    
    unless @test_results[:errors].empty?
      puts "\nErrors encountered:"
      @test_results[:errors].each_with_index do |error, i|
        puts "  #{i + 1}. #{error}"
      end
    end
  end
  
  # Test basic arithmetic evaluation
  def test_basic_arithmetic_evaluation
    test_cases = [
      { code: "42", expected: 42, description: "integer literal" },
      { code: "3.14", expected: 3.14, description: "float literal" },
      { code: "2 + 3", expected: 5, description: "addition" },
      { code: "10 - 4", expected: 6, description: "subtraction" },
      { code: "3 * 7", expected: 21, description: "multiplication" },
      { code: "15 / 3", expected: 5, description: "division" },
      { code: "2 + 3 * 4", expected: 14, description: "operator precedence" },
      { code: "(2 + 3) * 4", expected: 20, description: "parentheses grouping" }
    ]
    
    test_cases.each do |test_case|
      @test_results[:total] += 1
      
      begin
        # Test with Ruby evaluator
        ruby_result = @bridge.evaluate(test_case[:code], prefer_patlang: false)
        assert ruby_result[:success], "Ruby evaluation failed for #{test_case[:description]}: #{ruby_result[:error]}"
        assert_equal test_case[:expected], ruby_result[:value], "Ruby result mismatch for #{test_case[:description]}"
        
        # Test with PaTLang evaluator (simulated)
        patlang_result = @bridge.evaluate(test_case[:code], prefer_patlang: true)
        assert patlang_result[:success], "PaTLang evaluation failed for #{test_case[:description]}: #{patlang_result[:error]}"
        assert_equal test_case[:expected], patlang_result[:value], "PaTLang result mismatch for #{test_case[:description]}"
        
        # Ensure both evaluators produce the same result
        assert_equal ruby_result[:value], patlang_result[:value], "Evaluator results differ for #{test_case[:description]}"
        
        @test_results[:passed] += 1
        puts "  ✓ #{test_case[:description]}: #{test_case[:code]} => #{ruby_result[:value]}"
        
      rescue => e
        @test_results[:failed] += 1
        @test_results[:errors] << "#{test_case[:description]}: #{e.message}"
        puts "  ✗ #{test_case[:description]}: #{e.message}"
      end
    end
  end
  
  # Test evaluator selection logic
  def test_evaluator_selection_logic
    @test_results[:total] += 1
    
    begin
      # Regular arithmetic should prefer Ruby by default
      ruby_preferred = @bridge.evaluate("2 + 3", prefer_patlang: false)
      assert_equal :ruby, ruby_preferred[:evaluator_used]
      
      # Goal-oriented constructs should prefer PaTLang
      goal_code = "goal test() { precondition: true, postcondition: true }"
      patlang_preferred = @bridge.evaluate(goal_code, prefer_patlang: true)
      assert_includes [:patlang, :patlang_simulation], patlang_preferred[:evaluator_used]
      
      @test_results[:passed] += 1
      puts "  ✓ Evaluator selection logic working correctly"
      
    rescue => e
      @test_results[:failed] += 1
      @test_results[:errors] << "Evaluator selection: #{e.message}"
      puts "  ✗ Evaluator selection logic failed: #{e.message}"
    end
  end
  
  # Test error handling and fallback mechanisms
  def test_error_handling_and_fallback
    @test_results[:total] += 1
    
    begin
      # Test division by zero
      division_by_zero = @bridge.evaluate("10 / 0")
      assert !division_by_zero[:success], "Division by zero should fail"
      assert_not_nil division_by_zero[:error]
      
      # Test invalid syntax
      invalid_syntax = @bridge.evaluate("2 + + 3")
      assert !invalid_syntax[:success], "Invalid syntax should fail"
      
      # Test fallback from PaTLang to Ruby
      complex_code = "class TestClass; end"  # Ruby-specific construct
      fallback_result = @bridge.evaluate(complex_code, prefer_patlang: true)
      # Should either use Ruby directly or fall back to Ruby
      assert_includes [:ruby, :ruby_fallback], fallback_result[:evaluator_used]
      
      @test_results[:passed] += 1
      puts "  ✓ Error handling and fallback mechanisms working"
      
    rescue => e
      @test_results[:failed] += 1
      @test_results[:errors] << "Error handling: #{e.message}"
      puts "  ✗ Error handling test failed: #{e.message}"
    end
  end
  
  # Test memory management integration
  def test_memory_management_integration
    @test_results[:total] += 1
    
    begin
      initial_stats = @bridge.get_evaluation_statistics
      
      # Perform several evaluations to test memory tracking
      (1..10).each do |i|
        result = @bridge.evaluate("#{i} * #{i}")
        assert result[:success], "Evaluation #{i} failed"
        assert_equal i * i, result[:value]
      end
      
      final_stats = @bridge.get_evaluation_statistics
      assert final_stats[:total_evaluations] > initial_stats[:total_evaluations]
      
      # Test native bridge memory allocation if available
      if @bridge.instance_variable_get(:@native_bridge_initialized)
        memory_ptr = @bridge.allocate_memory(1024, 8, 1)
        # Memory allocation test (basic check)
        bridge_stats = @bridge.get_bridge_statistics
        assert bridge_stats[:total_allocated] > 0, "Native memory allocation should be tracked"
      end
      
      @test_results[:passed] += 1
      puts "  ✓ Memory management integration working"
      
    rescue => e
      @test_results[:failed] += 1
      @test_results[:errors] << "Memory management: #{e.message}"
      puts "  ✗ Memory management test failed: #{e.message}"
    end
  end
  
  # Test goal-oriented programming constructs (simulated)
  def test_goal_oriented_constructs
    @test_results[:total] += 1
    
    begin
      goal_constructs = [
        "goal simple_goal() { precondition: true, postcondition: true }",
        "fact simple_fact(42)",
        "rule simple_rule(X) :- X > 0",
        "constrain x :: Number where { x > 0 }"
      ]
      
      goal_constructs.each do |construct|
        result = @bridge.evaluate(construct, prefer_patlang: true)
        # For Phase 1, we expect these to be handled by the simulation
        # The key is that they don't crash and attempt PaTLang evaluation
        assert_includes [:patlang_simulation, :ruby_fallback], result[:evaluator_used]
      end
      
      @test_results[:passed] += 1
      puts "  ✓ Goal-oriented constructs handled appropriately"
      
    rescue => e
      @test_results[:failed] += 1
      @test_results[:errors] << "Goal-oriented constructs: #{e.message}"
      puts "  ✗ Goal-oriented constructs test failed: #{e.message}"
    end
  end
  
  # Test self-hosting capability (conceptual test)
  def test_self_hosting_capability
    @test_results[:total] += 1
    
    begin
      # Test that the PaTLang evaluator can be loaded
      assert @bridge.instance_variable_get(:@patlang_evaluator_loaded), "PaTLang evaluator should be loaded"
      
      # Test that the evaluator AST is available
      evaluator_ast = @bridge.instance_variable_get(:@patlang_evaluator_ast)
      assert_not_nil evaluator_ast, "PaTLang evaluator AST should be available"
      
      # Test that we can create evaluation contexts
      context = @bridge.send(:create_patlang_evaluation_context)
      assert context[:initialized], "Evaluation context should be initialized"
      assert_not_nil context[:scope_stack], "Context should have scope stack"
      assert_not_nil context[:memory_manager], "Context should have memory manager"
      
      # Conceptual self-hosting test - evaluate a simple expression
      # using the simulated PaTLang evaluator
      self_hosting_result = @bridge.evaluate("2 + 2", prefer_patlang: true)
      assert self_hosting_result[:success], "Self-hosting evaluation should succeed"
      assert_equal 4, self_hosting_result[:value], "Self-hosting should produce correct result"
      
      @test_results[:passed] += 1
      puts "  ✓ Self-hosting capability demonstrated"
      
    rescue => e
      @test_results[:failed] += 1
      @test_results[:errors] << "Self-hosting capability: #{e.message}"
      puts "  ✗ Self-hosting capability test failed: #{e.message}"
    end
  end
  
  # Test performance characteristics
  def test_performance_characteristics
    @test_results[:total] += 1
    
    begin
      # Measure evaluation performance
      test_expression = "((2 + 3) * 4) - ((5 + 6) / 2)"
      iterations = 100
      
      # Ruby evaluator performance
      ruby_start = Time.now
      iterations.times do
        @bridge.evaluate(test_expression, prefer_patlang: false)
      end
      ruby_time = Time.now - ruby_start
      
      # PaTLang evaluator performance
      patlang_start = Time.now
      iterations.times do
        @bridge.evaluate(test_expression, prefer_patlang: true)
      end
      patlang_time = Time.now - patlang_start
      
      # Performance analysis
      ruby_avg = (ruby_time / iterations) * 1000  # milliseconds
      patlang_avg = (patlang_time / iterations) * 1000  # milliseconds
      
      puts "  Performance comparison (#{iterations} iterations):"
      puts "    Ruby average: #{ruby_avg.round(3)}ms"
      puts "    PaTLang average: #{patlang_avg.round(3)}ms"
      puts "    Ratio: #{(patlang_time / ruby_time).round(2)}x"
      
      # For Phase 1, PaTLang (simulated) might be slower due to overhead
      # This is expected and acceptable
      assert ruby_avg < 10, "Ruby evaluation should be reasonably fast"
      assert patlang_avg < 50, "PaTLang evaluation should be acceptably fast"
      
      @test_results[:passed] += 1
      puts "  ✓ Performance characteristics within acceptable ranges"
      
    rescue => e
      @test_results[:failed] += 1
      @test_results[:errors] << "Performance characteristics: #{e.message}"
      puts "  ✗ Performance characteristics test failed: #{e.message}"
    end
  end
  
  # Test bridge statistics and monitoring
  def test_bridge_statistics_and_monitoring
    @test_results[:total] += 1
    
    begin
      # Get initial statistics
      initial_stats = @bridge.get_evaluation_statistics
      assert_kind_of Hash, initial_stats
      assert_includes initial_stats.keys, :total_evaluations
      assert_includes initial_stats.keys, :patlang_evaluator_loaded
      
      # Perform some evaluations
      5.times { |i| @bridge.evaluate("#{i} + 1") }
      
      # Check updated statistics
      updated_stats = @bridge.get_evaluation_statistics
      assert updated_stats[:total_evaluations] > initial_stats[:total_evaluations]
      assert updated_stats[:evaluation_time] > initial_stats[:evaluation_time]
      
      # Test native bridge statistics if available
      if @bridge.instance_variable_get(:@native_bridge_initialized)
        bridge_stats = @bridge.get_bridge_statistics
        assert_kind_of Hash, bridge_stats
        assert_includes bridge_stats.keys, :total_allocated
        assert_includes bridge_stats.keys, :initialized
        assert_equal true, bridge_stats[:initialized]
      end
      
      @test_results[:passed] += 1
      puts "  ✓ Bridge statistics and monitoring working"
      
    rescue => e
      @test_results[:failed] += 1
      @test_results[:errors] << "Bridge statistics: #{e.message}"
      puts "  ✗ Bridge statistics test failed: #{e.message}"
    end
  end
end

# Standalone test runner
if __FILE__ == $0
  puts "=== PaTLang Phase 1 Self-Hosting Test Suite ==="
  puts "Testing the self-hosting evaluator implementation..."
  puts
  
  # Run the test suite
  Minitest.run([])
  
  puts "\nPhase 1 testing completed."
end