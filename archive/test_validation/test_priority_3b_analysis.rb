#!/usr/bin/env ruby

require 'timeout'

# Add current directory and test directory to load path
$LOAD_PATH.unshift(File.expand_path('.', __dir__))
$LOAD_PATH.unshift(File.expand_path('test', __dir__))
$LOAD_PATH.unshift(File.expand_path('src', __dir__))

class Priority3BAnalysis
  def initialize
    @test_results = []
    @failure_patterns = Hash.new(0)
    @error_categories = {
      parse_errors: [],
      runtime_errors: [],
      assertion_failures: [],
      timeouts: [],
      not_implemented: []
    }
  end

  def run_analysis
    puts "🔍 Priority 3B Analysis: Remaining Test Failures for 90%+ Pass Rate"
    puts "=" * 70
    
    # Run tests with detailed failure capture
    run_comprehensive_test_suite
    categorize_failures
    analyze_patterns
    prioritize_fixes
    generate_action_plan
  end

  private

  def run_comprehensive_test_suite
    puts "\n📊 Running comprehensive test suite analysis..."
    
    test_files = discover_test_files
    puts "Found #{test_files.length} test files"
    
    total_tests = 0
    passed_tests = 0
    failed_tests = 0
    
    test_files.each_with_index do |test_file, index|
      puts "\n[#{index + 1}/#{test_files.length}] Testing: #{test_file}"
      
      begin
        # Use timeout protection and capture detailed results
        result = run_single_test_file(test_file)
        
        total_tests += result[:total]
        passed_tests += result[:passed]
        failed_tests += result[:failed]
        
        @test_results << {
          file: test_file,
          total: result[:total],
          passed: result[:passed],
          failed: result[:failed],
          failures: result[:failures],
          errors: result[:errors]
        }
        
      rescue => e
        puts "❌ Error running #{test_file}: #{e.message}"
        @error_categories[:runtime_errors] << {
          file: test_file,
          error: e.message,
          type: 'test_execution_error'
        }
      end
    end
    
    current_pass_rate = (passed_tests.to_f / total_tests * 100).round(1)
    puts "\n📈 Current Test Statistics:"
    puts "   Total Tests: #{total_tests}"
    puts "   Passed: #{passed_tests}"
    puts "   Failed: #{failed_tests}"
    puts "   Pass Rate: #{current_pass_rate}%"
    puts "   Target: 90%+ (need #{(total_tests * 0.9).ceil - passed_tests} more passes)"
  end

  def run_single_test_file(test_file)
    require 'open3'
    
    cmd = "ruby -I. -Itest #{test_file}"
    stdout, stderr, status = Open3.capture3(cmd, timeout: 30)
    
    # Parse minitest output for detailed results
    parse_test_output(stdout, stderr, status.success?)
  rescue Timeout::Error
    {
      total: 1,
      passed: 0,
      failed: 1,
      failures: [],
      errors: [{ type: 'timeout', message: 'Test execution timeout' }]
    }
  end

  def parse_test_output(stdout, stderr, success)
    result = {
      total: 0,
      passed: 0,
      failed: 0,
      failures: [],
      errors: []
    }
    
    # Extract test counts from minitest output
    if stdout =~ /(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/
      runs, assertions, failures, errors = $1.to_i, $2.to_i, $3.to_i, $4.to_i
      result[:total] = runs
      result[:passed] = runs - failures - errors
      result[:failed] = failures + errors
    end
    
    # Extract specific failure details
    extract_failure_details(stdout, stderr, result)
    
    result
  end

  def extract_failure_details(stdout, stderr, result)
    # Parse specific error messages and failure patterns
    combined_output = "#{stdout}\n#{stderr}"
    
    # Look for common failure patterns
    if combined_output.include?('NotImplementedError')
      result[:errors] << { type: 'not_implemented', message: 'Feature not implemented' }
    end
    
    if combined_output.include?('ParseError')
      result[:errors] << { type: 'parse_error', message: 'Parsing failed' }
    end
    
    if combined_output.include?('Undefined variable')
      result[:errors] << { type: 'undefined_variable', message: 'Variable resolution failed' }
    end
    
    if combined_output.include?('NoMethodError')
      result[:errors] << { type: 'no_method', message: 'Method call failed' }
    end
    
    if combined_output.include?('assert_raises')
      result[:failures] << { type: 'assertion_mismatch', message: 'Expected exception not raised' }
    end
  end

  def categorize_failures
    puts "\n🏷️  Categorizing failures by type..."
    
    @test_results.each do |result|
      result[:errors].each do |error|
        case error[:type]
        when 'not_implemented'
          @error_categories[:not_implemented] << error.merge(file: result[:file])
        when 'parse_error'
          @error_categories[:parse_errors] << error.merge(file: result[:file])
        when 'timeout'
          @error_categories[:timeouts] << error.merge(file: result[:file])
        else
          @error_categories[:runtime_errors] << error.merge(file: result[:file])
        end
      end
      
      result[:failures].each do |failure|
        @error_categories[:assertion_failures] << failure.merge(file: result[:file])
      end
    end
    
    puts "   Parse Errors: #{@error_categories[:parse_errors].length}"
    puts "   Runtime Errors: #{@error_categories[:runtime_errors].length}"
    puts "   Assertion Failures: #{@error_categories[:assertion_failures].length}"
    puts "   Timeouts: #{@error_categories[:timeouts].length}"
    puts "   Not Implemented: #{@error_categories[:not_implemented].length}"
  end

  def analyze_patterns
    puts "\n🔍 Analyzing failure patterns..."
    
    # Group similar failures
    @error_categories.each do |category, errors|
      next if errors.empty?
      
      puts "\n#{category.upcase}:"
      error_groups = errors.group_by { |e| extract_pattern(e[:message]) }
      
      error_groups.each do |pattern, group|
        puts "   #{pattern}: #{group.length} occurrences"
        @failure_patterns[pattern] += group.length
      end
    end
  end

  def extract_pattern(message)
    # Extract common patterns from error messages
    return "Unknown error" if message.nil?
    
    case message
    when /Undefined variable: (\w+)/
      "Undefined variable pattern"
    when /ParseError.*Expected/
      "Parse expectation error"
    when /NoMethodError.*`(\w+)'/
      "Missing method: #{$1}"
    when /NotImplementedError/
      "Feature not implemented"
    when /assert_raises.*expected/
      "Exception assertion mismatch"
    else
      message.to_s.split(':').first || message.to_s[0..50]
    end
  end

  def prioritize_fixes
    puts "\n🎯 Prioritizing fixes by impact..."
    
    # Sort patterns by frequency (impact)
    sorted_patterns = @failure_patterns.sort_by { |pattern, count| -count }
    
    puts "\nTop failure patterns (by frequency):"
    sorted_patterns.first(10).each_with_index do |(pattern, count), index|
      puts "   #{index + 1}. #{pattern}: #{count} failures"
    end
  end

  def generate_action_plan
    puts "\n📋 Priority 3B Action Plan for 90%+ Pass Rate"
    puts "=" * 50
    
    # Calculate impact vs effort for top issues
    top_patterns = @failure_patterns.sort_by { |pattern, count| -count }.first(5)
    
    top_patterns.each_with_index do |(pattern, count), index|
      effort = estimate_effort(pattern)
      impact = count
      priority_score = impact.to_f / effort
      
      puts "\n#{index + 1}. #{pattern}"
      puts "   Failures: #{count}"
      puts "   Estimated Effort: #{effort}/5"
      puts "   Impact Score: #{priority_score.round(2)}"
      puts "   Recommendation: #{get_recommendation(pattern)}"
    end
    
    puts "\n🎯 Quick Wins (High Impact, Low Effort):"
    quick_wins = identify_quick_wins(top_patterns)
    quick_wins.each { |win| puts "   • #{win}" }
    
    puts "\n🔧 Implementation Strategy:"
    puts "   1. Focus on patterns affecting 3+ tests"
    puts "   2. Fix parser issues first (foundation)"
    puts "   3. Address variable resolution problems"
    puts "   4. Implement missing features selectively"
    puts "   5. Fix assertion mismatches last"
  end

  def estimate_effort(pattern)
    case pattern
    when /Parse expectation error/
      2  # Parser fixes are usually straightforward
    when /Undefined variable pattern/
      3  # Variable resolution medium complexity
    when /Missing method/
      2  # Method implementation usually simple
    when /Feature not implemented/
      4  # New features require more work
    when /Exception assertion mismatch/
      1  # Test expectation fixes are easy
    else
      3  # Default medium effort
    end
  end

  def get_recommendation(pattern)
    case pattern
    when /Parse expectation error/
      "Fix parser grammar rules"
    when /Undefined variable pattern/
      "Improve variable scoping/resolution"
    when /Missing method/
      "Implement missing methods"
    when /Feature not implemented/
      "Implement core features"
    when /Exception assertion mismatch/
      "Update test expectations"
    else
      "Investigate specific implementation"
    end
  end

  def identify_quick_wins(patterns)
    patterns.select do |pattern, count|
      effort = estimate_effort(pattern)
      count >= 3 && effort <= 2
    end.map { |pattern, count| "#{pattern} (#{count} fixes)" }
  end

  def discover_test_files
    # Get all test files, focusing on core functionality
    test_dirs = [
      'test/infrastructure',
      'test/patlang_language', 
      'test/ruby_implementation'
    ]
    
    test_files = []
    test_dirs.each do |dir|
      if Dir.exist?(dir)
        test_files.concat(Dir.glob("#{dir}/test_*.rb"))
      end
    end
    
    # Add individual test files from test root
    test_files.concat(Dir.glob('test/test_*.rb'))
    
    test_files.sort
  end
end

# Run the analysis
if __FILE__ == $0
  analysis = Priority3BAnalysis.new
  analysis.run_analysis
end