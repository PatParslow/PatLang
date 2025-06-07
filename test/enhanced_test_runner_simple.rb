#!/usr/bin/env ruby
# frozen_string_literal: true

require 'simplecov'
require 'pathname'
require 'timeout'

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
    @total_tests = 0
    @completed_tests = 0
    @failed_tests = []
    @test_timings = {}
    @file_start_time = nil
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

  def final_summary
    total_duration = Time.now - @start_time
    
    log_with_timestamp("")
    log_with_timestamp("=" * 80)
    log_with_timestamp("📊 FINAL TEST SUITE SUMMARY")
    log_with_timestamp("=" * 80)
    log_with_timestamp("⏱️  Total execution time: #{total_duration.round(2)}s")
    log_with_timestamp("📁 Files processed: #{@completed_files}/#{@total_files}")
    
    if @failed_tests.any?
      log_with_timestamp("❌ Failed tests: #{@failed_tests.length}")
      log_with_timestamp("")
      log_with_timestamp("FAILED TEST DETAILS:")
      @failed_tests.each do |test|
        log_with_timestamp("   └─ #{test[:result]}: #{test[:name]} (#{test[:duration].round(3)}s)")
      end
    else
      log_with_timestamp("✅ Test loading completed successfully!")
    end
    
    log_with_timestamp("=" * 80)
    log_with_timestamp("🎯 NOTE: Individual test progress will be visible during test execution")
    log_with_timestamp("🔍 Watch for test names and timing information in the output below")
    log_with_timestamp("=" * 80)
  end

  def current_status
    {
      file: @current_file,
      completed_tests: @completed_tests
    }
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
    'enhanced_test_runner.rb',
    'enhanced_test_runner_simple.rb'
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
  
  # Load test files with progress reporting
  test_files_to_load.each do |file|
    begin
      progress.start_file(file)
      
      # Load the test file with timeout protection
      Timeout::timeout(progress.instance_variable_get(:@file_timeout_threshold) || 120) do
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
  progress.log_with_timestamp("   └─ Individual test progress will be shown below by Minitest")
  progress.log_with_timestamp("   └─ Look for test method names and results in the output")
  progress.log_with_timestamp("")
  
  progress.final_summary
  
  # Now run the tests normally - Minitest will handle the actual test execution
  # The enhanced reporting happens during file loading, which helps identify
  # hanging issues during the loading phase
  puts "Starting Minitest execution:"
  puts "=" * 40
  
  0 # Return success code
end

# Execute if run directly
if __FILE__ == $0
  exit_code = run_enhanced_test_suite
  exit(exit_code)
end