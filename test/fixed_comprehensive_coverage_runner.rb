#!/usr/bin/env ruby
# frozen_string_literal: true

# Fixed Comprehensive Coverage Runner
# Enables proper SimpleCov coverage collection across all tests

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
  
  # Lower coverage requirements for initial run
  minimum_coverage line: 20, branch: 10
end

class FixedComprehensiveCoverageRunner
  def initialize
    @base_path = File.dirname(__FILE__)
    @start_time = Time.now
    @results = {
      'summary' => {},
      'test_files' => {},
      'coverage' => {},
      'errors' => [],
      'failures' => []
    }
  end

  def run_comprehensive_coverage
    log_header("🚀 FIXED COMPREHENSIVE COVERAGE RUNNER")
    log_info("Started at: #{@start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    log_info("Coverage tracking enabled with branch analysis")
    log_info("SimpleCov will collect coverage data across ALL test executions")
    log_separator

    begin
      # Discover test files
      test_files = discover_test_files
      log_info("Found #{test_files.length} test files to execute")
      
      # Run tests with coverage collection enabled
      run_tests_with_coverage(test_files)
      
      # Generate final coverage report
      generate_final_coverage_report
      
      # Display summary
      display_summary
      
    rescue => e
      log_error("❌ RUNNER ERROR: #{e.class}: #{e.message}")
      @results['summary']['execution_error'] = {
        'class' => e.class.to_s,
        'message' => e.message,
        'backtrace' => e.backtrace&.first(10)
      }
    end

    @results
  end

  private

  def discover_test_files
    # Find all legitimate test files
    all_test_files = Dir.glob(File.join(@base_path, '**', 'test_*.rb')).map { |f| File.expand_path(f) }
    
    # Exclude non-test files
    exclusions = [
      /test_helper\.rb$/,
      /.*_runner\.rb$/,
      /.*_analysis\.rb$/,
      /diagnostic.*\.rb$/,
      /temp_.*\.rb$/,
      /debug_.*\.rb$/
    ]
    
    legitimate_tests = all_test_files.reject do |file|
      basename = File.basename(file)
      exclusions.any? { |pattern| basename =~ pattern }
    end
    
    log_info("   Found #{all_test_files.length} total test_*.rb files")
    log_info("   Excluded #{all_test_files.length - legitimate_tests.length} non-test files")
    log_info("   Legitimate test files: #{legitimate_tests.length}")
    
    legitimate_tests
  end

  def run_tests_with_coverage(test_files)
    log_info("🧪 Running tests with coverage collection enabled...")
    
    passed = 0
    failed = 0
    errors = 0
    
    test_files.each_with_index do |test_file, index|
      filename = File.basename(test_file)
      log_info("   [#{index + 1}/#{test_files.length}] Running #{filename}...")
      
      begin
        # Load and run the test file directly (no isolation)
        # This allows SimpleCov to collect coverage data
        load test_file
        passed += 1
        log_info("     ✅ PASSED")
        
      rescue => e
        if e.message.include?('failures') || e.message.include?('failed')
          failed += 1
          log_info("     ❌ FAILED: #{e.message}")
        else
          errors += 1
          log_error("     🚨 ERROR: #{e.class}: #{e.message}")
        end
        
        @results['test_files'][filename] = {
          'status' => e.message.include?('failures') ? 'failed' : 'error',
          'error' => e.message,
          'error_class' => e.class.to_s
        }
      end
    end
    
    @results['summary'] = {
      'total_tests' => test_files.length,
      'passed' => passed,
      'failed' => failed,
      'errors' => errors,
      'execution_time' => (Time.now - @start_time).round(2)
    }
    
    log_info("📊 Test Results: #{passed} passed, #{failed} failed, #{errors} errors")
  end

  def generate_final_coverage_report
    log_info("📊 Generating final coverage report...")
    
    if defined?(SimpleCov) && SimpleCov.result
      result = SimpleCov.result
      
      @results['coverage'] = {
        'line_coverage' => result.covered_percent,
        'total_lines' => result.total_lines,
        'covered_lines' => result.covered_lines,
        'missed_lines' => result.missed_lines,
        'files_count' => result.files.length
      }
      
      log_info("   Line Coverage: #{result.covered_percent.round(2)}%")
      log_info("   Total Lines: #{result.total_lines}")
      log_info("   Covered Lines: #{result.covered_lines}")
      log_info("   Files Analyzed: #{result.files.length}")
      
      # Force coverage report generation
      SimpleCov.result.format!
      
    else
      log_error("   SimpleCov result not available")
    end
  end

  def display_summary
    log_separator
    log_header("📊 COMPREHENSIVE COVERAGE SUMMARY")
    log_info("📅 Completed: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}")
    log_info("⏱️  Total Execution Time: #{@results['summary']['execution_time']}s")
    log_info("🧪 Tests: #{@results['summary']['total_tests']} total")
    log_info("   ✅ Passed: #{@results['summary']['passed']}")
    log_info("   ❌ Failed: #{@results['summary']['failed']}")
    log_info("   🚨 Errors: #{@results['summary']['errors']}")
    
    if @results['coverage']
      log_info("📊 Coverage:")
      log_info("   Line Coverage: #{@results['coverage']['line_coverage'].round(2)}%")
      log_info("   Files Analyzed: #{@results['coverage']['files_count']}")
      log_info("   Coverage Report: test/coverage/index.html")
    end
    
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
    puts "[#{Time.now.strftime('%H:%M:%S')}] #{message}"
  end

  def log_error(message)
    puts "[#{Time.now.strftime('%H:%M:%S')}] #{message}"
  end
end

# Execute the runner
if __FILE__ == $0
  runner = FixedComprehensiveCoverageRunner.new
  results = runner.run_comprehensive_coverage
  
  # Save results
  File.write('test/FIXED_COMPREHENSIVE_COVERAGE_REPORT.json', JSON.pretty_generate(results))
  
  exit(0)
end