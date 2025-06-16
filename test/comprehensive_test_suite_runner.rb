#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive Test Suite Runner with Coverage Reports
# Runs all test files, captures outputs, generates coverage reports, and provides detailed analysis

require 'simplecov'
require 'pathname'
require 'timeout'
require 'fileutils'
require 'json'
require 'time'

# Configure SimpleCov for comprehensive coverage analysis
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  add_filter '/adhoc_scripts/'
  add_filter '/tools/'
  
  track_files 'src/**/*.rb'
  
  # Create separate groups for better organization
  add_group 'Core Language', 'src/core'
  add_group 'Evaluator', 'src/evaluator'
  add_group 'Parser', 'src/parser'
  add_group 'Lexer', 'src/lexer'
  add_group 'Object Model', 'src/object_model'
  add_group 'Reasoning', 'src/reasoning'
  add_group 'Utilities', 'src/utils'
  
  # Multiple formatters for comprehensive reporting
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
  
  # Coverage requirements
  minimum_coverage line: 80, branch: 70
end

class ComprehensiveTestSuiteRunner
  def initialize
    @base_path = File.dirname(__FILE__)
    @start_time = Time.now
    @results = {
      'summary' => {},
      'categories' => {},
      'test_files' => {},
      'coverage' => {},
      'errors' => [],
      'failures' => [],
      'slow_tests' => [],
      'recommendations' => []
    }
    @timeout_threshold = 30 # seconds per test file
    @total_timeout = 600    # 10 minutes total
  end

  def run_comprehensive_suite
    log_header("🚀 COMPREHENSIVE TEST SUITE RUNNER")
    log_info("Started at: #{@start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    log_info("Coverage tracking enabled with branch analysis")
    log_info("Individual test timeout: #{@timeout_threshold}s")
    log_info("Total suite timeout: #{@total_timeout}s")
    log_separator

    begin
      Timeout::timeout(@total_timeout) do
        # Discover all test categories and files
        discover_test_structure
        
        # Run tests by category
        run_all_categories
        
        # Generate coverage report
        generate_coverage_analysis
        
        # Analyze results and generate recommendations
        analyze_results
        
        # Save comprehensive report
        save_comprehensive_report
        
        # Display final summary
        display_final_summary
      end
    rescue Timeout::Error
      log_error("🚨 TOTAL SUITE TIMEOUT: Test suite exceeded #{@total_timeout} seconds")
      @results['summary']['timeout'] = true
    rescue => e
      log_error("❌ SUITE EXECUTION ERROR: #{e.class}: #{e.message}")
      @results['summary']['execution_error'] = {
        'class' => e.class.to_s,
        'message' => e.message,
        'backtrace' => e.backtrace&.first(10)
      }
    end

    @results
  end

  private

  def discover_test_structure
    log_info("🔍 Discovering test structure...")
    
    # Define test categories based on directory structure
    categories = {
      'infrastructure' => File.join(@base_path, 'infrastructure'),
      'ruby_implementation' => File.join(@base_path, 'ruby_implementation'),
      'patlang_language' => File.join(@base_path, 'patlang_language'),
      'integration' => File.join(@base_path, 'integration'),
      'helpers' => File.join(@base_path, 'helpers'),
      'branch_coverage' => File.join(@base_path, 'branch_coverage'),
      'root_level' => @base_path
    }
    
    @test_categories = {}
    
    categories.each do |category, path|
      if File.directory?(path) || category == 'root_level'
        test_files = if category == 'root_level'
          # For root level, only get test files directly in test/ directory
          Dir.glob(File.join(path, 'test_*.rb')).select do |f|
            # Exclude files that are in subdirectories
            File.dirname(f) == path
          end
        else
          Dir.glob(File.join(path, 'test_*.rb'))
        end
        
        # Filter out runner files and helpers
        excluded_patterns = [
          /run_.*\.rb$/,
          /runner\.rb$/,
          /helper\.rb$/,
          /coverage.*\.rb$/,
          /analysis.*\.rb$/
        ]
        
        test_files = test_files.reject do |file|
          basename = File.basename(file)
          excluded_patterns.any? { |pattern| basename =~ pattern }
        end
        
        if test_files.any?
          @test_categories[category] = test_files.sort
          log_info("   #{category}: #{test_files.length} test files")
        end
      end
    end
    
    total_files = @test_categories.values.flatten.length
    log_info("📊 Total test files discovered: #{total_files}")
    log_separator
  end

  def run_all_categories
    log_info("🧪 Running tests by category...")
    
    total_passed = 0
    total_failed = 0
    total_errors = 0
    total_files = 0
    
    @test_categories.each do |category, test_files|
      log_info("📁 Category: #{category.upcase} (#{test_files.length} files)")
      
      category_result = run_category_tests(category, test_files)
      @results['categories'][category] = category_result
      
      total_files += test_files.length
      total_passed += category_result['passed']
      total_failed += category_result['failed']
      total_errors += category_result['errors']
      
      log_info("   Results: #{category_result['passed']} passed, #{category_result['failed']} failed, #{category_result['errors']} errors")
      log_separator
    end
    
    @results['summary'] = {
      'timestamp' => Time.now.iso8601,
      'total_files' => total_files,
      'total_passed' => total_passed,
      'total_failed' => total_failed,
      'total_errors' => total_errors,
      'success_rate' => total_files > 0 ? (total_passed.to_f / total_files * 100).round(1) : 0,
      'execution_time' => (Time.now - @start_time).round(2)
    }
  end

  def run_category_tests(category, test_files)
    result = {
      'passed' => 0,
      'failed' => 0,
      'errors' => 0,
      'test_files' => [],
      'execution_time' => 0
    }
    
    category_start = Time.now
    
    test_files.each do |test_file|
      file_result = run_single_test_file(test_file, category)
      
      @results['test_files'][File.basename(test_file)] = file_result
      result['test_files'] << file_result
      
      case file_result['status']
      when 'passed'
        result['passed'] += 1
      when 'failed'
        result['failed'] += 1
        @results['failures'] << file_result
      when 'error'
        result['errors'] += 1
        @results['errors'] << file_result
      end
      
      if file_result['execution_time'] > @timeout_threshold * 0.8
        @results['slow_tests'] << file_result
      end
    end
    
    result['execution_time'] = (Time.now - category_start).round(2)
    result
  end

  def run_single_test_file(test_file, category)
    filename = File.basename(test_file)
    relative_path = Pathname.new(test_file).relative_path_from(Pathname.new(@base_path)).to_s
    
    log_info("     🧪 Running #{filename}...")
    
    start_time = Time.now
    
    begin
      # Create isolated test execution
      output, error_output, exit_status = run_isolated_test(test_file)
      execution_time = (Time.now - start_time).round(3)
      
      status = if exit_status == 0 && error_output.strip.empty?
        'passed'
      elsif exit_status != 0 && contains_test_failures?(output)
        'failed'
      else
        'error'
      end
      
      {
        'file' => filename,
        'relative_path' => relative_path,
        'category' => category,
        'status' => status,
        'execution_time' => execution_time,
        'exit_status' => exit_status,
        'output' => output.length > 1000 ? output[0..1000] + "... (truncated)" : output,
        'error_output' => error_output.length > 1000 ? error_output[0..1000] + "... (truncated)" : error_output,
        'error_type' => status == 'error' ? classify_error_type(error_output) : nil
      }
    rescue Timeout::Error
      execution_time = (Time.now - start_time).round(3)
      {
        'file' => filename,
        'relative_path' => relative_path,
        'category' => category,
        'status' => 'timeout',
        'execution_time' => execution_time,
        'exit_status' => 124,
        'output' => '',
        'error_output' => "Test execution timed out after #{@timeout_threshold} seconds",
        'error_type' => 'timeout'
      }
    rescue => e
      execution_time = (Time.now - start_time).round(3)
      {
        'file' => filename,
        'relative_path' => relative_path,
        'category' => category,
        'status' => 'error',
        'execution_time' => execution_time,
        'exit_status' => 1,
        'output' => '',
        'error_output' => "Runner error: #{e.class}: #{e.message}",
        'error_type' => 'runner_error'
      }
    end
  end

  def run_isolated_test(test_file)
    # Create a temporary script to run the test in isolation
    script_content = create_isolated_test_script(test_file)
    script_path = File.join(@base_path, 'temp_test_runner.rb')
    
    begin
      File.write(script_path, script_content)
      
      # Run with timeout
      output = ""
      error_output = ""
      exit_status = nil
      
      Timeout::timeout(@timeout_threshold) do
        # Use Open3 to capture both stdout and stderr
        require 'open3'
        output, error_output, status = Open3.capture3("ruby #{script_path}")
        exit_status = status.exitstatus
      end
      
      [output, error_output, exit_status]
    ensure
      File.delete(script_path) if File.exist?(script_path)
    end
  end

  def create_isolated_test_script(test_file)
    <<~RUBY
      # Isolated test runner script
      begin
        # Set up load paths
        $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))
        $LOAD_PATH.unshift(File.dirname(__FILE__))
        
        # Suppress SimpleCov for individual test runs to avoid conflicts
        ENV['SIMPLECOV'] = 'false'
        
        # Load test helper if it exists
        helper_path = File.join(File.dirname(__FILE__), 'helpers', 'test_helper.rb')
        require helper_path if File.exist?(helper_path)
        
        # Load the specific test file
        load '#{test_file}'
        
      rescue LoadError => e
        puts "LOAD_ERROR: \#{e.message}"
        exit 1
      rescue SyntaxError => e
        puts "SYNTAX_ERROR: \#{e.message}"
        exit 1
      rescue => e
        puts "ERROR: \#{e.class}: \#{e.message}"
        e.backtrace&.each { |line| puts "  \#{line}" }
        exit 1
      end
    RUBY
  end

  def contains_test_failures?(output)
    output =~ /failures?|errors?/i && output =~ /minitest|test/i
  end

  def classify_error_type(error_output)
    case error_output
    when /syntax error/i then 'syntax_error'
    when /undefined method/i then 'undefined_method'
    when /uninitialized constant/i then 'uninitialized_constant'
    when /no such file to load|cannot load such file/i then 'load_error'
    when /wrong number of arguments/i then 'argument_error'
    when /name error/i then 'name_error'
    when /timeout/i then 'timeout'
    when /LOAD_ERROR/i then 'load_error'
    when /SYNTAX_ERROR/i then 'syntax_error'
    else 'unknown_error'
    end
  end

  def generate_coverage_analysis
    log_info("📊 Generating coverage analysis...")
    
    if defined?(SimpleCov) && SimpleCov.result
      result = SimpleCov.result
      
      @results['coverage'] = {
        'line_coverage' => result.covered_percent.round(2),
        'branch_coverage' => result.respond_to?(:branch_coverage_percent) ? result.branch_coverage_percent.round(2) : 'N/A',
        'total_lines' => result.total_lines,
        'covered_lines' => result.covered_lines,
        'missed_lines' => result.missed_lines,
        'files_analyzed' => result.files.length,
        'files_with_coverage' => result.files.count { |f| f.covered_percent > 0 }
      }
      
      # Identify files with low coverage
      low_coverage_files = result.files.select { |f| f.covered_percent < 50 }.map do |file|
        {
          'filename' => file.filename,
          'coverage_percent' => file.covered_percent.round(2),
          'lines_of_code' => file.lines_of_code,
          'missed_lines' => file.missed_lines
        }
      end
      
      @results['coverage']['low_coverage_files'] = low_coverage_files
      
      log_info("   Line coverage: #{@results['coverage']['line_coverage']}%")
      log_info("   Branch coverage: #{@results['coverage']['branch_coverage']}%")
      log_info("   Files analyzed: #{@results['coverage']['files_analyzed']}")
      log_info("   Low coverage files: #{low_coverage_files.length}")
    else
      log_warning("⚠️  Coverage analysis not available")
      @results['coverage'] = { 'error' => 'Coverage data not available' }
    end
  end

  def analyze_results
    log_info("🔍 Analyzing results and generating recommendations...")
    
    # Analyze error patterns
    error_patterns = Hash.new(0)
    (@results['errors'] + @results['failures']).each do |result|
      if result['error_type']
        error_patterns[result['error_type']] += 1
      end
    end
    
    # Generate recommendations
    recommendations = []
    
    # Coverage recommendations
    if @results['coverage']['line_coverage'] && @results['coverage']['line_coverage'] < 80
      recommendations << {
        'priority' => 'high',
        'category' => 'coverage',
        'description' => 'Line coverage is below 80%. Focus on adding tests for uncovered code.',
        'action' => 'Add tests for low-coverage files',
        'affected_files' => @results['coverage']['low_coverage_files']&.map { |f| f['filename'] }
      }
    end
    
    # Error pattern recommendations
    error_patterns.sort_by { |k, v| -v }.first(3).each do |error_type, count|
      recommendations << {
        'priority' => count >= 5 ? 'high' : 'medium',
        'category' => 'errors',
        'description' => "#{count} files have #{error_type.tr('_', ' ')} errors",
        'action' => get_error_fix_recommendation(error_type),
        'count' => count
      }
    end
    
    # Performance recommendations
    if @results['slow_tests'].length > 5
      recommendations << {
        'priority' => 'medium',
        'category' => 'performance',
        'description' => "#{@results['slow_tests'].length} tests are running slowly",
        'action' => 'Optimize slow test performance or increase timeout thresholds',
        'slow_test_count' => @results['slow_tests'].length
      }
    end
    
    @results['recommendations'] = recommendations
  end

  def get_error_fix_recommendation(error_type)
    case error_type
    when 'undefined_method'
      'Implement missing methods or fix method names'
    when 'uninitialized_constant'
      'Define missing constants or fix class/module names'
    when 'load_error'
      'Fix require paths or add missing files'
    when 'syntax_error'
      'Fix syntax errors in test files'
    when 'name_error'
      'Fix variable or method naming issues'
    when 'timeout'
      'Optimize hanging tests or increase timeout'
    else
      'Investigate and fix these errors'
    end
  end

  def save_comprehensive_report
    log_info("💾 Saving comprehensive test report...")
    
    # Save JSON report
    json_report_path = File.join(@base_path, 'COMPREHENSIVE_TEST_SUITE_REPORT.json')
    File.write(json_report_path, JSON.pretty_generate(@results))
    
    # Save human-readable report
    text_report_path = File.join(@base_path, 'COMPREHENSIVE_TEST_SUITE_REPORT.md')
    File.write(text_report_path, generate_markdown_report)
    
    log_info("   JSON report: #{json_report_path}")
    log_info("   Markdown report: #{text_report_path}")
  end

  def generate_markdown_report
    report = []
    report << "# Comprehensive Test Suite Report"
    report << ""
    report << "Generated: #{@results['summary']['timestamp']}"
    report << "Execution Time: #{@results['summary']['execution_time']}s"
    report << ""
    
    # Summary
    report << "## Executive Summary"
    report << ""
    summary = @results['summary']
    report << "- **Total Test Files**: #{summary['total_files']}"
    report << "- **Passed**: #{summary['total_passed']} (#{summary['success_rate']}%)"
    report << "- **Failed**: #{summary['total_failed']}"
    report << "- **Errors**: #{summary['total_errors']}"
    report << ""
    
    # Coverage
    if @results['coverage']['line_coverage']
      report << "## Coverage Analysis"
      report << ""
      cov = @results['coverage']
      report << "- **Line Coverage**: #{cov['line_coverage']}%"
      report << "- **Branch Coverage**: #{cov['branch_coverage']}%"
      report << "- **Files Analyzed**: #{cov['files_analyzed']}"
      report << "- **Low Coverage Files**: #{cov['low_coverage_files']&.length || 0}"
      report << ""
    end
    
    # Categories
    report << "## Results by Category"
    report << ""
    @results['categories'].each do |category, data|
      report << "### #{category.capitalize}"
      report << "- Passed: #{data['passed']}"
      report << "- Failed: #{data['failed']}"
      report << "- Errors: #{data['errors']}"
      report << "- Execution Time: #{data['execution_time']}s"
      report << ""
    end
    
    # Recommendations
    if @results['recommendations'].any?
      report << "## Recommendations"
      report << ""
      @results['recommendations'].each_with_index do |rec, index|
        report << "### #{index + 1}. #{rec['description']} (#{rec['priority']} priority)"
        report << "**Action**: #{rec['action']}"
        report << ""
      end
    end
    
    # Failed Tests
    if @results['failures'].any?
      report << "## Failed Tests"
      report << ""
      @results['failures'].each do |failure|
        report << "- **#{failure['file']}** (#{failure['category']})"
        report << "  - Status: #{failure['status']}"
        report << "  - Execution Time: #{failure['execution_time']}s"
        report << "  - Error: #{failure['error_output'][0..200]}..."
        report << ""
      end
    end
    
    # Error Tests
    if @results['errors'].any?
      report << "## Error Tests"
      report << ""
      @results['errors'].each do |error|
        report << "- **#{error['file']}** (#{error['category']})"
        report << "  - Error Type: #{error['error_type']}"
        report << "  - Execution Time: #{error['execution_time']}s"
        report << "  - Error: #{error['error_output'][0..200]}..."
        report << ""
      end
    end
    
    report.join("\n")
  end

  def display_final_summary
    log_separator
    log_header("📊 COMPREHENSIVE TEST SUITE SUMMARY")
    
    summary = @results['summary']
    log_info("📅 Completed: #{summary['timestamp']}")
    log_info("⏱️  Total Execution Time: #{summary['execution_time']}s")
    log_info("📁 Total Test Files: #{summary['total_files']}")
    log_info("✅ Passed: #{summary['total_passed']} (#{summary['success_rate']}%)")
    log_info("❌ Failed: #{summary['total_failed']}")
    log_info("🚨 Errors: #{summary['total_errors']}")
    
    if @results['coverage']['line_coverage']
      log_separator
      log_info("📊 COVERAGE ANALYSIS:")
      cov = @results['coverage']
      log_info("   Line Coverage: #{cov['line_coverage']}%")
      log_info("   Branch Coverage: #{cov['branch_coverage']}%")
      log_info("   Files with Low Coverage: #{cov['low_coverage_files']&.length || 0}")
    end
    
    if @results['recommendations'].any?
      log_separator
      log_info("🎯 TOP RECOMMENDATIONS:")
      @results['recommendations'].first(3).each_with_index do |rec, index|
        log_info("   #{index + 1}. [#{rec['priority'].upcase}] #{rec['description']}")
      end
    end
    
    if @results['slow_tests'].any?
      log_separator
      log_info("🐌 SLOW TESTS (>#{@timeout_threshold * 0.8}s):")
      @results['slow_tests'].first(5).each do |test|
        log_info("   #{test['file']}: #{test['execution_time']}s")
      end
    end
    
    log_separator
    log_info("📄 Detailed reports saved:")
    log_info("   - COMPREHENSIVE_TEST_SUITE_REPORT.json")
    log_info("   - COMPREHENSIVE_TEST_SUITE_REPORT.md")
    log_info("   - Coverage report: test/coverage/index.html")
    log_separator
  end

  def log_header(message)
    puts "=" * 80
    puts message.center(80)
    puts "=" * 80
  end

  def log_separator
    puts "-" * 60
  end

  def log_info(message)
    timestamp = Time.now.strftime("%H:%M:%S")
    puts "[#{timestamp}] #{message}"
  end

  def log_warning(message)
    timestamp = Time.now.strftime("%H:%M:%S")
    puts "[#{timestamp}] ⚠️  #{message}"
  end

  def log_error(message)
    timestamp = Time.now.strftime("%H:%M:%S")
    puts "[#{timestamp}] ❌ #{message}"
  end
end

# Main execution
if __FILE__ == $0
  runner = ComprehensiveTestSuiteRunner.new
  
  begin
    results = runner.run_comprehensive_suite
    
    # Determine exit code based on results
    if results['summary']['total_errors'] == 0 && results['summary']['total_failed'] == 0
      puts "🎉 All tests passed successfully!"
      exit 0
    else
      puts "⚠️  Some tests failed or had errors. Check the detailed reports."
      exit 1
    end
  rescue => e
    puts "❌ Test suite runner failed: #{e.class}: #{e.message}"
    puts "Backtrace:"
    e.backtrace&.each { |line| puts "  #{line}" }
    exit 2
  end
end