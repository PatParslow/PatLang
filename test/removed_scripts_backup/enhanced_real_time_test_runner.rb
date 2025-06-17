#!/usr/bin/env ruby
# frozen_string_literal: true

require 'simplecov'
require 'pathname'
require 'timeout'
require 'thread'
require 'monitor'

# Ultra-verbose logging system for debugging hangs
class UltraVerboseLogger
  def initialize
    @log_mutex = Mutex.new
    @log_file = File.open("test_runner_debug.log", "w")
    @log_file.sync = true # Force immediate writes
    @start_time = Time.now
    @heartbeat_thread = nil
    @system_monitor_thread = nil
    @thread_counter = 0
    start_system_monitoring
  end

  def log(message, level: :info, thread_info: true)
    @log_mutex.synchronize do
      timestamp = Time.now.strftime("%H:%M:%S.%6N")
      elapsed = (Time.now - @start_time).round(6)
      
      thread_id = thread_info ? "[T:#{Thread.current.object_id}]" : ""
      pid_info = "[PID:#{Process.pid}]"
      memory_info = get_memory_usage
      
      formatted_message = "[#{timestamp}][+#{elapsed}s]#{pid_info}#{thread_id}[#{level.upcase}] #{message} #{memory_info}"
      
      puts formatted_message
      @log_file.puts formatted_message
      @log_file.flush
      STDOUT.flush
    end
  end

  def start_system_monitoring
    log "🔧 SYSTEM MONITOR: Starting system monitoring threads", level: :debug
    
    # Heartbeat thread to prove we're alive
    @heartbeat_thread = Thread.new do
      Thread.current.name = "Heartbeat"
      loop do
        sleep 5
        log "💓 HEARTBEAT: Test runner still alive", level: :debug
      end
    end

    # System monitoring thread
    @system_monitor_thread = Thread.new do
      Thread.current.name = "SystemMonitor"
      loop do
        sleep 10
        thread_count = Thread.list.length
        log "📊 SYSTEM: #{thread_count} threads active, Memory: #{get_memory_usage}", level: :debug
        
        # Log all active threads
        Thread.list.each_with_index do |thread, idx|
          status = thread.alive? ? "ALIVE" : "DEAD"
          name = thread.name || "unnamed"
          log "   Thread #{idx}: #{name} (#{thread.object_id}) - #{status}", level: :debug
        end
      end
    end
  end

  def get_memory_usage
    begin
      if RUBY_PLATFORM =~ /linux/
        mem_kb = `ps -o rss= -p #{Process.pid}`.strip.to_i
        "[MEM:#{mem_kb}KB]"
      elsif RUBY_PLATFORM =~ /darwin/
        mem_bytes = `ps -o rss= -p #{Process.pid}`.strip.to_i * 1024
        "[MEM:#{mem_bytes/1024}KB]"
      else
        "[MEM:N/A]"
      end
    rescue
      "[MEM:ERR]"
    end
  end

  def emergency_shutdown(reason)
    log "🚨 EMERGENCY SHUTDOWN: #{reason}", level: :error
    
    # Kill all our monitoring threads
    [@heartbeat_thread, @system_monitor_thread].each do |thread|
      if thread&.alive?
        log "🔪 Killing thread: #{thread.name || thread.object_id}", level: :error
        thread.kill
      end
    end
    
    # Dump all thread backtraces
    log "🔍 THREAD DUMP:", level: :error
    Thread.list.each do |thread|
      log "Thread #{thread.object_id} (#{thread.name || 'unnamed'}):", level: :error
      if thread.alive?
        begin
          backtrace = thread.backtrace || ["No backtrace available"]
          backtrace.each { |line| log "  #{line}", level: :error }
        rescue
          log "  Could not get backtrace", level: :error
        end
      else
        log "  Thread is dead", level: :error
      end
    end
    
    @log_file.close if @log_file && !@log_file.closed?
  end

  def close
    @heartbeat_thread&.kill
    @system_monitor_thread&.kill
    @log_file&.close
  end
