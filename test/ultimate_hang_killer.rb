#!/usr/bin/env ruby
# frozen_string_literal: true

require 'simplecov'
require 'pathname'
require 'timeout'
require 'thread'

# Load hang prevention patches first
require_relative 'hang_prevention_patches'

# Minimal SimpleCov configuration
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  track_files 'src/**/*.rb'
  formatter SimpleCov::Formatter::SimpleFormatter
  minimum_coverage line: 95, branch: 90
end

# Always load test_helper first
require_relative 'helpers/test_helper'

class UltimateHangKiller
  def initialize
    @start_time = Time.now
    @current_test_start = nil
    @test_count = 0
    @completed_tests = 0
    @failed_tests = []
    @slow_tests = []
    @hanging_tests = []
    @timeout_threshold = 6  # Ultra-short timeout
    @test_mutex = Mutex.new
    @timeout_monitor = nil
    @active_test = nil
    @emergency_triggered = false
    @watchdog_pid = nil
    @main_process_pid = Process.pid
    @hang_count = 0
    @max_hangs = 0  # Absolute zero tolerance
    @last_heartbeat = Time.now
    @heartbeat_thread = nil
    @force_kill_timeout = 12  # Absolute max time for any test
  end

  def log_with_timestamp(message, flush: true)
    timestamp = Time.now.strftime("%H:%M:%S.%3N")
    puts "[#{timestamp}] #{message}"
    STDOUT.flush if flush
  end

  def suite_started
    log_with_timestamp("=" * 80)
    log_with_timestamp("💀 ULTIMATE HANG KILLER - ABSOLUTE ZERO TOLERANCE")
    log_with_timestamp("=" * 80)
    log_with_timestamp("⏰ Started at: #{@start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    log_with_timestamp("🔥 Ultra-aggressive hang detection: #{@timeout_threshold}s per test")
    log_with_timestamp("💀 Absolute force kill timeout: #{@force_kill_timeout}s")
    log_with_timestamp("🚫 ZERO tolerance: ANY hang = IMMEDIATE TERMINATION")
    log_with_timestamp("🛡️  Multiple protection layers active")
    log_with_timestamp("=" * 80)
    
    # Tighten global timeout configuration
    GlobalTimeoutConfig.tighten_all(0.3)  # Make all timeouts 30% of original
    GlobalTimeoutConfig.summary
    
    # Start multiple protection layers
    start_external_watchdog
    start_heartbeat_monitor
    start_force_kill_timer
  end

  def start_external_watchdog
    @watchdog_pid = fork do
      Process.setproctitle("UltimateHangKillerWatchdog")
      
      watchdog_timeout = 15  # 15 second absolute max
      
      loop do
        sleep(0.5)  # Check every 0.5 seconds
        
        # Check if main process is alive
        begin
          Process.getpgid(@main_process_pid)
        rescue Errno::ESRCH
          exit(0)  # Main process died
        end
        
        # Check heartbeat
        if File.exist?('.test_heartbeat')
          heartbeat_time = File.mtime('.test_heartbeat')
          if Time.now - heartbeat_time > watchdog_timeout
            puts ""
            puts "💀" * 40
            puts "ULTIMATE HANG KILLER: WATCHDOG TERMINATION"
            puts "💀" * 40
            puts "Last heartbeat: #{heartbeat_time}"
            puts "Hang duration: #{(Time.now - heartbeat_time).round(1)}s"
            puts "FORCE KILLING MAIN PROCESS #{@main_process_pid}"
            
            # Nuclear option: kill the entire process group
            begin
              Process.kill('KILL', -@main_process_pid)  # Kill process group
            rescue => e
              puts "Error killing process group: #{e.message}"
              begin
                Process.kill('KILL', @main_process_pid)  # Kill main process
              rescue => e2
                puts "Error killing main process: #{e2.message}"
              end
            end
            
            File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
            exit(9)  # Exit code 9 = killed by watchdog
          end
        else
          update_heartbeat
        end
      end
    end
  end

  def start_heartbeat_monitor
    @heartbeat_thread = Thread.new do
      Thread.current.name = "HeartbeatMonitor"
      
      loop do
        sleep(1)
        update_heartbeat
        @last_heartbeat = Time.now
        
        # Check if we should still be alive
        break if @emergency_triggered
      end
    end
  end

  def start_force_kill_timer
    Thread.new do
      Thread.current.name = "ForceKillTimer"
      
      # Absolute maximum runtime for the entire test suite
      max_runtime = 300  # 5 minutes absolute max
      
      sleep(max_runtime)
      
      unless @emergency_triggered
        log_with_timestamp("💀 FORCE KILL: Test suite exceeded maximum runtime (#{max_runtime}s)")
        force_nuclear_shutdown("Maximum runtime exceeded")
      end
    end
  end

  def update_heartbeat
    begin
      File.write('.test_heartbeat', "#{Time.now.to_f}|#{@active_test || 'idle'}|#{Process.pid}")
    rescue => e
      # Ignore heartbeat errors
    end
  end

  def test_started(test_class, test_method)
    return if @emergency_triggered
    
    @test_mutex.synchronize do
      @current_test_start = Time.now
      @test_count += 1
      @active_test = "#{test_class}##{test_method}"
      
      log_with_timestamp("🧪 [#{@test_count}] STARTING: #{@active_test}")
      update_heartbeat
      
      # Reset global loop detector for each test
      $global_loop_detector.reset_all
      
      # Start ultra-aggressive timeout monitor
      @timeout_monitor = Thread.new do
        Thread.current.name = "UltraTimeoutMonitor"
        monitor_test_execution_ultra_aggressively
      end
    end
  end

  def monitor_test_execution_ultra_aggressively
    sleep_interval = 0.2  # Check every 0.2 seconds
    elapsed = 0.0
    warning_intervals = [2, 4, 5]  # Warn at 2s, 4s, 5s
    warnings_given = []
    
    while elapsed < @timeout_threshold && @current_test_start && !@emergency_triggered
      sleep(sleep_interval)
      elapsed = Time.now - @current_test_start if @current_test_start
      
      # Update heartbeat frequently
      update_heartbeat if elapsed % 1 < sleep_interval  # Every 1 second
      
      # Progressive warnings
      warning_intervals.each do |interval|
        if elapsed > interval && !warnings_given.include?(interval)
          case interval
          when 2
            log_with_timestamp("⚠️  WARNING: #{@active_test} running for #{elapsed.round(1)}s")
          when 4
            log_with_timestamp("🚨 CRITICAL: #{@active_test} approaching kill zone (#{elapsed.round(1)}s)")
          when 5
            log_with_timestamp("💀 FINAL WARNING: #{@active_test} in death zone (#{elapsed.round(1)}s)")
          end
          warnings_given << interval
        end
      end
    end
    
    # If we get here, the test has hung - KILL IT IMMEDIATELY
    if @current_test_start && elapsed >= @timeout_threshold && !@emergency_triggered
      execute_immediate_termination(elapsed)
    end
  rescue => e
    log_with_timestamp("💥 MONITOR ERROR: #{e.message}")
  end

  def execute_immediate_termination(elapsed)
    @emergency_triggered = true
    @hang_count += 1
    
    log_with_timestamp("💀" * 30)
    log_with_timestamp("ULTIMATE HANG KILLER: IMMEDIATE TERMINATION")
    log_with_timestamp("💀" * 30)
    log_with_timestamp("🎯 HANGING TEST: #{@active_test}")
    log_with_timestamp("⏱️  HANG DURATION: #{elapsed.round(1)}s")
    log_with_timestamp("💀 ZERO TOLERANCE: Executing immediate termination")
    
    @hanging_tests << {
      name: @active_test,
      duration: elapsed,
      timestamp: Time.now
    }
    
    log_ultimate_hang_analysis
    force_nuclear_shutdown("Test hang detected")
  end

  def log_ultimate_hang_analysis
    log_with_timestamp("")
    log_with_timestamp("💀 ULTIMATE HANG ANALYSIS - DEATH REPORT")
    log_with_timestamp("=" * 70)
    log_with_timestamp("🎯 Hanging test: #{@active_test}")
    log_with_timestamp("⏱️  Hang duration: #{@hanging_tests.last[:duration].round(1)}s") if @hanging_tests.any?
    log_with_timestamp("🕐 Death time: #{@hanging_tests.last[:timestamp]}") if @hanging_tests.any?
    log_with_timestamp("🔢 Total hangs detected: #{@hang_count}")
    log_with_timestamp("💀 Death sentence: IMMEDIATE TERMINATION")
    log_with_timestamp("")
    log_with_timestamp("🔍 ROOT CAUSE ANALYSIS (POST-MORTEM):")
    log_with_timestamp("  💀 FATAL: Infinite loop or deadlock in test execution")
    log_with_timestamp("  🎯 LOCATION: #{@active_test}")
    log_with_timestamp("  ⚡ LIKELY CAUSES:")
    log_with_timestamp("     1. Parser infinite loop in expression parsing")
    log_with_timestamp("     2. Evaluator deadlock in recursive evaluation")
    log_with_timestamp("     3. Reasoning engine infinite goal pursuit")
    log_with_timestamp("     4. Unification engine recursive loop")
    log_with_timestamp("     5. I/O blocking without timeout")
    log_with_timestamp("     6. Thread synchronization deadlock")
    log_with_timestamp("")
    log_with_timestamp("💡 CRITICAL ACTIONS REQUIRED:")
    log_with_timestamp("  1. 🔍 Examine #{@active_test} test case immediately")
    log_with_timestamp("  2. 🔧 Add aggressive loop counters to parser")
    log_with_timestamp("  3. ⏰ Implement forced timeouts in all operations")
    log_with_timestamp("  4. 🛡️  Add recursive depth limits everywhere")
    log_with_timestamp("  5. 💀 Consider nuclear options for problem components")
    log_with_timestamp("=" * 70)
  end

  def force_nuclear_shutdown(reason)
    log_with_timestamp("")
    log_with_timestamp("💀" * 50)
    log_with_timestamp("NUCLEAR SHUTDOWN INITIATED")
    log_with_timestamp("💀" * 50)
    log_with_timestamp("Reason: #{reason}")
    log_with_timestamp("Time: #{Time.now}")
    log_with_timestamp("Active test: #{@active_test}")
    log_with_timestamp("Process ID: #{Process.pid}")
    log_with_timestamp("")
    log_with_timestamp("🔥 Cleaning up all resources...")
    
    # Clean up everything
    cleanup_all_resources
    
    log_with_timestamp("💀 ULTIMATE HANG KILLER: MISSION ACCOMPLISHED")
    log_with_timestamp("Test suite terminated due to hanging behavior.")
    log_with_timestamp("No mercy for infinite loops.")
    log_with_timestamp("💀" * 50)
    
    # Nuclear exit - can't be caught or prevented
    Kernel.exit!(9)  # exit! bypasses all cleanup and exit handlers
  end

  def cleanup_all_resources
    begin
      # Kill watchdog
      if @watchdog_pid
        Process.kill('TERM', @watchdog_pid) rescue nil
        Process.waitpid(@watchdog_pid, Process::WNOHANG) rescue nil
      end
      
      # Kill heartbeat monitor
      @heartbeat_thread&.kill rescue nil
      
      # Kill timeout monitor
      @timeout_monitor&.kill rescue nil
      
      # Clean up files
      File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
    rescue => e
      # Ignore cleanup errors during nuclear shutdown
    end
  end

  def test_finished(test_class, test_method, result, error = nil)
    return if @emergency_triggered
    
    @test_mutex.synchronize do
      cleanup_timeout_monitor
      update_heartbeat
      
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
        
        # Flag slow tests more aggressively
        if duration > 2
          @slow_tests << { name: current_test, duration: duration }
          log_with_timestamp("     🐌 SLOW: #{duration.round(2)}s")
        end
        
        # Flag very slow tests as potential hangs
        if duration > 4
          log_with_timestamp("     💀 VERY SLOW: #{duration.round(2)}s - potential hang risk")
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
    
    cleanup_all_resources
    total_duration = Time.now - @start_time
    
    puts ""
    puts "=" * 80
    puts "💀 ULTIMATE HANG KILLER SUMMARY"
    puts "=" * 80
    puts "⏱️  Total execution time: #{total_duration.round(2)}s"
    puts "🧪 Tests executed: #{@completed_tests}"
    puts "💀 Hangs detected: #{@hang_count}"
    
    if @hang_count > 0
      puts ""
      puts "💀 DEATH REPORT: #{@hang_count} hanging test(s) terminated"
      @hanging_tests.each do |test|
        puts "   💀 #{test[:name]} (terminated after #{test[:duration].round(1)}s)"
      end
      puts ""
      puts "❌ TEST SUITE FAILED: Hangs detected and eliminated"
      exit(9)
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
      puts "🐌 Slow tests (>2s): #{@slow_tests.length}"
      @slow_tests.sort_by { |t| -t[:duration] }.first(3).each_with_index do |test, index|
        puts "   #{index + 1}. #{test[:name]}: #{test[:duration].round(3)}s"
      end
    end
    
    puts "=" * 80
    puts "💀 SUCCESS: Ultimate hang killer completed - zero hangs tolerated"
    puts "🏆 All hanging tests were eliminated with extreme prejudice"
    puts "=" * 80
  end
end

# Thread-safe minitest hooks for ultimate hang killer
module UltimateHangKillerHooks
  @@reporter = UltimateHangKiller.new
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

# Enhanced Minitest::Test with ultimate hang protection
class Minitest::Test
  alias_method :original_setup, :setup
  alias_method :original_teardown, :teardown
  
  def setup
    begin
      UltimateHangKillerHooks.safe_reporter_call(:test_started, self.class.name, self.name)
      
      # Wrap setup in timeout
      EmergencyTimeout.protect(3) do
        original_setup
      end
    rescue => e
      puts "[SETUP ERROR] #{self.class.name}##{self.name}: #{e.message}"
      raise
    end
  end
  
  def teardown
    begin
      # Wrap teardown in timeout
      EmergencyTimeout.protect(2) do
        original_teardown
      end
      
      result = if passed?
                 :pass
               elsif skipped?
                 :skip
               elsif failure && failure.is_a?(Minitest::Assertion)
                 :fail
               else
                 :error
               end
      
      UltimateHangKillerHooks.safe_reporter_call(:test_finished, self.class.name, self.name, result, failure)
    rescue => e
      puts "[TEARDOWN ERROR] #{self.class.name}##{self.name}: #{e.message}"
    end
  end
end

# Ultra-safe test file loading with immediate termination for problematic files
def load_test_files_with_nuclear_protection
  puts "🔍 Loading test files with nuclear protection..."
  
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
    'bulletproof_test_runner.rb',
    'ultimate_hang_killer.rb',
    'hang_prevention_patches.rb'
  ]
  
  test_files_to_load = test_files.select do |file|
    basename = File.basename(file)
    !excluded_files.include?(basename) && basename.start_with?('test_')
  end
  
  puts "📁 Loading #{test_files_to_load.length} test files with 2s nuclear timeout each:"
  
  loaded_count = 0
  test_files_to_load.each_with_index do |file, index|
    relative_path = Pathname.new(file).relative_path_from(Pathname.new(test_dir)).to_s
    print "   #{index + 1}/#{test_files_to_load.length}: #{relative_path}... "
    
    begin
      EmergencyTimeout.protect(2) do  # Ultra-short timeout
        require_relative relative_path.sub('.rb', '')
        loaded_count += 1
        puts "✅"
      end
    rescue Timeout::Error
      puts "💀 NUCLEAR TIMEOUT"
      puts "      💀 File loading timeout: #{relative_path}"
      puts "      🚫 ULTIMATE HANG KILLER: Cannot continue with problematic file"
      puts "      💀 This file contains infinite loops or hangs during loading"
      puts ""
      puts "💀" * 40
      puts "NUCLEAR TERMINATION: Problematic file detected during loading"
      puts "File: #{relative_path}"
      puts "Reason: Exceeded 2-second loading timeout"
      puts "💀" * 40
      Kernel.exit!(10)  # Exit code 10 = killed during file loading
    rescue => e
      puts "❌ ERROR: #{e.message}"
    end
  end
  
  puts "✅ Loaded #{loaded_count}/#{test_files_to_load.length} test files successfully"
  puts ""
  
  UltimateHangKillerHooks.reporter.suite_started
