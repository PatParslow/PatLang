#!/usr/bin/env ruby

# Integration validation script for missing statistics methods
# Tests that UnificationEngine.statistics and TypeConstraintSystem.constraint_count work properly

require_relative 'src/reasoning/reasoning_coordinator'
require_relative 'src/reasoning/unification_engine'
require_relative 'src/reasoning/type_constraint_system'
require_relative 'src/reasoning/type_constraint'

class StatisticsIntegrationValidator
  def initialize
    @test_results = []
    @errors = []
  end

  def run_validation
    puts "=" * 60
    puts "STATISTICS INTEGRATION VALIDATION"
    puts "=" * 60
    puts

    begin
      test_unification_engine_statistics
      test_type_constraint_system_constraint_count
      test_reasoning_coordinator_integration
      test_statistics_data_format
      test_performance_tracking
      
      print_results
    rescue => e
      puts "CRITICAL ERROR during validation: #{e.message}"
      puts e.backtrace.first(5)
      false
    end
  end

  private

  def test_unification_engine_statistics
    test_name = "UnificationEngine.statistics method exists and is callable"
    
    begin
      engine = UnificationEngine.new
      
      # Test that method exists
      unless engine.respond_to?(:statistics)
        record_failure(test_name, "UnificationEngine does not respond to :statistics method")
        return
      end
      
      # Test that method is callable without errors
      stats = engine.statistics
      
      # Test return format
      unless stats.is_a?(Hash)
        record_failure(test_name, "statistics method should return a Hash, got #{stats.class}")
        return
      end
      
      # Test expected keys exist
      expected_keys = [:unification_attempts, :unification_successes, :unification_failures, 
                      :success_rate, :total_unification_time, :average_unification_time, 
                      :occurs_check_calls, :cache_hits]
      
      missing_keys = expected_keys - stats.keys
      unless missing_keys.empty?
        record_failure(test_name, "Missing expected keys: #{missing_keys}")
        return
      end
      
      record_success(test_name, "All expected statistics keys present: #{stats.keys}")
      
    rescue => e
      record_failure(test_name, "Exception: #{e.message}")
    end
  end

  def test_type_constraint_system_constraint_count
    test_name = "TypeConstraintSystem.constraint_count method exists and is callable"
    
    begin
      system = TypeConstraintSystem.new
      
      # Test that method exists
      unless system.respond_to?(:constraint_count)
        record_failure(test_name, "TypeConstraintSystem does not respond to :constraint_count method")
        return
      end
      
      # Test initial count is 0
      initial_count = system.constraint_count
      unless initial_count == 0
        record_failure(test_name, "Initial constraint count should be 0, got #{initial_count}")
        return
      end
      
      # Test count increases after adding constraints
      system.create_constraint("x", :type, :number)
      system.create_constraint("y", :range, {min: 1, max: 100})
      
      new_count = system.constraint_count
      unless new_count == 2
        record_failure(test_name, "Expected constraint count 2 after adding constraints, got #{new_count}")
        return
      end
      
      record_success(test_name, "constraint_count correctly tracks constraints: 0 -> #{new_count}")
      
    rescue => e
      record_failure(test_name, "Exception: #{e.message}")
    end
  end

  def test_reasoning_coordinator_integration
    test_name = "ReasoningCoordinator.statistics integration works without errors"
    
    begin
      # Create a mock evaluator
      evaluator = Object.new
      coordinator = ReasoningCoordinator.new(evaluator)
      
      # Test that statistics method can be called
      stats = coordinator.statistics
      
      unless stats.is_a?(Hash)
        record_failure(test_name, "ReasoningCoordinator.statistics should return Hash, got #{stats.class}")
        return
      end
      
      # Test that unification_stats key exists and contains data
      unless stats.key?(:unification_stats)
        record_failure(test_name, "Missing :unification_stats key in coordinator statistics")
        return
      end
      
      unless stats[:unification_stats].is_a?(Hash)
        record_failure(test_name, "unification_stats should be Hash, got #{stats[:unification_stats].class}")
        return
      end
      
      # Test that constraints key exists
      unless stats.key?(:constraints)
        record_failure(test_name, "Missing :constraints key in coordinator statistics")
        return
      end
      
      unless stats[:constraints].is_a?(Integer)
        record_failure(test_name, "constraints count should be Integer, got #{stats[:constraints].class}")
        return
      end
      
      record_success(test_name, "Integration successful - coordinator can access component statistics")
      
    rescue => e
      record_failure(test_name, "Integration failed with exception: #{e.message}")
    end
  end

  def test_statistics_data_format
    test_name = "Statistics data format compatibility"
    
    begin
      evaluator = Object.new
      coordinator = ReasoningCoordinator.new(evaluator)
      coordinator.enable_reasoning_mode
      
      # Add some test data
      coordinator.create_constraint("test_var", :type, :number)
      
      # Get fresh statistics
      stats = coordinator.statistics
      
      # Verify structure matches reasoning coordinator expectations
      expected_top_level_keys = [:reasoning_mode, :constraints, :goals, :facts, :rules, :inferences, :unification_stats]
      missing_keys = expected_top_level_keys - stats.keys
      
      unless missing_keys.empty?
        record_failure(test_name, "Missing expected top-level keys: #{missing_keys}")
        return
      end
      
      # Verify unification_stats has expected format
      unif_stats = stats[:unification_stats]
      expected_unif_keys = [:unification_attempts, :success_rate, :total_unification_time]
      
      missing_unif_keys = expected_unif_keys - unif_stats.keys
      unless missing_unif_keys.empty?
        record_failure(test_name, "Missing expected unification stats keys: #{missing_unif_keys}")
        return
      end
      
      record_success(test_name, "Data format matches reasoning coordinator expectations")
      
    rescue => e
      record_failure(test_name, "Data format validation failed: #{e.message}")
    end
  end

  def test_performance_tracking
    test_name = "Performance metrics are tracked correctly"
    
    begin
      engine = UnificationEngine.new
      
      # Perform some unifications to generate metrics
      var_x = TypeVariable.new("X")
      var_y = TypeVariable.new("Y")
      substitution = {}
      
      # Test successful unification
      result1 = engine.unify(var_x, :atom, substitution)
      
      # Test another unification
      substitution2 = {}
      result2 = engine.unify(:atom, :atom, substitution2)
      
      # Test failed unification
      substitution3 = {}
      begin
        result3 = engine.unify(:atom, :different_atom, substitution3)
      rescue
        # Expected to fail - that's okay
      end
      
      stats = engine.statistics
      
      # Verify metrics were recorded
      unless stats[:unification_attempts] >= 2
        record_failure(test_name, "Expected at least 2 unification attempts, got #{stats[:unification_attempts]}")
        return
      end
      
      unless stats[:total_unification_time] > 0
        record_failure(test_name, "Expected positive total unification time, got #{stats[:total_unification_time]}")
        return
      end
      
      unless stats[:success_rate].is_a?(Numeric)
        record_failure(test_name, "Success rate should be numeric, got #{stats[:success_rate].class}")
        return
      end
      
      record_success(test_name, "Performance tracking working: #{stats[:unification_attempts]} attempts, #{stats[:success_rate]}% success rate")
      
    rescue => e
      record_failure(test_name, "Performance tracking failed: #{e.message}")
    end
  end

  def record_success(test_name, details)
    @test_results << { status: :success, test: test_name, details: details }
    puts "✅ PASS: #{test_name}"
    puts "   #{details}"
    puts
  end

  def record_failure(test_name, error_msg)
    @test_results << { status: :failure, test: test_name, error: error_msg }
    @errors << "#{test_name}: #{error_msg}"
    puts "❌ FAIL: #{test_name}"
    puts "   ERROR: #{error_msg}"
    puts
  end

  def print_results
    puts "=" * 60
    puts "VALIDATION RESULTS SUMMARY"
    puts "=" * 60
    
    total_tests = @test_results.length
    successful_tests = @test_results.count { |r| r[:status] == :success }
    failed_tests = @test_results.count { |r| r[:status] == :failure }
    
    puts "Total Tests: #{total_tests}"
    puts "Passed: #{successful_tests}"
    puts "Failed: #{failed_tests}"
    puts "Success Rate: #{total_tests > 0 ? (successful_tests.to_f / total_tests * 100).round(1) : 0}%"
    puts
    
    if failed_tests > 0
      puts "FAILED TESTS:"
      @errors.each_with_index do |error, i|
        puts "#{i + 1}. #{error}"
      end
      puts
    end
    
    if failed_tests == 0
      puts "🎉 ALL TESTS PASSED! Statistics integration is working correctly."
      puts "✅ UnificationEngine.statistics method implemented and functional"
      puts "✅ TypeConstraintSystem.constraint_count method implemented and functional" 
      puts "✅ ReasoningCoordinator integration working without missing method errors"
      puts "✅ Performance metrics are being tracked properly"
      true
    else
      puts "❌ INTEGRATION VALIDATION FAILED"
      puts "Some statistics methods are still missing or not working properly."
      false
    end
  end
end

# Run the validation
if __FILE__ == $0
  validator = StatisticsIntegrationValidator.new
  success = validator.run_validation
  exit(success ? 0 : 1)
end