end

# Global ultra-verbose logger
$ultra_logger = UltraVerboseLogger.new

# Configure SimpleCov with safer settings
$ultra_logger.log "🔧 SIMPLECOV: Configuring SimpleCov"
begin
  SimpleCov.start do
    enable_coverage :branch
    add_filter '/test/'
    track_files 'src/**/*.rb'
    
    # Use simpler formatter to avoid potential hanging
    formatter SimpleCov::Formatter::SimpleFormatter
    
    # Set coverage requirements
    minimum_coverage line: 95, branch: 90
  end
  $ultra_logger.log "✅ SIMPLECOV: Configuration completed successfully"
rescue => e
  $ultra_logger.log "❌ SIMPLECOV: Configuration failed: #{e.message}", level: :error
  raise
end

# Safe file loading with timeout protection
def safe_require(file_path, timeout_seconds = 30)
  $ultra_logger.log "📂 SAFE_REQUIRE: Loading #{file_path} with #{timeout_seconds}s timeout"
  
  begin
    Timeout::timeout(timeout_seconds) do
      require_relative file_path
      $ultra_logger.log "✅ SAFE_REQUIRE: Successfully loaded #{file_path}"
    end
  rescue Timeout::Error
    $ultra_logger.log "⏰ SAFE_REQUIRE: TIMEOUT loading #{file_path} after #{timeout_seconds}s", level: :error
    raise "File loading timeout: #{file_path}"
  rescue => e
    $ultra_logger.log "❌ SAFE_REQUIRE: Error loading #{file_path}: #{e.message}", level: :error
    raise
  end
end

# Load test_helper safely first
$ultra_logger.log "📋 INITIALIZATION: Loading test_helper"
safe_require 'helpers/test_helper'
$ultra_logger.log "✅ INITIALIZATION: test_helper loaded successfully"

