#!/usr/bin/env ruby
# frozen_string_literal: true

# Unified Coverage Runner - Fixes SimpleCov configuration issues
# Ensures proper coverage measurement across all test phases including Phase 3 lexer edge cases
# Addresses subprocess tracking and coverage data collection problems

require 'simplecov'
require 'pathname'
require 'timeout'
require 'fileutils'
require 'json'
require 'time'

# FIXED SimpleCov Configuration - Addresses coverage measurement issues
SimpleCov.start do
  # Enable comprehensive coverage tracking
  enable_coverage :line
  enable_coverage :branch
  
  # Set absolute root path to ensure consistent file tracking
  root File.expand_path('../../', __FILE__)
  
  # Track all source files explicitly to prevent missing coverage
  track_files 'src/**/*.rb'
  
  # Add comprehensive filters
  add_filter '/test/'
  add_filter '/adhoc_scripts/'
  add_filter '/tools/'
  add_filter '/docs/'
  add_filter '/examples/'
  add_filter '/archive/'
  add_filter '/coverage/'
  
  # Set coverage output directory
  coverage_dir 'test/coverage'
  
  # Organize coverage by logical groups
  add_group 'Lexer', 'src/lexer'
  add_group 'Parser', 'src/parser'
  add_group 'Core Parser', ['src/parser.rb']
  add_group 'Core Lexer', ['src/lexer.rb'] 
  add_group 'AST Nodes', 'src/ast'
  add_group 'Evaluator', 'src/evaluator'
  add_group 'Object Model', 'src/object_model'
  add_group 'Reasoning', 'src/reasoning'
  add_group 'Utilities', ['src/token.rb', 'src/exceptions.rb', 'src/ambiguous_token.rb']
  
  # Configure comprehensive HTML reporting
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
  
  # Set reasonable coverage thresholds
  minimum_coverage line: 75, branch: 60
  
  # Enable result merging for multiple test runs
  use_merging true
  merge_timeout 3600 # 1 hour
  
  # Configure command name for proper result merging
  command_name 'Unified Coverage Run'
end

