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

# Always load test_helper first
require_relative 'helpers/test_helper'

class ProgressTestReporter
  def initialize
    @start_time = Time.now
    @current_test_start = nil
    @test_count = 0
    @completed_tests = 0
    @failed_tests = []
    @slow_tests = []
    @timeout_threshold = 30 # seconds
  end

  def log_with_timestamp(message, flush: true)
    timestamp = Time.now.strftime("%H:%M:%S.%3N")
    puts "[#{timestamp}] #{message}"
    STDOUT.flush if flush
  end

  def suite_started
    log_with_timestamp("=" * 80)
    log_with_timestamp("🚀 ENHANCED TEST SUITE WITH REAL-TIME PROGRESS")
    log_with_timestamp("=" * 80)
    log_with_timestamp("⏰ Started at: #{@start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    log_with_timestamp("🔍 Real-time test progress enabled")
    log_with_timestamp("⚠️  Timeout detection: #{@timeout_threshold}s per test")
    log_with_timestamp("=" * 80)
  end

  def test_started(test_class, test_method)
    @current_test_start = Time.now
    @test_count += 1
    current_test = "#{test_class}##{test_method}"
    
    log_with_timestamp("🧪 [TEST #{@test_count}] STARTING: #{current_test}")
    log_with_timestamp("   └─ Started at: #{@current_test_start.strftime('%H:%M:%S.%3N')}")
    
    # Start a timeout monitor for this test
    @timeout_monitor = Thread.new do
      sleep(@timeout_threshold)
      if @current_test_start && (Time.now - @current_test_start) >= @timeout_threshold
        log_with_timestamp("⚠️  POTENTIAL HANG: #{current_test} running for #{(Time.now - @current_test_start).round(1)}s")
        log_with_timestamp("   └─ This test may be hanging - investigate #{test_class}")
      end
    end
  end

  def test_finished(test_class, test_method, result, error = nil)
    @timeout_monitor.kill if @timeout_monitor&.alive?
    
    if @current_test_start
      duration = Time.now - @current_test_start
      @completed_tests += 1
      current_test = "#{test_class}##{test_method}"
      
      status_symbol = case result
                     when :pass then '✅'
                     when :skip then '⏭️ '
                     when :fail then '❌'
                     when :error then '💥'
                     else '❓'
                     end
      
      log_with_timestamp("   └─ #{status_symbol} #{result.to_s.upcase}: #{current_test} (#{duration.round(3)}s)")
      
      if duration > @timeout_threshold
        @slow_tests << { name: current_test, duration: duration }
        log_with_timestamp("   └─ ⚠️  SLOW TEST: #{duration.round(2)}s > #{@timeout_threshold}s")
      end
      
      if result != :pass
        @failed_tests << { 
          name: current_test, 
          result: result, 
          duration: duration,
          error: error&.message 
        }
        if error
          log_with_timestamp("   └─ Error: #{error.message}")
        end
      end
      
      @current_test_start = nil
    end
  end

  def suite_finished
    total_duration = Time.now - @start_time
    
    log_with_timestamp("")
    log_with_timestamp("=" * 80)
    log_with_timestamp("📊 FINAL TEST SUITE SUMMARY")
    log_with_timestamp("=" * 80)
    log_with_timestamp("⏱️  Total execution time: #{total_duration.round(2)}s")
    log_with_timestamp("🧪 Tests executed: #{@completed_tests}")
    
    if @failed_tests.any?
      log_with_timestamp("❌ Failed/Error tests: #{@failed_tests.length}")
      log_with_timestamp("")
      @failed_tests.each do |test|
        log_with_timestamp("   └─ #{test[:result].to_s.upcase}: #{test[:name]} (#{test[:duration].round(3)}s)")
        log_with_timestamp("      Error: #{test[:error]}") if test[:error]
      end
    else
      log_with_timestamp("✅ All tests passed!")
    end
    
    if @slow_tests.any?
      log_with_timestamp("")
      log_with_timestamp("🐌 SLOW TESTS (> #{@timeout_threshold}s):")
      @slow_tests.sort_by { |t| -t[:duration] }.each_with_index do |test, index|
        log_with_timestamp("   #{index + 1}. #{test[:name]}: #{test[:duration].round(3)}s")
      end
    end
    
    log_with_timestamp("=" * 80)
  end

  def report_current_status
    if @current_test_start
      duration = Time.now - @current_test_start
      log_with_timestamp("📍 CURRENT STATUS: Test running for #{duration.round(1)}s")
    end
  end
end

# Enhanced Minitest plugin to hook into test execution
module Minitest
  class ProgressPlugin < Minitest::AbstractReporter
    def initialize(io, options)
      super
      @progress_reporter = ProgressTestReporter.new
    end

    def start
      @progress_reporter.suite_started
    end

    def prerecord(klass, name)
      @progress_reporter.test_started(klass, name)
    end

    def record(result)
      test_class = result.class.name
      test_method = result.name
      
      if result.passed?
        status = :pass
        error = nil
      elsif result.skipped?
        status = :skip
        error = result.failure
      elsif result.failure
        status = :fail
        error = result.failure
      else
        status = :error
        error = result.failure
      end
      
      @progress_reporter.test_finished(test_class, test_method, status, error)
    end

    def report
      @progress_reporter.suite_finished
    end
  end

  def self.plugin_progress_init(options)
    # Replace the default reporter with our progress reporter
    reporter.reporters.clear
    reporter.reporters << ProgressPlugin.new(io, options)
  end
end

# Discover and load test files
def load_test_files
  puts "🔍 Discovering test files..."
  
  test_dir = File.dirname(__FILE__)
  test_files = Dir.glob(File.join(test_dir, '**', 'test_*.rb')).sort
  
  # Filter out helper files and non-test files
  excluded_files = [
    'test_helper.rb',
    'run_all_tests.rb',
    'enhanced_test_runner.rb',
    'enhanced_test_runner_simple.rb',
    'progress_test_runner.rb'
  ]
  
  test_files_to_load = test_files.select do |file|
    basename = File.basename(file)
    !excluded_files.include?(basename) && basename.start_with?('test_')
  end
  
  puts "📁 Loading #{test_files_to_load.length} test files:"
  test_files_to_load.each_with_index do |file, index|
    relative_path = Pathname.new(file).relative_path_from(Pathname.new(test_dir)).to_s
    puts "   #{index + 1}. #{relative_path}"
    
    begin
      require_relative relative_path.sub('.rb', '')
    rescue StandardError => e
      puts "💥 ERROR loading #{relative_path}: #{e.message}"
    end
  end
  
  puts "✅ Test files loaded successfully!"
  puts ""
end

# Main execution
if __FILE__ == $0
  load_test_files
  
  # Set up the enhanced progress reporting
  Minitest.load_plugins
  Minitest.plugin_progress_init({})
  
  # Run tests
  exit_code = Minitest.run([])
  exit(exit_code)
end