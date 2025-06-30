#!/usr/bin/env ruby
# frozen_string_literal: true

require 'simplecov'
require 'pathname'
require 'timeout'
require 'thread'
require 'process'

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

class BulletproofTestRunner
  def initialize
    @start_time = Time.now
    @current_test_start = nil
    @test_count = 0
    @completed_tests = 0
    @failed_tests = []
    @slow_tests = []
    @hanging_tests = []
    @timeout_threshold = 8  # Shorter timeout for faster hang detection
    @test_mutex = Mutex.new
    @timeout_monitor = nil
    @active_test = nil
    @emergency_triggered = false
    @watchdog_pid = nil
    @main_process_pid = Process.pid
    @hang_count = 0
    @max_hangs = 0  # Zero tolerance for hangs
  end

  def log_with_timestamp(message, flush: true)
    timestamp = Time.now.strftime("%H:%M:%S.%3N")
    puts "[#{timestamp}] #{message}"
    STDOUT.flush if flush
  end

  def suite_started
    log_with_timestamp("=" * 80)
    log_with_timestamp("🛡️  BULLETPROOF TEST RUNNER - ZERO HANG TOLERANCE")
    log_with_timestamp("=" * 80)
    log_with_timestamp("⏰ Started at: #{@start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    log_with_timestamp("🔍 Aggressive hang detection: #{@timeout_threshold}s per test")
    log_with_timestamp("⚡ Process-level termination for hanging tests")
    log_with_timestamp("🚫 Zero tolerance: ANY hang terminates entire suite")
    log_with_timestamp("🛡️  Emergency recovery mechanisms active")
    log_with_timestamp("=" * 80)
    
    # Start external watchdog process
    start_external_watchdog
  end

  def start_external_watchdog
    @watchdog_pid = fork do
      # Watchdog process runs independently
      Process.setproctitle("PatlangTestWatchdog")
      
      watchdog_timeout = 30 # 30 second max runtime per test
      last_heartbeat = Time.now
      
      # Monitor the main process
      loop do
        sleep(1)
        
        # Check if main process is still alive
        begin
          Process.getpgid(@main_process_pid)
        rescue Errno::ESRCH
          # Main process died, exit watchdog
          exit(0)
        end
        
        # Check for hangs based on heartbeat file
        if File.exist?('.test_heartbeat')
          heartbeat_time = File.mtime('.test_heartbeat')
          if Time.now - heartbeat_time > watchdog_timeout
            puts ""
            puts "🚨" * 30
            puts "WATCHDOG: FORCE TERMINATING HUNG TEST SUITE"
            puts "🚨" * 30
            puts "Last heartbeat: #{heartbeat_time}"
            puts "Hang duration: #{(Time.now - heartbeat_time).round(1)}s"
            puts "Force killing main process #{@main_process_pid}"
            
            # Force kill the main process and all children
            begin
              Process.kill('KILL', @main_process_pid)
            rescue => e
              puts "Error killing main process: #{e.message}"
            end
            
            # Clean up and exit
            File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
            exit(1)
          end
        else
          # Create initial heartbeat
          update_heartbeat
        end
      end
    end
    
    # Update initial heartbeat
    update_heartbeat
  end

  def update_heartbeat
    File.write('.test_heartbeat', Time.now.to_f.to_s)
  rescue => e
    # Ignore heartbeat errors
  end

  def test_started(test_class, test_method)
    return if @emergency_triggered
    
    @test_mutex.synchronize do
      @current_test_start = Time.now
      @test_count += 1
      @active_test = "#{test_class}##{test_method}"
      
      log_with_timestamp("🧪 [#{@test_count}] STARTING: #{@active_test}")
      update_heartbeat  # Update heartbeat when test starts
      
      # Start aggressive timeout monitor with process termination
      @timeout_monitor = Thread.new do
        Thread.current.name = "TimeoutMonitor"
        monitor_test_execution_with_termination
      end
    end
  end

  def monitor_test_execution_with_termination
    sleep_interval = 0.5  # Check every 0.5 seconds
    elapsed = 0.0
    warning_given = false
    critical_warning_given = false
    
    while elapsed < @timeout_threshold && @current_test_start && !@emergency_triggered
      sleep(sleep_interval)
      elapsed = Time.now - @current_test_start if @current_test_start
      
      # Update heartbeat regularly
      update_heartbeat if elapsed % 2 < sleep_interval  # Every 2 seconds
      
      # Early warning at 3 seconds
      if elapsed > 3 && !warning_given
        log_with_timestamp("⚠️  WARNING: #{@active_test} running for #{elapsed.round(1)}s")
        warning_given = true
      end
      
      # Critical warning at 6 seconds
      if elapsed > 6 && !critical_warning_given
        log_with_timestamp("🚨 CRITICAL: #{@active_test} approaching timeout (#{elapsed.round(1)}s)")
        critical_warning_given = true
      end
    end
    
    # Hang detected - immediate termination
    if @current_test_start && elapsed >= @timeout_threshold && !@emergency_triggered
      handle_hang_with_immediate_termination(elapsed)
    end
  rescue => e
    log_with_timestamp("💥 MONITOR ERROR: #{e.message}")
  end

  def handle_hang_with_immediate_termination(elapsed)
    @emergency_triggered = true
    @hang_count += 1
    
    log_with_timestamp("🚨" * 20)
    log_with_timestamp("HANG DETECTED: IMMEDIATE TERMINATION")
    log_with_timestamp("🚨" * 20)
    log_with_timestamp("🎯 HANGING TEST: #{@active_test}")
    log_with_timestamp("⏱️  HANG DURATION: #{elapsed.round(1)}s")
    log_with_timestamp("🚫 ZERO HANG TOLERANCE: Terminating entire test suite")
    
    @hanging_tests << {
      name: @active_test,
      duration: elapsed,
      timestamp: Time.now
    }
    
    # Log detailed hang analysis
    log_comprehensive_hang_analysis
    
    # Clean up watchdog
    cleanup_watchdog
    
    # Immediate exit - no recovery attempts
    puts ""
    puts "🚨" * 40
    puts "BULLETPROOF TEST RUNNER: HANG TERMINATION"
    puts "🚨" * 40
    puts "Test suite terminated due to hanging test."
    puts "Hanging test: #{@active_test}"
    puts "Duration: #{elapsed.round(1)} seconds"
    puts "This indicates a systemic issue requiring investigation."
    puts "🚨" * 40
    
    exit(2)  # Exit code 2 indicates hang termination
  end

  def log_comprehensive_hang_analysis
    log_with_timestamp("")
    log_with_timestamp("🔍 COMPREHENSIVE HANG ANALYSIS")
    log_with_timestamp("=" * 60)
    log_with_timestamp("🎯 Hanging test: #{@active_test}")
    log_with_timestamp("⏱️  Hang duration: #{@hanging_tests.last[:duration].round(1)}s") if @hanging_tests.any?
    log_with_timestamp("🕐 Hang detected at: #{@hanging_tests.last[:timestamp]}") if @hanging_tests.any?
    log_with_timestamp("🔢 Total hangs in this run: #{@hang_count}")
    log_with_timestamp("")
    log_with_timestamp("🔍 ROOT CAUSE ANALYSIS:")
    log_with_timestamp("  1. PARSER INFINITE LOOP: Most likely in expression_parser.rb")
    log_with_timestamp("     - Check token advancement in parsing loops")
    log_with_timestamp("     - Review recursion termination conditions")
    log_with_timestamp("  2. EVALUATOR DEADLOCK: Possible in complex evaluations")
    log_with_timestamp("     - Check for circular dependencies")
    log_with_timestamp("     - Review thread synchronization")
    log_with_timestamp("  3. REASONING ENGINE HANG: Complex logic resolution")
    log_with_timestamp("     - Check unification loops")
    log_with_timestamp("     - Review goal pursuit algorithms")
    log_with_timestamp("  4. I/O BLOCKING: File operations without timeout")
    log_with_timestamp("     - Check file read/write operations")
    log_with_timestamp("     - Review network or system calls")
    log_with_timestamp("")
    log_with_timestamp("💡 IMMEDIATE ACTIONS REQUIRED:")
    log_with_timestamp("  1. Review #{@active_test} test case")
    log_with_timestamp("  2. Add parser loop counters and forced exits")
    log_with_timestamp("  3. Implement timeouts in all I/O operations")
    log_with_timestamp("  4. Add comprehensive loop detection")
    log_with_timestamp("  5. Review recursion depth limits")
    log_with_timestamp("=" * 60)
  end

  def test_finished(test_class, test_method, result, error = nil)
    return if @emergency_triggered
    
    @test_mutex.synchronize do
      cleanup_timeout_monitor
      update_heartbeat  # Update heartbeat when test finishes
      
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
        
        if duration > 3  # Flag slow tests over 3 seconds
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

  def cleanup_watchdog
    if @watchdog_pid
      begin
        Process.kill('TERM', @watchdog_pid)
        Process.waitpid(@watchdog_pid, Process::WNOHANG)
      rescue => e
        # Ignore cleanup errors
      end
      @watchdog_pid = nil
    end
    
    # Clean up heartbeat file
    File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
  end

  def suite_finished
    return if @emergency_triggered
    
    cleanup_timeout_monitor
    cleanup_watchdog
    total_duration = Time.now - @start_time
    
    puts ""
    puts "=" * 80
    puts "📊 BULLETPROOF TEST RUNNER SUMMARY"
    puts "=" * 80
    puts "⏱️  Total execution time: #{total_duration.round(2)}s"
    puts "🧪 Tests executed: #{@completed_tests}"
    puts "🚫 Hangs detected: #{@hang_count}"
    
    if @hanging_tests.any?
      puts "🚨 HANGING TESTS (ZERO TOLERANCE VIOLATED):"
      @hanging_tests.each do |test|
        puts "   └─ #{test[:name]} (hung after #{test[:duration].round(1)}s)"
      end
      puts ""
      puts "❌ TEST SUITE FAILED: Hangs detected"
      exit(2)
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
      puts "🐌 Slow tests (>3s): #{@slow_tests.length}"
      @slow_tests.sort_by { |t| -t[:duration] }.first(3).each_with_index do |test, index|
        puts "   #{index + 1}. #{test[:name]}: #{test[:duration].round(3)}s"
      end
    end
    
    puts "=" * 80
    puts "🎯 SUCCESS: Bulletproof test runner completed without hangs"
    puts "💪 Zero hang tolerance maintained throughout execution"
    puts "=" * 80
  end
end

# Thread-safe minitest hooks for bulletproof runner
module BulletproofMinitestHooks
  @@reporter = BulletproofTestRunner.new
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

# Enhanced Minitest::Test with bulletproof error handling
class Minitest::Test
  alias_method :original_setup, :setup
  alias_method :original_teardown, :teardown
  
  def setup
    begin
      BulletproofMinitestHooks.safe_reporter_call(:test_started, self.class.name, self.name)
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
      
      BulletproofMinitestHooks.safe_reporter_call(:test_finished, self.class.name, self.name, result, failure)
    rescue => e
      puts "[TEARDOWN ERROR] #{self.class.name}##{self.name}: #{e.message}"
      # Don't re-raise teardown errors
    end
  end
end

# Ultra-safe test file loading with strict timeouts
def load_test_files_with_bulletproof_timeout
  puts "🔍 Loading test files with bulletproof timeouts..."
  
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
    'robust_test_runner.rb',
    'bulletproof_test_runner.rb'
  ]
  
  test_files_to_load = test_files.select do |file|
    basename = File.basename(file)
    !excluded_files.include?(basename) && basename.start_with?('test_')
  end
  
  puts "📁 Loading #{test_files_to_load.length} test files with 3s timeout each:"
  
  loaded_count = 0
  test_files_to_load.each_with_index do |file, index|
    relative_path = Pathname.new(file).relative_path_from(Pathname.new(test_dir)).to_s
    print "   #{index + 1}/#{test_files_to_load.length}: #{relative_path}... "
    
    begin
      Timeout::timeout(3) do  # Shorter timeout for file loading
        require_relative relative_path.sub('.rb', '')
        loaded_count += 1
        puts "✅"
      end
    rescue Timeout::Error
      puts "⏰ TIMEOUT (>3s)"
      puts "      🚨 File loading timeout: #{relative_path}"
      puts "      💡 This file contains infinite loops or blocking operations"
      puts "      🚫 BULLETPROOF MODE: Cannot continue with problematic file"
      exit(3)  # Exit if file loading hangs
    rescue => e
      puts "❌ ERROR: #{e.message}"
    end
  end
  
  puts "✅ Loaded #{loaded_count}/#{test_files_to_load.length} test files successfully"
  puts ""
  
  BulletproofMinitestHooks.reporter.suite_started