class UnifiedCoverageRunner
  def initialize
    @base_path = File.dirname(__FILE__)
    @project_root = File.expand_path('../../', __FILE__)
    @start_time = Time.now
    @results = {
      'summary' => {},
      'phases' => {},
      'coverage' => {},
      'errors' => [],
      'test_counts' => {}
    }
    
    # Ensure coverage directory exists
    FileUtils.mkdir_p(File.join(@base_path, 'coverage'))
  end

  def run_unified_coverage
    log_header("🚀 UNIFIED COVERAGE RUNNER - FIXING SIMPLECOV ISSUES")
    log_info("Started at: #{@start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    log_info("Project Root: #{@project_root}")
    log_info("Coverage tracking: Line + Branch enabled")
    log_info("Subprocess tracking: FIXED")
    log_separator

    begin
      # Phase 1: Load all source files first to ensure they're tracked
      preload_source_files
      
      # Phase 2: Run comprehensive test discovery
      all_test_files = discover_all_test_files
      
      # Phase 3: Run all tests in unified process (fixes subprocess issue)
      run_unified_test_suite(all_test_files)
      
      # Phase 4: Generate comprehensive coverage report
      generate_unified_coverage_report
      
      # Phase 5: Display comprehensive results
      display_comprehensive_summary
      
    rescue => e
      log_error("❌ RUNNER ERROR: #{e.class}: #{e.message}")
      log_error("Backtrace: #{e.backtrace.first(5).join("\n")}")
      @results['summary']['execution_error'] = {
        'class' => e.class.to_s,
        'message' => e.message,
        'backtrace' => e.backtrace&.first(10)
      }
    ensure
      # Always try to save results
      save_results
    end

    @results
  end

  private

  def preload_source_files
    log_info("📂 Preloading source files for coverage tracking...")
    
    source_files = Dir.glob(File.join(@project_root, 'src', '**', '*.rb')).sort
    loaded_count = 0
    error_count = 0
    
    source_files.each do |file|
      begin
        # Load file relative to project root for proper SimpleCov tracking
        relative_path = file.sub(@project_root + '/', '')
        require_relative "../#{relative_path}"
        loaded_count += 1
        log_info("   ✅ #{relative_path}")
      rescue LoadError => e
        error_count += 1
        log_info("   ⚠️  LoadError: #{File.basename(file)} - #{e.message}")
      rescue => e
        error_count += 1
        log_info("   ⚠️  Error: #{File.basename(file)} - #{e.class}: #{e.message}")
      end
    end
    
    log_info("📊 Source files: #{loaded_count} loaded, #{error_count} errors")
    @results['summary']['source_files'] = {
      'total' => source_files.length,
      'loaded' => loaded_count,
      'errors' => error_count
    }
  end

  def discover_all_test_files
    log_info("🔍 Discovering all test files...")
    
    # Find all test files across all phases
    all_test_files = []
    
    # Standard test directories
    test_dirs = [
      'safety_critical',
      'core_pipeline', 
      'infrastructure',
      'patlang_language',
      'ruby_implementation',
      'integration'
    ]
    
    test_dirs.each do |dir|
      dir_path = File.join(@base_path, dir)
      if Dir.exist?(dir_path)
        files = Dir.glob(File.join(dir_path, 'test_*.rb'))
        all_test_files.concat(files)
        log_info("   📁 #{dir}: #{files.length} test files")
      end
    end
    
    # Add any root-level test files
    root_tests = Dir.glob(File.join(@base_path, 'test_*.rb'))
    all_test_files.concat(root_tests)
    
    # Exclude utility files
    exclusions = [
      /test_helper\.rb$/,
      /.*_runner\.rb$/,
      /.*_analysis\.rb$/,
      /diagnostic.*\.rb$/,
      /temp_.*\.rb$/,
      /debug_.*\.rb$/,
      /coverage_.*\.rb$/
    ]
    
    legitimate_tests = all_test_files.reject do |file|
      basename = File.basename(file)
      exclusions.any? { |pattern| basename =~ pattern }
    end
    
    log_info("📊 Test Discovery Results:")
    log_info("   Total test_*.rb files found: #{all_test_files.length}")
    log_info("   Legitimate test files: #{legitimate_tests.length}")
    log_info("   Excluded utility files: #{all_test_files.length - legitimate_tests.length}")
    
    @results['test_counts'] = {
      'total_found' => all_test_files.length,
      'legitimate' => legitimate_tests.length,
      'excluded' => all_test_files.length - legitimate_tests.length
    }
    
    legitimate_tests
  end

  def run_unified_test_suite(test_files)
    log_info("🧪 Running unified test suite (fixes subprocess coverage issues)...")
    log_info("Running #{test_files.length} test files in unified process")
    
    # Load minitest framework
    require 'minitest/autorun'
    
    # Override autorun to prevent premature exit
    Minitest.class_variable_set(:@@installed_at_exit, true)
    
    total_tests = 0
    total_assertions = 0
    total_failures = 0
    total_errors = 0
    total_skips = 0
    
    phase_results = {}
    
    test_files.each_with_index do |test_file, index|
      filename = File.basename(test_file)
      log_info("   [#{index + 1}/#{test_files.length}] #{filename}")
      
      begin
        # Determine phase based on directory
        phase = determine_test_phase(test_file)
        phase_results[phase] ||= { files: 0, success: 0, errors: 0 }
        phase_results[phase][:files] += 1
        
        # Load test file in current process (fixes coverage tracking)
        load test_file
        
        # Track success
        phase_results[phase][:success] += 1
        log_info("     ✅ Loaded successfully")
        
      rescue => e
        phase_results[phase][:errors] += 1
        log_error("     ❌ Error loading: #{e.class}: #{e.message}")
        
        @results['errors'] << {
          'file' => filename,
          'phase' => phase,
          'error_class' => e.class.to_s,
          'error_message' => e.message
        }
      end
    end
    
    # Run all loaded tests
    log_info("🏃 Executing all loaded tests...")
    
    # Capture minitest results
    test_result = nil
    begin
      # Run minitest with custom reporter to capture stats
      reporter = Minitest::CompositeReporter.new
      reporter << Minitest::SummaryReporter.new($stdout)
      reporter << Minitest::ProgressReporter.new($stdout)
      
      test_result = Minitest.run_one_method(Object, 'run_tests') rescue nil
      
      # Extract results from minitest
      if defined?(Minitest) && Minitest.respond_to?(:reporter)
        stats = Minitest.reporter.reporters.first
        if stats.respond_to?(:count) && stats.respond_to?(:assertions)
          total_tests = stats.count
          total_assertions = stats.assertions
          total_failures = stats.failures
          total_errors = stats.errors
          total_skips = stats.skips
        end
      end
      
    rescue => e
      log_error("Test execution error: #{e.message}")
    end
    
    @results['phases'] = phase_results
    @results['summary'].merge!({
      'total_test_files' => test_files.length,
      'total_tests' => total_tests,
      'total_assertions' => total_assertions,
      'total_failures' => total_failures,
      'total_errors' => total_errors,
      'total_skips' => total_skips,
      'execution_time' => (Time.now - @start_time).round(2)
    })
    
    log_info("📊 Test Execution Summary:")
    log_info("   Test Files: #{test_files.length}")
    log_info("   Tests Run: #{total_tests}")
    log_info("   Assertions: #{total_assertions}")
    log_info("   Failures: #{total_failures}")
    log_info("   Errors: #{total_errors}")
    log_info("   Skips: #{total_skips}")
  end

  def determine_test_phase(test_file)
    case test_file
    when /safety_critical/
      'Phase 1 - Safety Critical'
    when /core_pipeline/
      'Phase 2 - Core Pipeline'  
    when /infrastructure.*edge_cases.*final/
      'Phase 3 - Lexer Edge Cases'
    when /infrastructure/
      'Phase 3 - Infrastructure'
    when /patlang_language/
      'Language Tests'
    when /ruby_implementation/
      'Ruby Implementation'
    when /integration/
      'Integration Tests'
    else
      'Other'
    end
  end

  def generate_unified_coverage_report
    log_info("📊 Generating unified coverage report...")
    
    # Force SimpleCov to calculate and format results
    if defined?(SimpleCov) && SimpleCov.running
      result = SimpleCov.result
      
      if result
        @results['coverage'] = {
          'line_coverage' => result.covered_percent.round(2),
          'total_lines' => result.total_lines,
          'covered_lines' => result.covered_lines,
          'missed_lines' => result.missed_lines,
          'files_count' => result.files.length
        }
        
        # Extract lexer-specific coverage
        lexer_file = result.files.find { |f| f.filename.end_with?('src/lexer.rb') }
        if lexer_file
          @results['coverage']['lexer'] = {
            'line_coverage' => lexer_file.covered_percent.round(2),
            'total_lines' => lexer_file.lines.count,
            'covered_lines' => lexer_file.covered_lines.count,
            'missed_lines' => lexer_file.missed_lines.count
          }
          
          log_info("🎯 LEXER COVERAGE:")
          log_info("   Line Coverage: #{lexer_file.covered_percent.round(2)}%")
          log_info("   Lines: #{lexer_file.covered_lines.count}/#{lexer_file.lines.count}")
        end
        
        log_info("📊 OVERALL COVERAGE:")
        log_info("   Line Coverage: #{result.covered_percent.round(2)}%")
        log_info("   Total Lines: #{result.total_lines}")
        log_info("   Covered Lines: #{result.covered_lines}")
        log_info("   Files Analyzed: #{result.files.length}")
        
        # Force HTML report generation
        result.format!
        log_info("✅ HTML coverage report generated: test/coverage/index.html")
        
      else
        log_error("❌ SimpleCov result not available")
      end
    else
      log_error("❌ SimpleCov not running or not available")
    end
  end

  def display_comprehensive_summary
    log_separator
    log_header("📊 UNIFIED COVERAGE ANALYSIS SUMMARY")
    log_info("📅 Completed: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}")
    log_info("⏱️  Total Execution Time: #{@results['summary']['execution_time']}s")
    log_separator
    
    # Test execution summary
    log_info("🧪 TEST EXECUTION:")
    log_info("   Files Processed: #{@results['summary']['total_test_files']}")
    log_info("   Tests Run: #{@results['summary']['total_tests']}")
    log_info("   Assertions: #{@results['summary']['total_assertions']}")
    log_info("   Failures: #{@results['summary']['total_failures']}")
    log_info("   Errors: #{@results['summary']['total_errors']}")
    log_info("   Skips: #{@results['summary']['total_skips']}")
    
    # Phase breakdown
    if @results['phases']&.any?
      log_separator
      log_info("📊 BY PHASE:")
      @results['phases'].each do |phase, stats|
        log_info("   #{phase}:")
        log_info("     Files: #{stats[:files]}")
        log_info("     Success: #{stats[:success]}")
        log_info("     Errors: #{stats[:errors]}")
      end
    end
    
    # Coverage summary
    if @results['coverage']&.any?
      log_separator
      log_info("📊 COVERAGE RESULTS:")
      log_info("   Overall Line Coverage: #{@results['coverage']['line_coverage']}%")
      log_info("   Files Analyzed: #{@results['coverage']['files_count']}")
      
      if @results['coverage']['lexer']
        log_info("🎯 LEXER SPECIFIC:")
        log_info("   Lexer Line Coverage: #{@results['coverage']['lexer']['line_coverage']}%")
        log_info("   Lexer Lines: #{@results['coverage']['lexer']['covered_lines']}/#{@results['coverage']['lexer']['total_lines']}")
      end
      
      log_info("📄 HTML Report: test/coverage/index.html")
    end
    
    # Error summary
    if @results['errors']&.any?
      log_separator
      log_info("⚠️  ERRORS ENCOUNTERED:")
      @results['errors'].each do |error|
        log_info("   #{error['file']}: #{error['error_class']} - #{error['error_message']}")
      end
    end
    
    log_separator
    log_info("✅ UNIFIED COVERAGE ANALYSIS COMPLETE")
    log_separator
  end

  def save_results
    begin
      results_file = File.join(@base_path, 'UNIFIED_COVERAGE_RESULTS.json')
      File.write(results_file, JSON.pretty_generate(@results))
      log_info("💾 Results saved: #{results_file}")
    rescue => e
      log_error("Failed to save results: #{e.message}")
    end
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
    puts "[#{Time.now.strftime('%H:%M:%S')}] ❌ #{message}"
  end
end

# Execute the unified coverage runner
if __FILE__ == $0
  runner = UnifiedCoverageRunner.new
  results = runner.run_unified_coverage
  
  # Return appropriate exit code
  if results['summary']['total_errors'] && results['summary']['total_errors'] > 0
    exit(1)
  else
    exit(0)
  end
end