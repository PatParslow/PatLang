#!/usr/bin/env ruby

# Critical Error Assessment Script
# Assess current state and remaining critical errors

require 'json'
require 'fileutils'

class CriticalErrorAssessment
  def initialize
    @results = {
      timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
      total_tests: 0,
      passed: 0,
      failed: 0,
      errors: [],
      critical_errors: [],
      success_rate: 0
    }
  end

  def run_assessment
    puts "=== CRITICAL ERROR ASSESSMENT ==="
    puts "Assessing current state of 39 high-priority critical errors"
    
    # Step 1: Identify available test files
    discover_test_files
    
    # Step 2: Run systematic test execution
    execute_tests_systematically
    
    # Step 3: Categorize remaining errors
    categorize_errors
    
    # Step 4: Generate final report
    generate_assessment_report
  end

  private

  def discover_test_files
    puts "\n--- DISCOVERING TEST FILES ---"
    
    @test_files = []
    
    # Primary test directories
    test_dirs = [
      'test/ruby_implementation',
      'test/infrastructure', 
      'test/patlang_language',
      'test/integration'
    ]
    
    test_dirs.each do |dir|
      if Dir.exist?(dir)
        pattern = File.join(dir, 'test_*.rb')
        files = Dir.glob(pattern)
        @test_files.concat(files)
        puts "Found #{files.length} test files in #{dir}"
      end
    end
    
    @test_files.uniq!
    puts "Total test files discovered: #{@test_files.length}"
  end

  def execute_tests_systematically
    puts "\n--- EXECUTING TESTS SYSTEMATICALLY ---"
    
    @test_files.each do |test_file|
      execute_single_test(test_file)
    end
  end

  def execute_single_test(test_file)
    puts "Testing: #{File.basename(test_file)}"
    
    begin
      # Determine correct execution context
      test_dir = File.dirname(test_file)
      test_name = File.basename(test_file)
      
      # Create execution command
      if test_dir.include?('ruby_implementation')
        cmd = "cd #{test_dir} && ruby -I../../src #{test_name}"
      elsif test_dir.include?('infrastructure')
        cmd = "cd #{test_dir} && ruby -I../../src #{test_name}"
      elsif test_dir.include?('patlang_language')
        cmd = "cd #{test_dir} && ruby -I../../src #{test_name}"
      elsif test_dir.include?('integration')
        cmd = "cd #{test_dir} && ruby -I../../src #{test_name}"
      else
        cmd = "cd test && ruby -I../src #{test_name}"
      end
      
      # Execute test
      output = `#{cmd} 2>&1`
      success = $?.success?
      
      @results[:total_tests] += 1
      
      if success
        @results[:passed] += 1
        puts "  ✓ PASSED"
      else
        @results[:failed] += 1
        puts "  ✗ FAILED"
        
        # Capture error details
        error_info = {
          file: test_file,
          output: output.split("\n").first(5).join(" | "),
          category: determine_error_category(output)
        }
        
        @results[:errors] << error_info
        
        # Check if this is a critical error
        if is_critical_error?(output)
          @results[:critical_errors] << error_info
        end
      end
      
    rescue => e
      @results[:total_tests] += 1
      @results[:failed] += 1
      puts "  ✗ EXECUTION ERROR: #{e.message}"
      
      @results[:errors] << {
        file: test_file,
        error: e.message,
        category: 'execution_error'
      }
    end
  end

  def determine_error_category(output)
    case output
    when /NameError.*uninitialized constant/
      'ast_node_constants'
    when /NoMethodError.*unification/
      'unification_engine'
    when /ArgumentError.*string.*index/
      'string_indexing'
    when /TypeError.*constraint/
      'type_system'
    when /SyntaxError/
      'syntax_issues'
    when /LoadError/
      'dependencies'
    else
      'other'
    end
  end

  def is_critical_error?(output)
    critical_patterns = [
      /NameError.*uninitialized constant/,
      /NoMethodError.*unification/,
      /ArgumentError.*string.*index/,
      /TypeError.*constraint/,
      /stack level too deep/,
      /SystemStackError/
    ]
    
    critical_patterns.any? { |pattern| output.match?(pattern) }
  end

  def categorize_errors
    puts "\n--- CATEGORIZING REMAINING ERRORS ---"
    
    categories = @results[:errors].group_by { |e| e[:category] }
    
    categories.each do |category, errors|
      puts "#{category.upcase}: #{errors.length} errors"
      errors.first(3).each do |error|
        puts "  - #{File.basename(error[:file])}"
      end
    end
  end

  def generate_assessment_report
    puts "\n" + "="*60
    puts "CRITICAL ERROR ASSESSMENT REPORT"
    puts "="*60
    
    @results[:success_rate] = if @results[:total_tests] > 0
      (@results[:passed].to_f / @results[:total_tests] * 100).round(2)
    else
      0
    end
    
    puts "Total tests executed: #{@results[:total_tests]}"
    puts "Tests passed: #{@results[:passed]}"
    puts "Tests failed: #{@results[:failed]}"
    puts "Success rate: #{@results[:success_rate]}%"
    puts "Critical errors remaining: #{@results[:critical_errors].length}"
    
    # Analysis based on success rate
    if @results[:success_rate] >= 90
      puts "\n🎉 EXCELLENT: Critical errors have been largely resolved!"
      puts "   #{@results[:success_rate]}% success rate achieved"
    elsif @results[:success_rate] >= 80
      puts "\n✅ VERY GOOD: Most critical errors have been resolved"
      puts "   #{@results[:success_rate]}% success rate achieved"
    elsif @results[:success_rate] >= 70
      puts "\n⚠️  GOOD PROGRESS: Significant critical error reduction achieved"
      puts "   #{@results[:success_rate]}% success rate achieved"
    else
      puts "\n❌ MORE WORK NEEDED: Additional critical errors require attention"
      puts "   #{@results[:success_rate]}% success rate achieved"
    end
    
    # Remaining issues breakdown
    if @results[:critical_errors].any?
      puts "\n--- REMAINING CRITICAL ERRORS ---"
      @results[:critical_errors].each_with_index do |error, i|
        puts "#{i+1}. #{File.basename(error[:file])}: #{error[:category]}"
      end
    end
    
    # Save detailed results
    File.write('critical_error_assessment_results.json', JSON.pretty_generate(@results))
    puts "\nDetailed results saved to critical_error_assessment_results.json"
    
    @results
  end
end

# Execute assessment
if __FILE__ == $0
  assessor = CriticalErrorAssessment.new
  results = assessor.run_assessment
  
  puts "\n=== TASK COMPLETION STATUS ==="
  if results[:success_rate] >= 80
    puts "✅ TASK SUBSTANTIALLY COMPLETED"
    puts "   Critical errors have been significantly reduced"
    puts "   #{results[:critical_errors].length} critical errors remain out of original 39"
  else
    puts "⚠️  TASK PARTIALLY COMPLETED" 
    puts "   Additional work needed on remaining critical errors"
    puts "   #{results[:critical_errors].length} critical errors still need attention"
  end
end