end

# Exit handler with nuclear cleanup
at_exit do
  begin
    if defined?(UltimateHangKillerHooks)
      UltimateHangKillerHooks.reporter.suite_finished 
    end
  rescue => e
    puts "[EXIT ERROR] #{e.message}"
  ensure
    File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
  end
end

# Signal handlers for nuclear shutdown
Signal.trap('INT') do
  puts ""
  puts "💀 INTERRUPT SIGNAL: Nuclear shutdown initiated"
  File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
  Kernel.exit!(130)
end

Signal.trap('TERM') do
  puts ""
  puts "💀 TERMINATE SIGNAL: Nuclear shutdown initiated"  
  File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
  Kernel.exit!(143)
end

# Main execution with nuclear protection
if __FILE__ == $0
  begin
    puts "[#{Time.now.strftime("%H:%M:%S")}] 💀 Starting Ultimate Hang Killer"
    load_test_files_with_nuclear_protection
    
    puts "[#{Time.now.strftime("%H:%M:%S")}] 🎬 Starting Minitest execution"
    exit_code = Minitest.run([])
    puts "[#{Time.now.strftime("%H:%M:%S")}] 🏁 Minitest completed with exit code: #{exit_code}"
    
    File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
    exit(exit_code)
  rescue => e
    puts "[FATAL ERROR] #{e.message}"
    puts "Backtrace: #{e.backtrace.first(5).join(', ')}"
    File.delete('.test_heartbeat') if File.exist?('.test_heartbeat')
    Kernel.exit!(1)
  end
end