class EnhancedRealTimeProgressReporter
  def initialize
    @start_time = Time.now
    @current_test_start = nil
    @test_count = 0
    @completed_tests = 0
    @failed_tests = []
    @slow_tests = []
    @timeout_threshold = 15 # Reduced from 30 for faster hang detection
    @test_mutex = Mutex.new
    @timeout_monitor = nil
    @active_test = nil
    @emergency_shutdown_triggered = false
    
    $ultra_logger.log "🚀 REPORTER: Initialized with #{@timeout_threshold}s timeout threshold"
  end

  def suite_started
    $ultra_logger.log "🎬 SUITE: Starting test suite"
    puts "=" * 80
    puts "🚀 ENHANCED REAL-TIME TEST PROGRESS MONITOR"
    puts "=" * 80
    puts "⏰ Started at: #{@start_time.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "🔍 Ultra-verbose debugging enabled"
    puts "⚠️  Timeout detection: #{@timeout_threshold}s per test"
    puts "🎯 Enhanced hang detection with emergency recovery"
    puts "📊 System monitoring active"
    puts "=" * 80
    $ultra_logger.log "✅ SUITE: Suite started message displayed"
  end

  def test_started(test_class, test_method)
    return if @emergency_shutdown_triggered
    
    @test_mutex.synchronize do
      $ultra_logger.log "🧪 TEST_START: Beginning #{test_class}##{test_method}"
      
      # Clean up any previous timeout monitor
      cleanup_timeout_monitor
      
      @current_test_start = Time.now
      @test_count += 1
      @active_test = "#{test_class}##{test_method}"
      
      puts "🧪 [TEST #{@test_count}] STARTING: #{@active_test}"
      puts "   └─ Started at: #{@current_test_start.strftime('%H:%M:%S.%6N')}"
      
      $ultra_logger.log "⏱️  TEST_TIMER: Starting timeout monitor for #{@active_test}"
      
      # Create timeout monitor with enhanced monitoring
      @timeout_monitor = Thread.new do
        Thread.current.name = "TimeoutMonitor_#{@test_count}"
        monitor_test_execution
      end
      
      $ultra_logger.log "✅ TEST_START: Setup complete for #{@active_test}"
    end
  end

  def monitor_test_execution
    sleep_interval = 1.0
    elapsed = 0.0
    
    while elapsed < @timeout_threshold && @current_test_start
      sleep(sleep_interval)
      elapsed = Time.now - @current_test_start if @current_test_start
      
      # Log progress every 5 seconds for slow tests
      if elapsed > 5 && (elapsed % 5).round(1) < sleep_interval
        $ultra_logger.log "⏳ TEST_PROGRESS: #{@active_test} running for #{elapsed.round(1)}s"
      end
    end
    
    # Timeout detected
    if @current_test_start && elapsed >= @timeout_threshold
      handle_timeout_detected(elapsed)
    end
  rescue => e
    $ultra_logger.log "💥 TIMEOUT_MONITOR: Error in monitor thread: #{e.message}", level: :error
  end

  def handle_timeout_detected(elapsed)
    $ultra_logger.log "🚨 TIMEOUT: #{@active_test} exceeded #{@timeout_threshold}s (#{elapsed.round(1)}s)", level: :error
    
    puts "🚨 HANG DETECTED: #{@active_test} running for #{elapsed.round(1)}s"
    puts "   └─ ⚠️  This test is likely hanging - #{@active_test}"
    puts "   └─ 💡 Exact hang location identified!"
    puts "   └─ 🔍 Check the test method for infinite loops or blocking operations"
    
    # Give test a few more seconds to complete naturally
    sleep(5)
    
    if @current_test_start && (Time.now - @current_test_start) >= (@timeout_threshold + 5)
      $ultra_logger.log "💥 EMERGENCY: #{@active_test} still hanging after grace period", level: :error
      trigger_emergency_recovery
    end
  end

  def trigger_emergency_recovery
    @emergency_shutdown_triggered = true
    $ultra_logger.log "🚨 EMERGENCY_RECOVERY: Triggering emergency shutdown", level: :error
    
    puts ""
    puts "🚨" * 20
    puts "EMERGENCY RECOVERY ACTIVATED"
    puts "Test runner will attempt graceful shutdown"
    puts "🚨" * 20
    
    # Try to identify the hanging test
    if @current_test_start
      hang_duration = Time.now - @current_test_start
      puts "🎯 HANGING TEST IDENTIFIED: #{@active_test}"
      puts "🕐 Hang duration: #{hang_duration.round(1)} seconds"
    end
    
    $ultra_logger.emergency_shutdown("Hanging test detected: #{@active_test}")
    
    # Force exit after logging
    Thread.new do
      sleep(3)
      puts "🔌 FORCED EXIT: Test runner will exit in 2 seconds..."
      sleep(2)
      exit(1)
    end
  end

  def test_finished(test_class, test_method, result, error = nil)
    return if @emergency_shutdown_triggered
    
    @test_mutex.synchronize do
      current_test = "#{test_class}##{test_method}"
      $ultra_logger.log "🏁 TEST_FINISH: Completing #{current_test} with result #{result}"
      
      cleanup_timeout_monitor
      
      if @current_test_start
        duration = Time.now - @current_test_start
        @completed_tests += 1
        
        status_symbol = case result
                       when :pass then '✅'
                       when :skip then '⏭️ '
                       when :fail then '❌'
                       when :error then '💥'
                       else '❓'
                       end
        
        puts "   └─ #{status_symbol} #{result.to_s.upcase}: #{current_test} (#{duration.round(3)}s)"
        
        if duration > @timeout_threshold
          @slow_tests << { name: current_test, duration: duration }
          puts "   └─ ⚠️  SLOW TEST: #{duration.round(2)}s > #{@timeout_threshold}s"
          $ultra_logger.log "🐌 SLOW_TEST: #{current_test} took #{duration.round(3)}s", level: :warn
        end
        
        if result != :pass
          @failed_tests << { 
            name: current_test, 
            result: result, 
            duration: duration,
            error: error&.message 
          }
          if error
            puts "   └─ Error: #{error.message}"
            $ultra_logger.log "❌ TEST_ERROR: #{current_test} - #{error.message}", level: :error
          end
        end
        
        @current_test_start = nil
        @active_test = nil
        $ultra_logger.log "✅ TEST_FINISH: #{current_test} cleanup complete"
      end
    end
  end

  def cleanup_timeout_monitor
    if @timeout_monitor&.alive?
      $ultra_logger.log "🧹 CLEANUP: Killing timeout monitor thread"
      @timeout_monitor.kill
      @timeout_monitor = nil
    end
  end

  def suite_finished
    return if @emergency_shutdown_triggered
    
    $ultra_logger.log "🎬 SUITE_FINISH: Completing test suite"
    cleanup_timeout_monitor
    
    total_duration = Time.now - @start_time
    
    puts ""
    puts "=" * 80
    puts "📊 FINAL TEST SUITE SUMMARY"
    puts "=" * 80
    puts "⏱️  Total execution time: #{total_duration.round(2)}s"
    puts "🧪 Tests executed: #{@completed_tests}"
    
    if @failed_tests.any?
      puts "❌ Failed/Error tests: #{@failed_tests.length}"
      puts ""
      @failed_tests.each do |test|
        puts "   └─ #{test[:result].to_s.upcase}: #{test[:name]} (#{test[:duration].round(3)}s)"
        puts "      Error: #{test[:error]}" if test[:error]
      end
    else
      puts "✅ All tests passed!"
    end
    
    if @slow_tests.any?
      puts ""
      puts "🐌 SLOW TESTS (> #{@timeout_threshold}s):"
      @slow_tests.sort_by { |t| -t[:duration] }.each_with_index do |test, index|
        puts "   #{index + 1}. #{test[:name]}: #{test[:duration].round(3)}s"
      end
    end
    
    puts "=" * 80
    puts "🎯 SUCCESS: Enhanced test runner completed"
    puts "💡 All hangs and slow tests clearly identified"
    puts "📋 Detailed logs saved to test_runner_debug.log"
    puts "=" * 80
    
    $ultra_logger.log "✅ SUITE_FINISH: Test suite completed successfully"
  end
