#!/usr/bin/env ruby

require 'minitest/autorun'
require 'json'
require 'timeout'

class ComprehensiveTestAnalysis
  def initialize
    @results = {
      timestamp: Time.now.to_s,
      total_tests: 0,
      total_assertions: 0,
      failures: [],
      errors: [],
      skipped: [],
      success_rate: 0.0,
      categorized_issues: {},
      priority_analysis: []
    }
  end

  def run_analysis
    puts "🔍 Starting comprehensive test suite analysis..."
    
    # Run all tests with detailed output capture
    start_time = Time.now
    
    begin
      # Use timeout to prevent infinite hangs
      Timeout.timeout(300) do
        test_output = `ruby -Ilib -Itest test/run_all_tests.rb 2>&1`
        parse_test_output(test_output)
      end
    rescue Timeout::Error
      puts "⚠️  Test execution timed out after 5 minutes"
      @results[:timeout] = true
    rescue StandardError => e
      puts "❌ Error running tests: #{e.message}"
      @results[:execution_error] = e.message
    end
    
    execution_time = Time.now - start_time
    @results[:execution_time] = execution_time
    
    analyze_patterns
    # Issue categorization handled in analyze_patterns
    calculate_priorities
    generate_report
    
    puts "✅ Analysis complete in #{execution_time.round(2)}s"
  end

  private

  def parse_test_output(output)
    puts "📊 Parsing test output..."
    
    # Extract basic statistics
    if output =~ /(\d+) runs?, (\d+) assertions?, (\d+) failures?, (\d+) errors?/
      @results[:total_tests] = $1.to_i
      @results[:total_assertions] = $2.to_i
      failure_count = $3.to_i
      error_count = $4.to_i
      
      @results[:success_rate] = ((@results[:total_tests] - failure_count - error_count).to_f / @results[:total_tests] * 100).round(2)
    end
    
    # Extract individual failures and errors
    extract_failures(output)
    extract_errors(output)
    
    # Look for specific patterns
    extract_patterns(output)
  end

  def extract_failures(output)
    current_failure = nil
    in_failure = false
    
    output.each_line do |line|
      if line =~ /^\s*\d+\)\s+Failure:/
        if current_failure
          @results[:failures] << current_failure
        end
        current_failure = { type: 'failure', message: line.strip, details: [] }
        in_failure = true
      elsif in_failure && line.strip.empty?
        in_failure = false
      elsif in_failure
        current_failure[:details] << line.strip if current_failure
      end
    end
    
    @results[:failures] << current_failure if current_failure
  end

  def extract_errors(output)
    current_error = nil
    in_error = false
    
    output.each_line do |line|
      if line =~ /^\s*\d+\)\s+Error:/
        if current_error
          @results[:errors] << current_error
        end
        current_error = { type: 'error', message: line.strip, details: [] }
        in_error = true
      elsif in_error && line.strip.empty?
        in_error = false
      elsif in_error
        current_error[:details] << line.strip if current_error
      end
    end
    
    @results[:errors] << current_error if current_error
  end

  def extract_patterns(output)
    @results[:patterns] = {
      load_errors: output.scan(/LoadError.*?$/i).uniq,
      name_errors: output.scan(/NameError.*?$/i).uniq,
      no_method_errors: output.scan(/NoMethodError.*?$/i).uniq,
      superclass_mismatches: output.scan(/superclass mismatch.*?$/i).uniq,
      missing_files: output.scan(/cannot load such file.*?$/i).uniq,
      infinite_loops: output.scan(/stack level too deep.*?$/i).uniq
    }
  end

  def analyze_patterns
    puts "🔍 Analyzing error patterns..."
    
    # Group similar errors
    @results[:categorized_issues] = {
      infrastructure: [],
      missing_dependencies: [],
      superclass_issues: [],
      method_errors: [],
      ast_node_issues: [],
      test_framework_issues: []
    }
    
    (@results[:failures] + @results[:errors]).each do |issue|
      categorize_issue(issue)
    end
  end

  def categorize_issue(issue)
    message = issue[:message].downcase
    details = issue[:details].join(' ').downcase
    
    case
    when message.include?('loaderror') || message.include?('cannot load')
      @results[:categorized_issues][:missing_dependencies] << issue
    when message.include?('nameerror') || message.include?('uninitialized constant')
      @results[:categorized_issues][:missing_dependencies] << issue
    when message.include?('superclass mismatch')
      @results[:categorized_issues][:superclass_issues] << issue
    when message.include?('nomethoderror') || message.include?('undefined method')
      @results[:categorized_issues][:method_errors] << issue
    when message.include?('ast') || message.include?('node')
      @results[:categorized_issues][:ast_node_issues] << issue
    when message.include?('assert') || message.include?('minitest')
      @results[:categorized_issues][:test_framework_issues] << issue
    else
      @results[:categorized_issues][:infrastructure] << issue
    end
  end

  def calculate_priorities
    puts "📋 Calculating priority rankings..."
    
    # Analyze impact and frequency
    @results[:priority_analysis] = [
      {
        category: 'Missing Dependencies',
        count: @results[:categorized_issues][:missing_dependencies].size,
        impact: 'High',
        blocking_tests: estimate_blocking_tests(:missing_dependencies),
        priority: 1
      },
      {
        category: 'Superclass Issues',
        count: @results[:categorized_issues][:superclass_issues].size,
        impact: 'Critical',
        blocking_tests: estimate_blocking_tests(:superclass_issues),
        priority: 1
      },
      {
        category: 'Method Errors',
        count: @results[:categorized_issues][:method_errors].size,
        impact: 'Medium',
        blocking_tests: estimate_blocking_tests(:method_errors),
        priority: 2
      },
      {
        category: 'AST Node Issues',
        count: @results[:categorized_issues][:ast_node_issues].size,
        impact: 'High',
        blocking_tests: estimate_blocking_tests(:ast_node_issues),
        priority: 1
      },
      {
        category: 'Test Framework Issues',
        count: @results[:categorized_issues][:test_framework_issues].size,
        impact: 'Low',
        blocking_tests: estimate_blocking_tests(:test_framework_issues),
        priority: 3
      }
    ].sort_by { |item| [item[:priority], -item[:count]] }
  end

  def estimate_blocking_tests(category)
    # Estimate how many tests are blocked by each category
    count = @results[:categorized_issues][category].size
    case category
    when :missing_dependencies, :superclass_issues
      count * 3  # These tend to cascade
    when :ast_node_issues
      count * 2  # Moderate cascade
    else
      count  # Direct impact only
    end
  end

  def generate_report
    puts "\n" + "="*80
    puts "🎯 COMPREHENSIVE TEST SUITE ANALYSIS REPORT"
    puts "="*80
    
    puts "\n📊 CURRENT TEST SUITE METRICS:"
    puts "• Total Tests: #{@results[:total_tests]}"
    puts "• Total Assertions: #{@results[:total_assertions]}"
    puts "• Failures: #{@results[:failures].size}"
    puts "• Errors: #{@results[:errors].size}"
    puts "• Success Rate: #{@results[:success_rate]}%"
    puts "• Execution Time: #{@results[:execution_time].round(2)}s"
    
    puts "\n🔍 ISSUE CATEGORIZATION:"
    @results[:categorized_issues].each do |category, issues|
      next if issues.empty?
      puts "• #{category.to_s.gsub('_', ' ').capitalize}: #{issues.size} issues"
    end
    
    puts "\n🎯 PRIORITY ANALYSIS:"
    @results[:priority_analysis].each_with_index do |priority, index|
      next if priority[:count] == 0
      puts "#{index + 1}. #{priority[:category]} (Priority #{priority[:priority]})"
      puts "   Count: #{priority[:count]}, Impact: #{priority[:impact]}"
      puts "   Estimated Blocking Tests: #{priority[:blocking_tests]}"
    end
    
    puts "\n🚨 CRITICAL PATTERNS DETECTED:"
    @results[:patterns].each do |pattern, instances|
      next if instances.empty?
      puts "• #{pattern.to_s.gsub('_', ' ').capitalize}: #{instances.size} instances"
      instances.first(2).each { |instance| puts "  - #{instance}" }
    end
    
    # Save detailed results
    File.write('comprehensive_test_analysis_results.json', JSON.pretty_generate(@results))
    puts "\n💾 Detailed results saved to: comprehensive_test_analysis_results.json"
  end
end

# Run the analysis
if __FILE__ == $0
  analyzer = ComprehensiveTestAnalysis.new
  analyzer.run_analysis
end