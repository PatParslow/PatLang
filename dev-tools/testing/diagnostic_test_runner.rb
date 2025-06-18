#!/usr/bin/env ruby
# frozen_string_literal: true

puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🔧 DIAGNOSTIC: Starting minimal test runner"

# Test each component step by step to find the hang point
begin
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 📋 STEP 1: Loading basic libraries"
  require 'pathname'
  require 'timeout'
  require 'thread'
  require 'monitor'
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ✅ STEP 1: Basic libraries loaded"

  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 📋 STEP 2: Testing SimpleCov loading"
  require 'simplecov'
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ✅ STEP 2: SimpleCov loaded"

  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 📋 STEP 3: Testing SimpleCov configuration"
  SimpleCov.start do
    enable_coverage :branch
    add_filter '/test/'
    track_files 'src/**/*.rb'
    formatter SimpleCov::Formatter::SimpleFormatter
    minimum_coverage line: 95, branch: 90
  end
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ✅ STEP 3: SimpleCov configured"

  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 📋 STEP 4: Testing test_helper loading"
  
  # Try loading test_helper with timeout
  Timeout::timeout(30) do
    require_relative 'helpers/test_helper'
  end
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ✅ STEP 4: test_helper loaded"

  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 📋 STEP 5: Testing file discovery"
  test_dir = File.dirname(__FILE__)
  test_files = Dir.glob(File.join(test_dir, '**', 'test_*.rb')).sort
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ✅ STEP 5: Found #{test_files.length} test files"

  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 📋 STEP 6: Testing Minitest availability"
  puts "Minitest defined: #{defined?(Minitest)}"
  puts "Minitest::Test defined: #{defined?(Minitest::Test)}"
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ✅ STEP 6: Minitest check complete"

  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 📋 STEP 7: Testing individual test file loading"
  
  excluded_files = [
    'test_helper.rb',
    'run_all_tests.rb', 
    'enhanced_test_runner.rb',
    'enhanced_test_runner_simple.rb',
    'progress_test_runner.rb',
    'real_time_test_runner.rb',
    'enhanced_real_time_test_runner.rb',
    'diagnostic_test_runner.rb'
  ]
  
  test_files_to_load = test_files.select do |file|
    basename = File.basename(file)
    !excluded_files.include?(basename) && basename.start_with?('test_')
  end

  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 📁 Will attempt to load #{test_files_to_load.length} files:"
  test_files_to_load.each_with_index do |file, index|
    relative_path = Pathname.new(file).relative_path_from(Pathname.new(test_dir)).to_s
    puts "   #{index + 1}. #{relative_path}"
  end

  # Load files one by one with individual timeouts
  loaded_files = 0
  test_files_to_load.each_with_index do |file, index|
    relative_path = Pathname.new(file).relative_path_from(Pathname.new(test_dir)).to_s
    
    puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 📂 Loading #{index + 1}/#{test_files_to_load.length}: #{relative_path}"
    
    begin
      Timeout::timeout(10) do  # 10 second timeout per file
        require_relative relative_path.sub('.rb', '')
        loaded_files += 1
        puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ✅ Loaded: #{relative_path}"
      end
    rescue Timeout::Error
      puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ⏰ TIMEOUT: #{relative_path} took > 10s"
      puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🚨 HANG DETECTED IN FILE: #{relative_path}"
      break
    rescue => e
      puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ❌ ERROR: #{relative_path} - #{e.message}"
      puts "   Backtrace: #{e.backtrace.first(3).join(', ')}"
    end
  end

  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ✅ STEP 7: Loaded #{loaded_files}/#{test_files_to_load.length} files"

  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 📋 STEP 8: Testing Minitest execution"
  puts "Running basic Minitest.run test..."
  
  # Try a minimal Minitest run
  Timeout::timeout(30) do
    result = Minitest.run([])
    puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ✅ STEP 8: Minitest completed with result: #{result}"
  end

rescue Timeout::Error => e
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ⏰ TIMEOUT: Operation timed out - #{e.message}"
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🚨 HANG LOCATION IDENTIFIED"
rescue => e
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 💥 ERROR: #{e.message}"
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] Backtrace:"
  e.backtrace.each { |line| puts "   #{line}" }
end

puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🏁 DIAGNOSTIC: Test runner diagnostic complete"