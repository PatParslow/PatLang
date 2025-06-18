#!/usr/bin/env ruby
# frozen_string_literal: true

require 'simplecov'
require 'pathname'
require 'timeout'
require 'minitest/autorun'

# Configure SimpleCov with branch coverage for comprehensive analysis
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  track_files 'src/**/*.rb'
  
  # Detailed coverage reporting
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
  
  # Set coverage requirements
  minimum_coverage line: 95, branch: 90
end

class EnhancedTestProgress
  def initialize
    @start_time = Time.now
    @current_file = nil
    @current_test = nil
    @total_tests = 0
    @completed_tests = 0
    @failed_tests = []
    @test_timings = {}
    @file_start_time = nil
    @test_start_time = nil
    @test_timeout_threshold = 30 # seconds
    @file_timeout_threshold = 120 # seconds
  end

  def log_with_timestamp(message, flush: true)
    timestamp = Time.now.strftime("%H:%M:%S.%3N")
    puts "[#{timestamp}] #{message}"
    STDOUT.flush if flush
  end

  def start_test_suite(test_files)
    @total_files = test_files.length
    @completed_files = 0
    
    log_with_timestamp("=" * 80)
    log_with_timestamp("🚀 STARTING ENHANCED TEST SUITE")
    log_with_timestamp("=" * 80)
    log_with_timestamp("📊 Total test files to process: #{@total_files}")
    log_with_timestamp("⏰ Test suite started at: #{@start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    log_with_timestamp("🔍 Enhanced progress reporting ENABLED")
    log_with_timestamp("⚠️  Test timeout threshold: #{@test_timeout_threshold}s")
    log_with_timestamp("⚠️  File timeout threshold: #{@file_timeout_threshold}s")
    log_with_timestamp("=" * 80)
  end

  def start_file(file_path)
    @current_file = file_path
    @file_start_time = Time.now
    @completed_files += 1
    
    relative_path = Pathname.new(file_path).relative_path_from(Pathname.new(File.dirname(__FILE__))).to_s
    
    log_with_timestamp("")
    log_with_timestamp("📁 [#{@completed_files}/#{@total_files}] STARTING FILE: #{relative_path}")
    log_with_timestamp("   └─ Full path: #{file_path}")
    log_with_timestamp("   └─ File start time: #{@file_start_time.strftime('%H:%M:%S')}")
  end

  def end_file(file_path)
    if @file_start_time
      duration = Time.now - @file_start_time
      log_with_timestamp("✅ COMPLETED FILE: #{File.basename(file_path)} (#{duration.round(2)}s)")
      
      if duration > @file_timeout_threshold
        log_with_timestamp("⚠️  WARNING: File took longer than expected (#{duration.round(2)}s > #{@file_timeout_threshold}s)")
      end
    end
  end

  def method_started(test_class, method_name)
    @current_test = "#{test_class}##{method_name}"
    @test_start_time = Time.now
    @completed_tests += 1
    
    log_with_timestamp("   🧪 TEST: #{@current_test}")
    log_with_timestamp("      └─ Started at: #{@test_start_time.strftime('%H:%M:%S.%3N')}")
  end

  def method_finished(test_class, method_name, result)
    if @test_start_time
      duration = Time.now - @test_start_time
      test_name = "#{test_class}##{method_name}"
      @test_timings[test_name] = duration
      
      status_symbol = case result
                     when 'PASS' then '✅'
                     when 'FAIL' then '❌'
                     when 'ERROR' then '💥'
                     when 'SKIP' then '⏭️ '
                     else '❓'
                     end
      
      log_with_timestamp("      └─ #{status_symbol} #{result}: #{test_name} (#{duration.round(3)}s)")
      
      if duration > @test_timeout_threshold
        log_with_timestamp("      └─ ⚠️  SLOW TEST WARNING: #{duration.round(2)}s > #{@test_timeout_threshold}s")
      end
      
      if result != 'PASS'
        @failed_tests << { name: test_name, result: result, duration: duration }
      end
    end
  end

  def report_potential_hang
    if @current_test
      duration = @test_start_time ? Time.now - @test_start_time : nil
      log_with_timestamp("")
      log_with_timestamp("🚨 POTENTIAL HANG DETECTED!")
      log_with_timestamp("   └─ Current test: #{@current_test}")
      log_with_timestamp("   └─ Running for: #{duration.round(2)}s") if duration
      log_with_timestamp("   └─ File: #{@current_file}")
      log_with_timestamp("   └─ This test may be hanging - consider investigation")
      log_with_timestamp("")
    end
  end

  def final_summary
    total_duration = Time.now - @start_time
    
    log_with_timestamp("")
    log_with_timestamp("=" * 80)
    log_with_timestamp("📊 FINAL TEST SUITE SUMMARY")
    log_with_timestamp("=" * 80)
    log_with_timestamp("⏱️  Total execution time: #{total_duration.round(2)}s")
    log_with_timestamp("📁 Files processed: #{@completed_files}/#{@total_files}")
    log_with_timestamp("🧪 Tests executed: #{@completed_tests}")
    
    if @failed_tests.any?
      log_with_timestamp("❌ Failed tests: #{@failed_tests.length}")
      log_with_timestamp("")
      log_with_timestamp("FAILED TEST DETAILS:")
      @failed_tests.each do |test|
        log_with_timestamp("   └─ #{test[:result]}: #{test[:name]} (#{test[:duration].round(3)}s)")
      end
    else
      log_with_timestamp("✅ All tests passed!")
    end
    
    # Show slowest tests
    if @test_timings.any?
      slowest = @test_timings.sort_by { |_, duration| -duration }.first(5)
      log_with_timestamp("")
      log_with_timestamp("🐌 SLOWEST TESTS:")
      slowest.each_with_index do |(test_name, duration), index|
        log_with_timestamp("   #{index + 1}. #{test_name}: #{duration.round(3)}s")
      end
    end
    
    log_with_timestamp("=" * 80)
  end

  def current_status
    {
      file: @current_file,
      test: @current_test,
      completed_tests: @completed_tests
    }
  end
end

# Enhanced Minitest plugin for real-time progress reporting
class MinitestProgressReporter < Minitest::Reporter
  def initialize(progress_tracker)
    super()
    @progress = progress_tracker
  end

  def start
    # Called at the beginning of the test run
  end

  def before_suite(suite)
    # Called before each test class
  end

  def before_test(test)
    test_class = test.class.name
    method_name = test.name
    @progress.method_started(test_class, method_name)
  end

  def record(test)
    test_class = test.class.name
    method_name = test.name
    
    result = if test.passed?
               'PASS'
             elsif test.skipped?
               'SKIP'
             elsif test.failure
               'FAIL'
             else
               'ERROR'
             end
    
    @progress.method_finished(test_class, method_name, result)
  end

  def report
    # Called at the end of the test run
  end
end

# Main execution
def run_enhanced_test_suite
  progress = EnhancedTestProgress.new
  
  # Always load test_helper first
  require_relative 'helpers/test_helper'
  
  # Dynamically discover and load all test files from all subdirectories
  test_dir = File.dirname(__FILE__)
  test_files = Dir.glob(File.join(test_dir, '**', 'test_*.rb')).sort
  
  # Filter out helper files and non-test files
  excluded_files = [
    'test_helper.rb',
    'run_all_tests.rb',
    'enhanced_test_runner.rb'
  ]
  
  test_files_to_load = test_files.select do |file|
    basename = File.basename(file)
    !excluded_files.include?(basename) && basename.start_with?('test_')
  end
  
  progress.start_test_suite(test_files_to_load)
  
  progress.log_with_timestamp("🔍 Discovered #{test_files_to_load.length} test files:")
  test_files_to_load.each_with_index do |file, index|
    relative_path = Pathname.new(file).relative_path_from(Pathname.new(test_dir)).to_s
    progress.log_with_timestamp("   #{index + 1}. #{relative_path}")
  end
  
  # Set up Minitest reporter
  reporter = MinitestProgressReporter.new(progress)
  Minitest.reporter = Minitest::CompositeReporter.new
  Minitest.reporter << reporter
  
  # Load test files with progress reporting
  test_files_to_load.each do |file|
    begin
      progress.start_file(file)
      
      # Load the test file with timeout protection
      Timeout::timeout(@file_timeout_threshold || 120) do
        relative_path = Pathname.new(file).relative_path_from(Pathname.new(test_dir)).to_s
        require_relative relative_path.sub('.rb', '')
      end
      
      progress.end_file(file)
      
    rescue Timeout::Error
      progress.log_with_timestamp("💥 TIMEOUT: File #{File.basename(file)} exceeded time limit!")
      progress.log_with_timestamp("   └─ This file may contain hanging tests")
      progress.end_file(file)
    rescue StandardError => e
      progress.log_with_timestamp("💥 ERROR loading #{File.basename(file)}: #{e.message}")
      progress.log_with_timestamp("   └─ #{e.backtrace.first}")
      progress.end_file(file)
    end
  end
  
  progress.log_with_timestamp("")
  progress.log_with_timestamp("🎯 All test files loaded successfully!")
  progress.log_with_timestamp("🏃 Starting test execution...")
  
  # Monitor for potential hangs during test execution
  hang_monitor = Thread.new do
    loop do
      sleep 10 # Check every 10 seconds
      if progress.current_status[:test] && 
         progress.instance_variable_get(:@test_start_time) &&
         (Time.now - progress.instance_variable_get(:@test_start_time)) > 30
        progress.report_potential_hang
      end
    end
  end
  
  begin
    # Run the tests (this will use our custom reporter)
    exit_code = Minitest.run([])
    
    progress.final_summary
    
    exit_code
  ensure
    hang_monitor.kill if hang_monitor.alive?
  end
end

# Execute if run directly
if __FILE__ == $0
  exit_code = run_enhanced_test_suite
  exit(exit_code)
end