end

# Exit handler with cleanup
at_exit do
  begin
    if defined?(BulletproofMinitestHooks)
      BulletproofMinitestHooks.reporter.suite_finished 
    end
  rescue => e
    puts "[EXIT ERROR] #{e.message}"
  ensure
    # Ensure watchdog cleanup
    File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
  end
end

# Signal handlers for graceful shutdown
Signal.trap('INT') do
  puts ""
  puts "🚨 INTERRUPT SIGNAL RECEIVED"
  puts "Cleaning up and exiting..."
  File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
  exit(130)
end

Signal.trap('TERM') do
  puts ""
  puts "🚨 TERMINATE SIGNAL RECEIVED"
  puts "Cleaning up and exiting..."
  File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
  exit(143)
end

# Main execution
if __FILE__ == $0
  begin
    puts "[#{Time.now.strftime("%H:%M:%S")}] 🛡️  Starting bulletproof test runner"
    load_test_files_with_bulletproof_timeout
    
    puts "[#{Time.now.strftime("%H:%M:%S")}] 🎬 Starting Minitest execution"
    exit_code = Minitest.run([])
    puts "[#{Time.now.strftime("%H:%M:%S")}] 🏁 Minitest completed with exit code: #{exit_code}"
    
    # Clean up
    File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
    exit(exit_code)
  rescue => e
    puts "[FATAL ERROR] #{e.message}"
    puts "Backtrace: #{e.backtrace.first(5).join(', ')}"
    File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
    exit(1)
  end
end