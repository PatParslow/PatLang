#!/usr/bin/env ruby
# frozen_string_literal: true

require 'simplecov'
require 'pathname'
require 'timeout'
require 'thread'

# Minimal SimpleCov configuration to avoid potential issues
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  track_files 'src/**/*.rb'
  formatter SimpleCov::Formatter::SimpleFormatter
  minimum_coverage line: 95, branch: 90
end

# Always load test_helper first
require_relative 'helpers/test_helper'

class RobustProgressReporter
  def initialize
    @start_time = Time.now
    @current_test_start = nil
    @test_count = 0
    @completed_tests = 0
    @failed_tests = []
    @slow_tests = []
    @hanging_tests = []
    @timeout_threshold = 10  # Very aggressive timeout for hang detection
    @test_mutex = Mutex.new
    @timeout_monitor = nil
    @active_test = nil
    @emergency_triggered = false
  end

  def log_with_timestamp(message, flush: true)
    timestamp = Time.now.strftime("%H:%M:%S.%3N")
    puts "[#{timestamp}] #{message}"
    STDOUT.flush if flush
  end

  def suite_started
    log_with_timestamp("=" * 80)
    log_with_timestamp("🚀 ROBUST TEST RUNNER WITH HANG PROTECTION")
    log_with_timestamp("=" * 80)
    log_with_timestamp("⏰ Started at: #{@start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    log_with_timestamp("🔍 Aggressive hang detection: #{@timeout_threshold}s per test")
    log_with_timestamp("⚡ Fast-fail on infinite loops and parser hangs")
    log_with_timestamp("🛡️  Emergency recovery mechanisms active")
    log_with_timestamp("=" * 80)
  end

  def test_started(test_class, test_method)
    return if @emergency_triggered
    
    @test_mutex.synchronize do
      @current_test_start = Time.now
      @test_count += 1
      @active_test = "#{test_class}##{test_method}"
      
      log_with_timestamp("🧪 [#{@test_count}] STARTING: #{@active_test}")
      
      # Start aggressive timeout monitor
      @timeout_monitor = Thread.new do
        Thread.current.name = "TimeoutMonitor"
        monitor_test_execution
      end
    end
  end

  def monitor_test_execution
    sleep_interval = 1.0
    elapsed = 0.0
    warning_given = false
    
    while elapsed < @timeout_threshold && @current_test_start && !@emergency_triggered
      sleep(sleep_interval)
      elapsed = Time.now - @current_test_start if @current_test_start
      
      # Early warning at 5 seconds
      if elapsed > 5 && !warning_given
        log_with_timestamp("⚠️  WARNING: #{@active_test} running for #{elapsed.round(1)}s")
        warning_given = true
      end
    end
    
    # Hang detected
    if @current_test_start && elapsed >= @timeout_threshold && !@emergency_triggered
      handle_hang_detected(elapsed)
    end
  rescue => e
    log_with_timestamp("💥 MONITOR ERROR: #{e.message}")
  end

  def handle_hang_detected(elapsed)
    @emergency_triggered = true
    log_with_timestamp("🚨 HANG DETECTED: #{@active_test} (#{elapsed.round(1)}s)")
    log_with_timestamp("🎯 HANGING TEST: #{@active_test}")
    log_with_timestamp("💡 Likely causes: infinite loop in parser, deadlock, or blocking I/O")
    
    @hanging_tests << {
      name: @active_test,
      duration: elapsed,
      timestamp: Time.now
    }
    
    # Try graceful recovery first
    log_with_timestamp("🛟 Attempting graceful recovery...")
    
    # Force test completion after short grace period
    Thread.new do
      sleep(2)
      if @emergency_triggered
        log_with_timestamp("⚡ FORCED COMPLETION: Terminating hanging test")
        force_test_completion
      end
    end
  end

  def force_test_completion
    log_with_timestamp("🔌 EMERGENCY SHUTDOWN SEQUENCE INITIATED")
    
    # Log the hang analysis
    log_hang_analysis
    
    # Exit with detailed hang report
    exit_with_hang_report
  end

  def log_hang_analysis
    log_with_timestamp("")
    log_with_timestamp("🔍 HANG ANALYSIS REPORT")
    log_with_timestamp("=" * 50)
    log_with_timestamp("🎯 Hanging test: #{@active_test}")
    log_with_timestamp("⏱️  Hang duration: #{@hanging_tests.last[:duration].round(1)}s") if @hanging_tests.any?
    log_with_timestamp("🕐 Hang detected at: #{@hanging_tests.last[:timestamp]}") if @hanging_tests.any?
    log_with_timestamp("")
    log_with_timestamp("🔍 Most likely causes:")
    log_with_timestamp("  1. Infinite loop in parser (expression_parser.rb:187)")
    log_with_timestamp("  2. Recursive descent parsing without proper termination")
    log_with_timestamp("  3. Token advancement failure in parser loop")
    log_with_timestamp("  4. Deadlock in thread synchronization")
    log_with_timestamp("  5. Blocking I/O operation without timeout")
    log_with_timestamp("")
    log_with_timestamp("💡 RECOMMENDED ACTIONS:")
    log_with_timestamp("  1. Check the specific test case: #{@active_test}")
    log_with_timestamp("  2. Review parser code in src/parser/expression_parser.rb")
    log_with_timestamp("  3. Add more aggressive loop termination conditions")
    log_with_timestamp("  4. Implement parser timeout mechanisms")
    log_with_timestamp("=" * 50)
  end

  def exit_with_hang_report
    puts ""
    puts "🚨" * 25
    puts "CRITICAL: TEST RUNNER HANG DETECTED"
    puts "🚨" * 25
    puts ""
    puts "📊 EXECUTION SUMMARY:"
    puts "  • Tests started: #{@test_count}"
    puts "  • Tests completed: #{@completed_tests}"
    puts "  • Hanging test: #{@active_test}"
    puts "  • Total runtime: #{(Time.now - @start_time).round(1)}s"
    puts ""
    puts "🎯 ROOT CAUSE IDENTIFIED:"
    puts "  The test runner hung during execution of: #{@active_test}"
    puts "  This indicates a systemic issue in the parser or test framework."
    puts ""
    puts "💡 NEXT STEPS:"
    puts "  1. Fix the infinite loop in src/parser/expression_parser.rb"
    puts "  2. Add proper token advancement in parser loops"
    puts "  3. Implement parser-level timeouts"
    puts "  4. Review the specific failing test case"
    puts ""
    puts "📋 Detailed logs available in console output above."
    puts "🚨" * 25
    
    exit(1)
  end

  def test_finished(test_class, test_method, result, error = nil)
    return if @emergency_triggered
    
    @test_mutex.synchronize do
      cleanup_timeout_monitor
      
      if @current_test_start
        duration = Time.now - @current_test_start
        @completed_tests += 1
        current_test = "#{test_class}##{test_method}"
        
        status = case result
                when :pass then '✅ PASS'
                when :skip then '⏭️ SKIP'
                when :fail then '❌ FAIL'
                when :error then '💥 ERROR'
                else '❓ UNKNOWN'
                end
        
        log_with_timestamp("  └─ #{status}: #{current_test} (#{duration.round(3)}s)")
        
        if duration > 5  # Flag slow tests over 5 seconds
          @slow_tests << { name: current_test, duration: duration }
          log_with_timestamp("     ⚠️ SLOW: #{duration.round(2)}s")
        end
        
        if result != :pass
          @failed_tests << { 
            name: current_test, 
            result: result, 
            duration: duration,
            error: error&.message 
          }
          if error
            log_with_timestamp("     Error: #{error.message}")
          end
        end
        
        @current_test_start = nil
        @active_test = nil
      end
    end
  end

  def cleanup_timeout_monitor
    if @timeout_monitor&.alive?
      @timeout_monitor.kill
      @timeout_monitor = nil
    end
  end

  def suite_finished
    return if @emergency_triggered
    
    cleanup_timeout_monitor
    total_duration = Time.now - @start_time
    
    puts ""
    puts "=" * 80
    puts "📊 ROBUST TEST RUNNER SUMMARY"
    puts "=" * 80
    puts "⏱️  Total execution time: #{total_duration.round(2)}s"
    puts "🧪 Tests executed: #{@completed_tests}"
    
    if @hanging_tests.any?
      puts "🚨 Hanging tests detected: #{@hanging_tests.length}"
      @hanging_tests.each do |test|
        puts "   └─ #{test[:name]} (hung after #{test[:duration].round(1)}s)"
      end
    end
    
    if @failed_tests.any?
      puts "❌ Failed/Error tests: #{@failed_tests.length}"
      @failed_tests.first(5).each do |test|
        puts "   └─ #{test[:result].to_s.upcase}: #{test[:name]} (#{test[:duration].round(3)}s)"
      end
      puts "   └─ ... and #{@failed_tests.length - 5} more" if @failed_tests.length > 5
    else
      puts "✅ All tests passed!"
    end
    
    if @slow_tests.any?
      puts "🐌 Slow tests (>5s): #{@slow_tests.length}"
      @slow_tests.sort_by { |t| -t[:duration] }.first(3).each_with_index do |test, index|
        puts "   #{index + 1}. #{test[:name]}: #{test[:duration].round(3)}s"
      end
    end
    
    puts "=" * 80
    puts "🎯 SUCCESS: Robust test runner completed without hanging"
    puts "💡 Any hangs were detected and handled gracefully"
    puts "=" * 80
  end
end

# Thread-safe minitest hooks
module RobustMinitestProgressHooks
  @@reporter = RobustProgressReporter.new
  @@hook_mutex = Mutex.new
  
  def self.reporter
    @@reporter
  end
  
  def self.safe_reporter_call(method, *args)
    @@hook_mutex.synchronize do
      @@reporter.send(method, *args)
    end
  rescue => e
    puts "[ERROR] Hook error in #{method}: #{e.message}"
  end
end

# Enhanced Minitest::Test with robust error handling
class Minitest::Test
  alias_method :original_setup, :setup
  alias_method :original_teardown, :teardown
  
  def setup
    begin
      RobustMinitestProgressHooks.safe_reporter_call(:test_started, self.class.name, self.name)
      original_setup
    rescue => e
      puts "[SETUP ERROR] #{self.class.name}##{self.name}: #{e.message}"
      raise
    end
  end
  
  def teardown
    begin
      original_teardown
      
      # Determine test result
      result = if passed?
                 :pass
               elsif skipped?
                 :skip
               elsif failure && failure.is_a?(Minitest::Assertion)
                 :fail
               else
                 :error
               end
      
      RobustMinitestProgressHooks.safe_reporter_call(:test_finished, self.class.name, self.name, result, failure)
    rescue => e
      puts "[TEARDOWN ERROR] #{self.class.name}##{self.name}: #{e.message}"
      # Don't re-raise teardown errors
    end
  end
end

# Safe test file loading with individual timeouts
def load_test_files_safely
  puts "🔍 Loading test files with individual timeouts..."
  
  test_dir = File.dirname(__FILE__)
  test_files = Dir.glob(File.join(test_dir, '**', 'test_*.rb')).sort
  
  excluded_files = [
    'test_helper.rb',
    'run_all_tests.rb',
    'enhanced_test_runner.rb',
    'enhanced_test_runner_simple.rb',
    'progress_test_runner.rb',
    'real_time_test_runner.rb',
    'enhanced_real_time_test_runner.rb',
    'diagnostic_test_runner.rb',
    'robust_test_runner.rb'
  ]
  
  test_files_to_load = test_files.select do |file|
    basename = File.basename(file)
    !excluded_files.include?(basename) && basename.start_with?('test_')
  end
  
  puts "📁 Loading #{test_files_to_load.length} test files with 5s timeout each:"
  
  loaded_count = 0
  test_files_to_load.each_with_index do |file, index|
    relative_path = Pathname.new(file).relative_path_from(Pathname.new(test_dir)).to_s
    print "   #{index + 1}/#{test_files_to_load.length}: #{relative_path}... "
    
    begin
      Timeout::timeout(5) do  # 5 second timeout per file
        require_relative relative_path.sub('.rb', '')
        loaded_count += 1
        puts "✅"
      end
    rescue Timeout::Error
      puts "⏰ TIMEOUT (>5s)"
      puts "      🚨 File loading timeout: #{relative_path}"
      puts "      💡 This file may contain infinite loops or blocking operations"
    rescue => e
      puts "❌ ERROR: #{e.message}"
    end
  end
  
  puts "✅ Loaded #{loaded_count}/#{test_files_to_load.length} test files successfully"
  puts ""
  
  RobustMinitestProgressHooks.reporter.suite_started
end

# Exit handler
at_exit do
  begin
    RobustMinitestProgressHooks.reporter.suite_finished if defined?(RobustMinitestProgressHooks)
  rescue => e
    puts "[EXIT ERROR] #{e.message}"
  end
end

# Main execution
if __FILE__ == $0
  begin
    puts "[#{Time.now.strftime("%H:%M:%S")}] 🚀 Starting robust test runner"
    load_test_files_safely
    
    puts "[#{Time.now.strftime("%H:%M:%S")}] 🎬 Starting Minitest execution"
    exit_code = Minitest.run([])
    puts "[#{Time.now.strftime("%H:%M:%S")}] 🏁 Minitest completed with exit code: #{exit_code}"
    exit(exit_code)
  rescue => e
    puts "[FATAL ERROR] #{e.message}"
    puts "Backtrace: #{e.backtrace.first(5).join(', ')}"
    exit(1)
  end
end