end

# Thread-safe minitest hooks
module EnhancedMinitestProgressHooks
  @@reporter = EnhancedRealTimeProgressReporter.new
  @@hook_mutex = Mutex.new
  
  def self.reporter
    @@reporter
  end
  
  def self.safe_reporter_call(method, *args)
    @@hook_mutex.synchronize do
      @@reporter.send(method, *args)
    end
  rescue => e
    $ultra_logger.log "💥 HOOK_ERROR: Error in #{method}: #{e.message}", level: :error
  end
end

# Enhanced Minitest::Test with better error handling
class Minitest::Test
  alias_method :original_setup, :setup
  alias_method :original_teardown, :teardown
  
  def setup
    $ultra_logger.log "🔧 SETUP: Starting setup for #{self.class.name}##{self.name}"
    
    begin
      EnhancedMinitestProgressHooks.safe_reporter_call(:test_started, self.class.name, self.name)
      original_setup
      $ultra_logger.log "✅ SETUP: Setup completed for #{self.class.name}##{self.name}"
    rescue => e
      $ultra_logger.log "💥 SETUP_ERROR: Setup failed for #{self.class.name}##{self.name}: #{e.message}", level: :error
      raise
    end
  end
  
  def teardown
    $ultra_logger.log "🧹 TEARDOWN: Starting teardown for #{self.class.name}##{self.name}"
    
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
      
      EnhancedMinitestProgressHooks.safe_reporter_call(:test_finished, self.class.name, self.name, result, failure)
      $ultra_logger.log "✅ TEARDOWN: Teardown completed for #{self.class.name}##{self.name}"
    rescue => e
      $ultra_logger.log "💥 TEARDOWN_ERROR: Teardown failed for #{self.class.name}##{self.name}: #{e.message}", level: :error
      # Don't re-raise teardown errors as they mask the original test failure
    end
  end
