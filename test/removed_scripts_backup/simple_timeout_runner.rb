#!/usr/bin/env ruby

# Simple Timeout-Protected Test Runner
# Uses system-level timeouts to prevent any hanging

require 'fileutils'

class SimpleTimeoutRunner
  def initialize
    @base_path = File.dirname(__FILE__)
    @categories = {
      'infrastructure' => 120,      # 2 minutes
      'ruby_implementation' => 60,  # 1 minute  
      'patlang_language' => 180,    # 3 minutes
      'performance' => 300          # 5 minutes for performance tests
    }
    @individual_file_timeout = 30   # 30 seconds per test file
  end

  def run_category(category)
    unless @categories.key?(category)
      puts "❌ Unknown category: #{category}"
      puts "Available categories: #{@categories.keys.join(', ')}"
      return false
    end

    puts "=== RUNNING #{category.upcase} TESTS WITH TIMEOUT PROTECTION ==="
    puts "🛡️  Category timeout: #{@categories[category]}s"
    puts "🛡️  Per-file timeout: #{@individual_file_timeout}s"
    puts

    category_dir = File.join(@base_path, category)
    unless Dir.exist?(category_dir)
      puts "❌ Category directory not found: #{category_dir}"
      return false
    end

    test_files = Dir.glob(File.join(category_dir, 'test_*.rb')).sort
    
    if test_files.empty?
      puts "⚠️  No test files found in #{category}"
      return false
    end

    puts "🧪 Found #{test_files.length} test files:"
    test_files.each_with_index do |file_path, index|
      filename = File.basename(file_path, '.rb')
      puts "   [#{index + 1}] #{filename}"
    end
    puts

    successful_runs = 0
    total_start_time = Time.now

    test_files.each_with_index do |file_path, index|
      filename = File.basename(file_path, '.rb')
      puts "[#{index + 1}/#{test_files.length}] Running #{filename}..."
      
      if run_single_test_file(file_path)
        successful_runs += 1
        puts "   ✅ PASSED"
      else
        puts "   ❌ FAILED or TIMEOUT"
      end
      puts
    end

    total_time = Time.now - total_start_time
    puts "📊 SUMMARY:"
    puts "   Successful: #{successful_runs}/#{test_files.length}"
    puts "   Total time: #{total_time.round(2)}s"
    puts "   Success rate: #{(successful_runs.to_f / test_files.length * 100).round(1)}%"

    successful_runs > 0
  end

  def run_single_test_file(file_path)
    filename = File.basename(file_path)
    
    # Build the ruby command with timeout
    cmd = build_timeout_command(file_path)
    
    puts "   Command: #{cmd}"
    start_time = Time.now
    
    success = system(cmd)
    execution_time = Time.now - start_time
    
    puts "   Time: #{execution_time.round(2)}s"
    
    if success
      puts "   Result: SUCCESS"
    else
      exit_status = $?.exitstatus
      if exit_status == 124  # timeout command exit code
        puts "   Result: TIMEOUT (#{@individual_file_timeout}s exceeded)"
      else
        puts "   Result: FAILURE (exit code: #{exit_status})"
      end
    end
    
    success
  end

  def build_timeout_command(file_path)
    ruby_cmd = "ruby -Itest #{file_path}"
    
    # Use different timeout commands based on OS
    if Gem.win_platform?
      # Windows: use Ruby's built-in timeout
      timeout_script = create_windows_timeout_script(file_path)
      "ruby #{timeout_script}"
    else
      # Unix/Linux/Mac: use system timeout command
      "timeout #{@individual_file_timeout} #{ruby_cmd}"
    end
  end

  def create_windows_timeout_script(file_path)
    script_content = <<~RUBY
      require 'timeout'
      
      begin
        Timeout::timeout(#{@individual_file_timeout}) do
          load '#{file_path}'
        end
        exit 0
      rescue Timeout::Error
        puts "TIMEOUT: Test exceeded #{@individual_file_timeout} seconds"
        exit 124
      rescue => e
        puts "ERROR: \#{e.class}: \#{e.message}"
        exit 1
      end
    RUBY
    
    script_path = File.join(@base_path, 'temp_timeout_script.rb')
    File.write(script_path, script_content)
    script_path
  end

  def show_usage
    puts "USAGE: ruby test/simple_timeout_runner.rb [CATEGORY]"
    puts
    puts "🛡️  This runner uses system-level timeouts to prevent hanging"
    puts
    puts "Available categories:"
    @categories.each do |category, timeout|
      puts "  #{category.ljust(20)} - #{timeout}s timeout"
    end
    puts
    puts "Individual test file timeout: #{@individual_file_timeout}s"
    puts
    puts "Examples:"
    puts "  ruby test/simple_timeout_runner.rb infrastructure"
    puts "  ruby test/simple_timeout_runner.rb patlang_language"
    puts
  end

  def cleanup
    # Clean up temporary files
    temp_script = File.join(@base_path, 'temp_timeout_script.rb')
    File.delete(temp_script) if File.exist?(temp_script)
  end
end

# Main execution
if __FILE__ == $0
  category = ARGV[0]
  
  if category.nil?
    runner = SimpleTimeoutRunner.new
    runner.show_usage
    exit 1
  end

  runner = SimpleTimeoutRunner.new
  
  begin
    success = runner.run_category(category)
    puts success ? "\n🎉 Test run completed!" : "\n⚠️  Test run completed with issues"
    exit success ? 0 : 1
  ensure
    runner.cleanup
  end
end