#!/usr/bin/env ruby

require 'fileutils'

class UnifiedTestRunner
  def initialize
    @passed_tests = 0
    @failed_tests = 0
    @skipped_tests = 0
    @errors = []
    @test_results = {}
  end
  
  def run(pattern = nil)
    puts "🧪 Unified Test Runner - Running tests with new directory structure"
    puts "=" * 80
    
    # Set up load paths for new structure
    setup_load_paths
    
    # Find and run tests
    test_files = find_test_files(pattern)
    puts "📁 Found #{test_files.size} test files to run"
    
    test_files.each { |file| run_test_file(file) }
    
    # Generate summary report
    generate_summary
  end
  
  private
  
  def setup_load_paths
    # Add new directory structure to load path
    project_root = File.expand_path('..', __dir__)
    $LOAD_PATH.unshift(File.join(project_root, 'patlang-core'))
    $LOAD_PATH.unshift(File.join(project_root, 'patlang-core', 'lexer'))
    $LOAD_PATH.unshift(File.join(project_root, 'patlang-core', 'parser'))
    $LOAD_PATH.unshift(File.join(project_root, 'patlang-core', 'evaluator'))
    $LOAD_PATH.unshift(File.join(project_root, 'patlang-core', 'ast'))
    $LOAD_PATH.unshift(File.join(project_root, 'patlang-core', 'reasoning'))
    $LOAD_PATH.unshift(File.join(project_root, 'patlang-core', 'object_model'))
    $LOAD_PATH.unshift(File.join(project_root, 'ruby-host', 'bootstrap'))
    
    puts "✅ Load paths configured for new directory structure"
  end
  
  def find_test_files(pattern)
    if pattern
      Dir.glob("test/**/#{pattern}")
    else
      # Find all test files but exclude backup and removed directories
      Dir.glob("test/**/*.rb").reject do |f|
        f.include?('removed_scripts_backup') || 
        f.include?('fix_test_requires.rb') ||
        f.include?('unified_test_runner.rb')
      end
    end.select { |f| File.file?(f) }
  end
  
  def run_test_file(file_path)
    puts "\n🔬 Running: #{file_path}"
    
    begin
      # Run the test file and capture output
      start_time = Time.now
      
      # Use system to run the test and capture the result
      result = system("ruby -I. #{file_path}")
      
      end_time = Time.now
      duration = end_time - start_time
      
      if result
        @passed_tests += 1
        @test_results[file_path] = { status: 'PASSED', duration: duration }
        puts "  ✅ PASSED (#{duration.round(2)}s)"
      else
        @failed_tests += 1
        @test_results[file_path] = { status: 'FAILED', duration: duration }
        puts "  ❌ FAILED (#{duration.round(2)}s)"
      end
      
    rescue => e
      @errors << { file: file_path, error: e.message }
      @failed_tests += 1
      @test_results[file_path] = { status: 'ERROR', duration: 0, error: e.message }
      puts "  💥 ERROR: #{e.message}"
    end
  end
  
  def generate_summary
    puts "\n" + "=" * 80
    puts "📊 TEST EXECUTION SUMMARY"
    puts "=" * 80
    puts "Total tests run: #{@passed_tests + @failed_tests}"
    puts "Passed: #{@passed_tests}"
    puts "Failed: #{@failed_tests}"
    puts "Success rate: #{(@passed_tests.to_f / (@passed_tests + @failed_tests) * 100).round(1)}%" if (@passed_tests + @failed_tests) > 0
    
    if @test_results.any?
      puts "\n📋 DETAILED RESULTS:"
      @test_results.each do |file, result|
        status_icon = case result[:status]
                     when 'PASSED' then '✅'
                     when 'FAILED' then '❌'
                     when 'ERROR' then '💥'
                     end
        puts "  #{status_icon} #{File.basename(file)}: #{result[:status]} (#{result[:duration].round(2)}s)"
        puts "     Error: #{result[:error]}" if result[:error]
      end
    end
    
    if @errors.any?
      puts "\n❌ ERRORS ENCOUNTERED:"
      @errors.each { |error| puts "  • #{error[:file]}: #{error[:error]}" }
    end
    
    puts "\n✅ Test execution complete!"
  end
end

# Command line interface
if __FILE__ == $0
  pattern = ARGV[0]  # Optional test file pattern
  
  runner = UnifiedTestRunner.new
  runner.run(pattern)
end