end

# Enhanced test file discovery and loading
def enhanced_load_test_files
  $ultra_logger.log "🔍 FILE_DISCOVERY: Starting test file discovery"
  puts "🔍 Discovering test files..."
  
  test_dir = File.dirname(__FILE__)
  test_files = Dir.glob(File.join(test_dir, '**', 'test_*.rb')).sort
  
  # Enhanced exclusion list
  excluded_files = [
    'test_helper.rb',
    'run_all_tests.rb',
    'enhanced_test_runner.rb',
    'enhanced_test_runner_simple.rb',
    'progress_test_runner.rb',
    'real_time_test_runner.rb',
    'enhanced_real_time_test_runner.rb'
  ]
  
  test_files_to_load = test_files.select do |file|
    basename = File.basename(file)
    !excluded_files.include?(basename) && basename.start_with?('test_')
  end
  
  $ultra_logger.log "📁 FILE_DISCOVERY: Found #{test_files_to_load.length} test files to load"
  puts "📁 Loading #{test_files_to_load.length} test files:"
  
  loaded_count = 0
  test_files_to_load.each_with_index do |file, index|
    relative_path = Pathname.new(file).relative_path_from(Pathname.new(test_dir)).to_s
    puts "   #{index + 1}. #{relative_path}"
    
    begin
      $ultra_logger.log "📂 FILE_LOAD: Loading #{relative_path}"
      safe_require relative_path.sub('.rb', ''), 30 # 30 second timeout per file
      loaded_count += 1
      $ultra_logger.log "✅ FILE_LOAD: Successfully loaded #{relative_path}"
    rescue => e
      puts "💥 ERROR loading #{relative_path}: #{e.message}"
      $ultra_logger.log "💥 FILE_LOAD_ERROR: Failed to load #{relative_path}: #{e.message}", level: :error
      
      # Don't exit on file loading errors, just continue
      puts "   └─ Continuing with remaining files..."
    end
  end
  
  puts "✅ Test files loaded: #{loaded_count}/#{test_files_to_load.length}"
  puts ""
  
  $ultra_logger.log "✅ FILE_DISCOVERY: Completed loading #{loaded_count} test files"
  EnhancedMinitestProgressHooks.reporter.suite_started
end

# Enhanced exit handler with cleanup
at_exit do
  begin
    if defined?(EnhancedMinitestProgressHooks)
      $ultra_logger.log "🏁 EXIT_HANDLER: Running suite finish"
      EnhancedMinitestProgressHooks.reporter.suite_finished
    end
  rescue => e
    $ultra_logger.log "💥 EXIT_ERROR: Error in exit handler: #{e.message}", level: :error
  ensure
    $ultra_logger.log "🔚 EXIT_HANDLER: Closing ultra logger"
    $ultra_logger.close
  end
end

# Main execution with enhanced error handling
if __FILE__ == $0
  begin
    $ultra_logger.log "🚀 MAIN: Starting enhanced test runner"
    enhanced_load_test_files
    
    $ultra_logger.log "🎬 MAIN: Starting Minitest execution"
    # Run tests normally - our hooks will provide the progress reporting
    exit_code = Minitest.run([])
    $ultra_logger.log "🏁 MAIN: Minitest execution completed with exit code #{exit_code}"
    exit(exit_code)
  rescue => e
    $ultra_logger.log "💥 MAIN_ERROR: Fatal error in main execution: #{e.message}", level: :error
    $ultra_logger.emergency_shutdown("Fatal error in main execution: #{e.message}")
    exit(1)
  end
end