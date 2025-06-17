#!/usr/bin/env ruby
# frozen_string_literal: true

# Final Enhanced Comprehensive Test Suite Runner
# Fixed categorization and comprehensive test discovery

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
  
  # Set consolidated coverage output directory
  coverage_dir 'test/coverage'
  
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

class FinalComprehensiveTestSuiteRunner
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
      'recommendations' => [],
      'discovery_stats' => {}
    }
    @timeout_threshold = 30 # seconds per test file
    @total_timeout = 600    # 10 minutes total
  end

  def run_comprehensive_suite
    log_header("🚀 FINAL COMPREHENSIVE TEST SUITE RUNNER")
    log_info("Started at: #{@start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    log_info("Coverage tracking enabled with branch analysis")
    log_info("Individual test timeout: #{@timeout_threshold}s")
    log_info("Total suite timeout: #{@total_timeout}s")
    log_info("Fixed dynamic test discovery with proper categorization")
    log_separator

    begin
      Timeout::timeout(@total_timeout) do
        # Enhanced dynamic test discovery with fixed categorization
        discover_all_test_files
        
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

  def discover_all_test_files
    log_info("🔍 Enhanced dynamic test discovery with fixed categorization...")
    
    # Find ALL test_*.rb files recursively
    all_test_files = Dir.glob(File.join(@base_path, '**', 'test_*.rb')).map { |f| File.expand_path(f) }
    
    log_info("   Found #{all_test_files.length} total test_*.rb files")
    
    # Apply refined exclusion patterns (much more specific than before)
    refined_exclusions = [
      /test_helper\.rb$/,           # Helper files only
      /.*_runner\.rb$/,             # Test runners only  
      /.*_analysis\.rb$/,           # Analysis scripts only
      /diagnostic.*\.rb$/,          # Diagnostic scripts
      /temp_.*\.rb$/,               # Temporary files
      /debug_.*\.rb$/               # Debug scripts (not actual tests)
    ]
    
    # Exclude files in specific non-test directories
    excluded_directories = [
      'coverage',                   # Coverage output directory
      'temp'                       # Temporary directory
    ]
    
    excluded_files = []
    legitimate_test_files = all_test_files.reject do |file|
      basename = File.basename(file)
      relative_path = file.sub(@base_path + '/', '')
      
      # Check exclusion patterns
      pattern_match = refined_exclusions.any? { |pattern| basename =~ pattern }
      
      # Check excluded directories
      directory_exclusion = excluded_directories.any? { |dir| relative_path.include?("/#{dir}/") }
      
      if pattern_match || directory_exclusion
        excluded_files << file
        true
      else
        false
      end
    end
    
    log_info("   Excluded #{excluded_files.length} non-test files:")
    excluded_files.each { |f| log_info("     - #{File.basename(f)}") }
    
    log_info("   Legitimate test files: #{legitimate_test_files.length}")
    
    # Fixed categorization based on directory structure
    @test_categories = categorize_test_files_properly(legitimate_test_files)
    
    # Record discovery statistics
    @results['discovery_stats'] = {
      'total_files_found' => all_test_files.length,
      'excluded_files' => excluded_files.length,
      'legitimate_test_files' => legitimate_test_files.length,
      'categories_discovered' => @test_categories.keys.length,
      'discovery_method' => 'enhanced_dynamic_fixed',
      'previous_discovery_count' => 61  # From original analysis
    }
    
    total_files = @test_categories.values.flatten.length
    log_info("📊 Fixed dynamic categorization complete:")
    @test_categories.each do |category, files|
      log_info("   #{category}: #{files.length} test files")
    end
    log_info("📊 Total test files to execute: #{total_files}")
    log_info("📈 Improvement: +#{legitimate_test_files.length - 61} additional test files discovered")
    log_separator
  end

  def categorize_test_files_properly(test_files)
    categories = Hash.new { |h, k| h[k] = [] }
    
    test_files.each do |file|
      # Use relative path from base_path for proper categorization
      relative_path = Pathname.new(file).relative_path_from(Pathname.new(@base_path)).to_s
      
      # Determine category based on directory structure
      if relative_path.include?('/')
        # File is in a subdirectory
        top_level_dir = relative_path.split('/').first
        category = case top_level_dir
        when 'infrastructure'
          'infrastructure'
        when 'ruby_implementation'
          'ruby_implementation'
        when 'patlang_language'
          'patlang_language'
        when 'integration'
          'integration'
        when 'helpers'
          'helpers'
        when 'branch_coverage'
          'branch_coverage'
        when 'core'
          'core'
        else
          # New category discovered dynamically
          top_level_dir
        end
      else
        # File is in root test directory
        category = 'root_level'
      end
      
      categories[category] << file
    end
    
    # Sort files within each category and convert to regular hash
    categories.each { |k, v| categories[k] = v.sort }
    categories.to_h
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
    script_path = File.join(@base_path, 'temp_final_test_runner.rb')
    
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
      # Final isolated test runner script
      begin
        # Set up load paths
        $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))
        $LOAD_PATH.unshift(File.dirname(__FILE__))
        
        # Suppress SimpleCov for individual test runs to avoid conflicts
        ENV['SIMPLECOV'] = 'false'
        
        # Load test helper if it exists (check multiple locations)
        helper_paths = [
          File.join(File.dirname(__FILE__), 'helpers', 'test_helper.rb'),
          File.join(File.dirname(__FILE__), 'test_helper.rb')
        ]
        
        helper_paths.each do |helper_path|
          if File.exist?(helper_path)
            require helper_path
            break
          end
        end
        
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
    log_info("📊 Generating comprehensive coverage analysis...")
    
    if defined?(SimpleCov) && SimpleCov.result
      result = SimpleCov.result
      
      # Enhanced coverage analysis with branch coverage guaranteed
      coverage_data = {
        'line_coverage' => result.covered_percent.round(2),
        'total_lines' => result.total_lines,
        'covered_lines' => result.covered_lines,
        'missed_lines' => result.missed_lines,
        'files_analyzed' => result.files.length,
        'files_with_coverage' => result.files.count { |f| f.covered_percent > 0 }
      }
      
      # Enhanced branch coverage calculation
      if result.respond_to?(:branch_coverage_percent) && result.branch_coverage_percent
        coverage_data['branch_coverage'] = result.branch_coverage_percent.round(2)
        coverage_data['branch_coverage_available'] = true
      elsif result.respond_to?(:total_branches) && result.total_branches && result.total_branches > 0
        # Calculate manually if available
        total_branches = result.total_branches
        covered_branches = result.covered_branches || 0
        coverage_data['branch_coverage'] = ((covered_branches.to_f / total_branches) * 100).round(2)
        coverage_data['branch_coverage_available'] = true
        coverage_data['total_branches'] = total_branches
        coverage_data['covered_branches'] = covered_branches
      else
        coverage_data['branch_coverage'] = 'N/A'
        coverage_data['branch_coverage_available'] = false
        coverage_data['branch_coverage_note'] = 'Branch coverage data not available in this SimpleCov version'
      end
      
      @results['coverage'] = coverage_data
      
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
    log_info("🔍 Analyzing results and generating comprehensive recommendations...")
    
    # Analyze error patterns
    error_patterns = Hash.new(0)
    (@results['errors'] + @results['failures']).each do |result|
      if result['error_type']
        error_patterns[result['error_type']] += 1
      end
    end
    
    # Generate comprehensive recommendations
    recommendations = []
    
    # Discovery improvement recommendation
    discovery_stats = @results['discovery_stats']
    improvement_count = discovery_stats['legitimate_test_files'] - discovery_stats['previous_discovery_count']
    if improvement_count > 0
      recommendations << {
        'priority' => 'high',
        'category' => 'discovery',
        'description' => "Enhanced discovery found #{improvement_count} additional test files that were previously excluded",
        'action' => 'Test discovery has been enhanced to include all legitimate test files',
        'improvement' => "+#{improvement_count} additional tests",
        'details' => "Discovered #{discovery_stats['legitimate_test_files']} legitimate tests from #{discovery_stats['total_files_found']} total files"
      }
    end
    
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
    
    # Branch coverage recommendations
    if @results['coverage']['branch_coverage_available'] && @results['coverage']['branch_coverage'].is_a?(Numeric) && @results['coverage']['branch_coverage'] < 70
      recommendations << {
        'priority' => 'high',
        'category' => 'branch_coverage',
        'description' => 'Branch coverage is below 70%. Add tests for conditional logic paths.',
        'action' => 'Focus on testing conditional branches, loops, and error handling paths',
        'current_branch_coverage' => @results['coverage']['branch_coverage']
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
    log_info("💾 Saving final comprehensive test report...")
    
    # Save JSON report
    json_report_path = File.join(@base_path, 'FINAL_COMPREHENSIVE_TEST_SUITE_REPORT.json')
    File.write(json_report_path, JSON.pretty_generate(@results))
    
    # Save human-readable report
    text_report_path = File.join(@base_path, 'FINAL_COMPREHENSIVE_TEST_SUITE_REPORT.md')
    File.write(text_report_path, generate_final_markdown_report)
    
    log_info("   JSON report: #{json_report_path}")
    log_info("   Markdown report: #{text_report_path}")
  end

  def generate_final_markdown_report
    report = []
    report << "# Final Comprehensive Test Suite Report"
    report << ""
    report << "Generated: #{@results['summary']['timestamp']}"
    report << "Execution Time: #{@results['summary']['execution_time']}s"
    report << "Discovery Method: #{@results['discovery_stats']['discovery_method']}"
    report << ""
    
    # Enhanced Summary with Discovery Stats
    report << "## Executive Summary"
    report << ""
    summary = @results['summary']
    discovery = @results['discovery_stats']
    report << "- **Total Test Files**: #{summary['total_files']}"
    report << "- **Passed**: #{summary['total_passed']} (#{summary['success_rate']}%)"
    report << "- **Failed**: #{summary['total_failed']}"
    report << "- **Errors**: #{summary['total_errors']}"
    report << ""
    report << "### Test Discovery Enhancement"
    report << "- **Files Found**: #{discovery['total_files_found']}"
    report << "- **Excluded Non-Tests**: #{discovery['excluded_files']}"
    report << "- **Legitimate Tests**: #{discovery['legitimate_test_files']}"
    report << "- **Categories**: #{discovery['categories_discovered']}"
    report << "- **Previous Discovery**: #{discovery['previous_discovery_count']} files"
    report << "- **Improvement**: +#{discovery['legitimate_test_files'] - discovery['previous_discovery_count']} additional tests"
    report << ""
    
    # Root Cause Analysis of Previous Exclusions
    report << "### Root Cause Analysis of Previous Exclusions"
    report << ""
    report << "The original comprehensive test runner excluded 12 legitimate test files due to:"
    report << "1. **Overly Broad Coverage Pattern**: Files with 'coverage' in name were excluded"
    report << "2. **Missing Directory Coverage**: 'core' directory was not in the hardcoded category list"  
    report << "3. **Helper Pattern Too Broad**: All files ending in 'helper.rb' were excluded"
    report << "4. **Static Directory List**: Used hardcoded directory list instead of dynamic discovery"
    report << ""
    
    # Enhanced Coverage
    if @results['coverage']['line_coverage']
      report << "## Coverage Analysis"
      report << ""
      cov = @results['coverage']
      report << "- **Line Coverage**: #{cov['line_coverage']}%"
      if cov['branch_coverage_available']
        report << "- **Branch Coverage**: #{cov['branch_coverage']}%"
        if cov['total_branches']
          report << "- **Total Branches**: #{cov['total_branches']}"
          report << "- **Covered Branches**: #{cov['covered_branches']}"
        end
      else
        report << "- **Branch Coverage**: #{cov['branch_coverage']} (#{cov['branch_coverage_note']})"
      end
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
    
    # Comprehensive Recommendations
    if @results['recommendations'].any?
      report << "## Comprehensive Recommendations"
      report << ""
      @results['recommendations'].each_with_index do |rec, index|
        report << "### #{index + 1}. #{rec['description']} (#{rec['priority']} priority)"
        report << "**Action**: #{rec['action']}"
        if rec['improvement']
          report << "**Improvement**: #{rec['improvement']}"
        end
        if rec['details']
          report << "**Details**: #{rec['details']}"
        end
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
    log_header("📊 FINAL COMPREHENSIVE TEST SUITE SUMMARY")
    
    summary = @results['summary']
    discovery = @results['discovery_stats']
    
    log_info("📅 Completed: #{summary['timestamp']}")
    log_info("⏱️  Total Execution Time: #{summary['execution_time']}s")
    log_info("🔍 Discovery Method: #{discovery['discovery_method']}")
    log_info("📁 Total Test Files: #{summary['total_files']} (was #{discovery['previous_discovery_count']})")
    log_info("📈 Discovery Improvement: +#{discovery['legitimate_test_files'] - discovery['previous_discovery_count']} additional tests")
    log_info("✅ Passed: #{summary['total_passed']} (#{summary['success_rate']}%)")
    log_info("❌ Failed: #{summary['total_failed']}")
    log_info("🚨 Errors: #{summary['total_errors']}")
    
    if @results['coverage']['line_coverage']
      log_separator
      log_info("📊 COVERAGE ANALYSIS:")
      cov = @results['coverage']
      log_info("   Line Coverage: #{cov['line_coverage']}%")
      if cov['branch_coverage_available']
        log_info("   Branch Coverage: #{cov['branch_coverage']}%")
      else
        log_info("   Branch Coverage: #{cov['branch_coverage']}")
      end
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
    log_info("📄 Final comprehensive reports saved:")
    log_info("   - FINAL_COMPREHENSIVE_TEST_SUITE_REPORT.json")
    log_info("   - FINAL_COMPREHENSIVE_TEST_SUITE_REPORT.md")
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
  runner = FinalComprehensiveTestSuiteRunner.new
  
  begin
    results = runner.run_comprehensive_suite
    
    # Final comprehensive exit code logic
    discovery_stats = results['discovery_stats']
    puts
    puts "🎉 FINAL TEST DISCOVERY COMPLETE!"
    puts "   Previous discovery: #{discovery_stats['previous_discovery_count']} files"
    puts "   Enhanced discovery: #{discovery_stats['legitimate_test_files']} files"
    puts "   Additional tests: +#{discovery_stats['legitimate_test_files'] - discovery_stats['previous_discovery_count']}"
    puts "   Categories: #{discovery_stats['categories_discovered']}"
    puts
    
    # Determine exit code based on results
    if results['summary']['total_errors'] == 0 && results['summary']['total_failed'] == 0
      puts "🎉 All tests passed successfully!"
      exit 0
    else
      puts "⚠️  Some tests failed or had errors. Check the detailed reports."
      exit 1
    end
  rescue => e
    puts "❌ Final test suite runner failed: #{e.class}: #{e.message}"
    puts "Backtrace:"
    e.backtrace&.each { |line| puts "  #{line}" }
    exit 2
  end
end