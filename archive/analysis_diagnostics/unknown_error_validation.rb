#!/usr/bin/env ruby

# Unknown Error Epidemic Validation
# Tests if the applied fixes resolved the silent failures

require 'timeout'
require 'json'

class UnknownErrorValidation
  def initialize
    @test_results = {}
    @unknown_error_files = [
      # Infrastructure
      "test/infrastructure/test_reasoning_coordinator.rb",
      "test/infrastructure/test_type_constraint_parser.rb",
      
      # Ruby Implementation
      "test/ruby_implementation/test_evaluator_edge_cases.rb", 
      "test/ruby_implementation/test_evaluator_stress.rb",
      "test/ruby_implementation/test_function_evaluator.rb",
      "test/ruby_implementation/test_object_model_comprehensive.rb",
      "test/ruby_implementation/test_object_model_edge_cases.rb",
      "test/ruby_implementation/test_reasoning_evaluator_integration.rb",
      "test/ruby_implementation/test_string_operations.rb",
      "test/ruby_implementation/test_type_constraints.rb",
      
      # Patlang Language
      "test/patlang_language/test_evaluator.rb",
      "test/patlang_language/test_evaluator_error_handling.rb", 
      "test/patlang_language/test_function_integration.rb",
      "test/patlang_language/test_object_evaluation.rb",
      "test/patlang_language/test_type_constraint_syntax.rb",
      
      # Helpers
      "test/helpers/test_constants.rb"
    ]
  end

  def validate_all_fixes
    puts "🔍 VALIDATING UNKNOWN ERROR FIXES"
    puts "=" * 50
    puts "Testing #{@unknown_error_files.length} previously problematic files...\n"
    
    @unknown_error_files.each_with_index do |file, index|
      test_file_individually(file, index + 1)
    end
    
    generate_validation_report
  end

  private

  def test_file_individually(file, file_num)
    print "#{file_num.to_s.rjust(2)}/#{@unknown_error_files.length} Testing #{File.basename(file)}... "
    
    begin
      # Test with timeout protection
      result = Timeout::timeout(10) do
        test_output = `cd test && ruby #{file.sub('test/', '')} 2>&1`
        exit_status = $?.exitstatus
        
        {
          status: categorize_result(exit_status, test_output),
          exit_status: exit_status,
          output: test_output,
          has_output: !test_output.strip.empty?,
          completed: exit_status != nil
        }
      end
      
      @test_results[file] = result
      print_result_status(result[:status])
      
    rescue Timeout::Error
      @test_results[file] = {
        status: :timeout,
        exit_status: nil,
        output: "Timeout after 10s",
        has_output: false,
        completed: false
      }
      puts "⏰ TIMEOUT"
    rescue => e
      @test_results[file] = {
        status: :error,
        exit_status: nil,
        output: e.message,
        has_output: true,
        completed: false
      }
      puts "❌ ERROR"
    end
  end

  def categorize_result(exit_status, output)
    return :unknown_error if exit_status.nil?
    return :timeout if output.include?("timeout") || output.include?("Maximum iterations")
    return :success if exit_status == 0
    return :test_failures if exit_status == 1 && output.include?("Finished in")
    return :load_error if output.include?("LoadError") || output.include?("cannot load")
    return :name_error if output.include?("NameError") || output.include?("uninitialized constant")
    :other_error
  end

  def print_result_status(status)
    case status
    when :success
      puts "✅ SUCCESS"
    when :test_failures  
      puts "🟡 TEST FAILURES (but completes)"
    when :unknown_error
      puts "❌ STILL UNKNOWN ERROR"
    when :timeout
      puts "⏰ TIMEOUT"
    when :load_error
      puts "📁 LOAD ERROR"
    when :name_error
      puts "🏷️  NAME ERROR"
    else
      puts "❓ OTHER ERROR"
    end
  end

  def generate_validation_report
    puts "\n" + "=" * 60
    puts "🎯 VALIDATION REPORT"
    puts "=" * 60
    
    # Count results by status
    status_counts = @test_results.values.group_by { |r| r[:status] }.transform_values(&:length)
    
    puts "\n📊 RESULTS SUMMARY:"
    puts "   Total files tested: #{@test_results.length}"
    puts "   ✅ Success: #{status_counts[:success] || 0}"
    puts "   🟡 Test failures (but completes): #{status_counts[:test_failures] || 0}"
    puts "   ❌ Still unknown errors: #{status_counts[:unknown_error] || 0}"
    puts "   ⏰ Timeouts: #{status_counts[:timeout] || 0}"
    puts "   📁 Load errors: #{status_counts[:load_error] || 0}"
    puts "   🏷️  Name errors: #{status_counts[:name_error] || 0}"
    puts "   ❓ Other errors: #{status_counts[:other_error] || 0}"
    
    # Calculate improvement
    resolved_count = (status_counts[:success] || 0) + (status_counts[:test_failures] || 0)
    still_problematic = @test_results.length - resolved_count
    improvement_rate = (resolved_count.to_f / @test_results.length * 100).round(1)
    
    puts "\n🚀 IMPROVEMENT ANALYSIS:"
    puts "   Files now completing: #{resolved_count}/#{@test_results.length}"
    puts "   Success rate: #{improvement_rate}%"
    puts "   Still problematic: #{still_problematic}"
    
    if still_problematic > 0
      puts "\n❌ REMAINING ISSUES:"
      @test_results.each do |file, result|
        next if [:success, :test_failures].include?(result[:status])
        puts "   • #{File.basename(file)}: #{result[:status]}"
      end
    end
    
    puts "\n💡 NEXT STEPS:"
    if improvement_rate >= 80
      puts "   🎉 Major success! Most unknown errors resolved."
      puts "   🔧 Address remaining specific issues individually."
    elsif improvement_rate >= 50
      puts "   ✅ Good progress made on unknown error epidemic."
      puts "   🔧 Continue targeted fixes for remaining issues."
    else
      puts "   ⚠️  Limited improvement. May need deeper investigation."
      puts "   🔧 Consider alternative approaches for remaining issues."
    end
    
    # Save detailed results
    File.write("unknown_error_validation_results.json", JSON.pretty_generate(@test_results))
    puts "   📄 Detailed results saved to: unknown_error_validation_results.json"
  end
end

# Run validation
if __FILE__ == $0
  validator = UnknownErrorValidation.new
  validator.validate_all_fixes
end