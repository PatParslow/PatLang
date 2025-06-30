#!/usr/bin/env ruby
# Focused test runner to identify the 2 failing tests out of 225

require 'timeout'
require 'minitest/autorun'

$LOAD_PATH.unshift(File.expand_path('src', __dir__))
$LOAD_PATH.unshift(File.expand_path('test', __dir__))

class FailingTestIdentifier
  def initialize
    @failed_tests = []
    @test_count = 0
    @timeout_duration = 10 # seconds per test
  end
  
  def run_all_reasoning_tests
    puts "🔍 IDENTIFYING FAILING REASONING TESTS"
    puts "=" * 50
    
    test_files = [
      'test/infrastructure/test_unification_engine.rb',
      'test/infrastructure/test_reasoning_coordinator.rb', 
      'test/infrastructure/test_type_constraint_system.rb',
      'test/infrastructure/test_complex_logic_queries.rb',
      'test/infrastructure/test_goal_resolution_engine.rb',
      'test/ruby_implementation/test_reasoning_evaluator_integration.rb',
      'test/ruby_implementation/test_type_constraints.rb',
      'test/ruby_implementation/test_type_constraints_clean.rb',
      'test/ruby_implementation/test_goal_system.rb',
      'test/ruby_implementation/test_advanced_goal_strategies.rb',
      'test/integration/test_unified_reasoning_integration.rb'
    ]
    
    test_files.each do |test_file|
      run_test_file(test_file)
    end
    
    print_summary
  end
  
  private
  
  def run_test_file(test_file)
    unless File.exist?(test_file)
      puts "⚠️  #{File.basename(test_file)} - FILE NOT FOUND"
      return
    end
    
    puts "\n🧪 Testing #{File.basename(test_file)}"
    
    begin
      Timeout::timeout(@timeout_duration) do
        # Capture test results
        result = run_individual_test_file(test_file)
        analyze_result(test_file, result)
      end
    rescue Timeout::Error
      puts "   ⏰ TIMEOUT - Test file hung after #{@timeout_duration}s"
      @failed_tests << {
        file: File.basename(test_file),
        error: "Timeout after #{@timeout_duration}s",
        type: :timeout
      }
    rescue => e
      puts "   ❌ ERROR: #{e.message}"
      @failed_tests << {
        file: File.basename(test_file),
        error: e.message,
        type: :error
      }
    end
  end
  
  def run_individual_test_file(test_file)
    # Run the test file in a subprocess to isolate failures
    command = "ruby -Itest -Isrc #{test_file} 2>&1"
    output = `#{command}`
    exit_code = $?.exitstatus
    
    {
      output: output,
      exit_code: exit_code,
      success: exit_code == 0
    }
  end
  
  def analyze_result(test_file, result)
    if result[:success]
      # Extract test count and results from output
      if result[:output] =~ /(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/
        runs, assertions, failures, errors = $1.to_i, $2.to_i, $3.to_i, $4.to_i
        @test_count += runs
        
        if failures > 0 || errors > 0
          puts "   ❌ #{failures} failures, #{errors} errors out of #{runs} tests"
          @failed_tests << {
            file: File.basename(test_file),
            error: "#{failures} failures, #{errors} errors",
            type: :test_failure,
            details: extract_failure_details(result[:output])
          }
        else
          puts "   ✅ All #{runs} tests passed"
        end
      else
        puts "   ✅ Completed successfully"
      end
    else
      puts "   ❌ Exit code: #{result[:exit_code]}"
      @failed_tests << {
        file: File.basename(test_file),
        error: "Exit code #{result[:exit_code]}",
        type: :runtime_error,
        details: result[:output]
      }
    end
  end
  
  def extract_failure_details(output)
    # Extract failure details from minitest output
    failures = []
    current_failure = nil
    
    output.split("\n").each do |line|
      if line =~ /^\s*\d+\)\s*Failure:/
        current_failure = line.strip
      elsif current_failure && line =~ /Expected.*but was/
        failures << "#{current_failure}: #{line.strip}"
        current_failure = nil
      end
    end
    
    failures
  end
  
  def print_summary
    puts "\n" + "=" * 50
    puts "📊 TEST FAILURE ANALYSIS SUMMARY"
    puts "=" * 50
    
    puts "Total Tests Run: #{@test_count}"
    puts "Failed Test Files: #{@failed_tests.length}"
    
    if @failed_tests.any?
      puts "\n💥 FAILED TESTS:"
      @failed_tests.each_with_index do |failure, index|
        puts "\n#{index + 1}. #{failure[:file]}"
        puts "   Type: #{failure[:type]}"
        puts "   Error: #{failure[:error]}"
        
        if failure[:details] && failure[:details].is_a?(Array)
          failure[:details].each do |detail|
            puts "   Detail: #{detail}"
          end
        elsif failure[:details]
          puts "   Details: #{failure[:details][0..200]}#{'...' if failure[:details].length > 200}"
        end
      end
      
      puts "\n🎯 PHASE 1 COMPLETION STATUS:"
      puts "   ❌ 2+ test failures identified - Phase 1 incomplete"
      puts "   📋 Next: Fix identified failing tests"
      
    else
      puts "\n🎉 ALL REASONING TESTS PASSED!"
      puts "   ✅ Phase 1 appears complete - no failing tests found"
      puts "   📋 Next: Performance optimization and caching"
    end
  end
end

# Run the test identifier
if __FILE__ == $0
  identifier = FailingTestIdentifier.new
  identifier.run_all_reasoning_tests
end