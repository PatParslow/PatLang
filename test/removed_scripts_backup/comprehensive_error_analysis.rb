#!/usr/bin/env ruby

# Comprehensive Error Analysis for PATLang Test Suite
# Captures detailed error information across all test categories

require 'fileutils'
require 'json'
require 'time'

class ComprehensiveErrorAnalysis
  def initialize
    @base_path = File.dirname(__FILE__)
    @categories = {
      'infrastructure' => 120,
      'ruby_implementation' => 60,
      'patlang_language' => 180
    }
    @individual_file_timeout = 30
    @results = {
      'summary' => {},
      'categories' => {},
      'error_patterns' => {},
      'prioritized_fixes' => []
    }
  end

  def analyze_all_categories
    puts "🔍 COMPREHENSIVE ERROR ANALYSIS STARTING"
    puts "=" * 60
    puts

    total_files = 0
    total_errors = 0
    total_failures = 0
    total_success = 0

    @categories.each do |category, timeout|
      puts "🧪 Analyzing #{category.upcase} category..."
      result = analyze_category(category)
      
      @results['categories'][category] = result
      
      total_files += result['total_files']
      total_errors += result['errors'].length
      total_failures += result['failures'].length  
      total_success += result['successful_files']
      
      puts "   Files: #{result['total_files']}, Success: #{result['successful_files']}, Errors: #{result['errors'].length}, Failures: #{result['failures'].length}"
      puts
    end

    # Generate summary
    @results['summary'] = {
      'timestamp' => Time.now.iso8601,
      'total_files' => total_files,
      'total_success' => total_success,
      'total_errors' => total_errors,
      'total_failures' => total_failures,
      'success_rate' => (total_success.to_f / total_files * 100).round(1)
    }

    # Analyze error patterns
    analyze_error_patterns
    
    # Generate prioritized fixes
    generate_prioritized_fixes

    # Save results
    save_results

    # Display summary
    display_summary

    @results
  end

  def analyze_category(category)
    category_dir = File.join(@base_path, category)
    test_files = Dir.glob(File.join(category_dir, 'test_*.rb')).sort
    
    result = {
      'total_files' => test_files.length,
      'successful_files' => 0,
      'errors' => [],
      'failures' => [],
      'timeouts' => [],
      'execution_times' => []
    }

    test_files.each do |file_path|
      filename = File.basename(file_path, '.rb')
      puts "  📄 Analyzing #{filename}..."
      
      file_result = analyze_single_file(file_path)
      
      if file_result['success']
        result['successful_files'] += 1
      elsif file_result['timeout']
        result['timeouts'] << {
          'file' => filename,
          'timeout_duration' => @individual_file_timeout
        }
      elsif file_result['error_output'] && !file_result['error_output'].empty?
        # Categorize as error or failure based on output
        if contains_syntax_or_critical_error?(file_result['error_output'])
          result['errors'] << {
            'file' => filename,
            'category' => category,
            'error_output' => file_result['error_output'],
            'error_type' => classify_error_type(file_result['error_output']),
            'execution_time' => file_result['execution_time']
          }
        else
          result['failures'] << {
            'file' => filename,
            'category' => category,
            'failure_output' => file_result['error_output'],
            'failure_type' => classify_failure_type(file_result['error_output']),
            'execution_time' => file_result['execution_time']
          }
        end
      end
      
      result['execution_times'] << {
        'file' => filename,
        'time' => file_result['execution_time']
      }
    end

    result
  end

  def analyze_single_file(file_path)
    filename = File.basename(file_path)
    
    # Create a temporary script to capture both stdout and stderr
    capture_script = create_error_capture_script(file_path)
    
    start_time = Time.now
    success = system(capture_script)
    execution_time = Time.now - start_time
    
    # Read captured output
    output_file = File.join(@base_path, 'temp_test_output.txt')
    error_output = File.exist?(output_file) ? File.read(output_file).strip : ""
    
    # Clean up
    File.delete(capture_script) if File.exist?(capture_script)
    File.delete(output_file) if File.exist?(output_file)
    
    {
      'success' => success && error_output.empty?,
      'timeout' => execution_time >= @individual_file_timeout,
      'error_output' => error_output,
      'execution_time' => execution_time.round(2)
    }
  end

  def create_error_capture_script(file_path)
    script_content = <<~RUBY
      require 'timeout'
      
      output_file = '#{File.join(@base_path, 'temp_test_output.txt')}'
      
      begin
        Timeout::timeout(#{@individual_file_timeout}) do
          # Redirect both stdout and stderr to capture all output
          original_stdout = $stdout
          original_stderr = $stderr
          
          begin
            File.open(output_file, 'w') do |f|
              $stdout = f
              $stderr = f
              
              # Set up the load path
              $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))
              $LOAD_PATH.unshift(File.dirname(__FILE__))
              
              load '#{file_path}'
            end
          rescue => e
            File.open(output_file, 'a') do |f|
              f.puts "ERROR: \#{e.class}: \#{e.message}"
              f.puts "BACKTRACE:"
              e.backtrace&.each { |line| f.puts "  \#{line}" }
            end
            exit 1
          ensure
            $stdout = original_stdout
            $stderr = original_stderr
          end
        end
        
        # If we get here, the test completed without error
        File.write(output_file, "") unless File.exist?(output_file)
        exit 0
        
      rescue Timeout::Error
        File.open(output_file, 'w') do |f|
          f.puts "TIMEOUT: Test exceeded #{@individual_file_timeout} seconds"
        end
        exit 124
      end
    RUBY
    
    script_path = File.join(@base_path, 'temp_error_capture.rb')
    File.write(script_path, script_content)
    "ruby #{script_path}"
  end

  def contains_syntax_or_critical_error?(output)
    critical_patterns = [
      /syntax error/i,
      /undefined method/i,
      /uninitialized constant/i,
      /no such file to load/i,
      /cannot load such file/i,
      /wrong number of arguments/i,
      /name error/i,
      /load error/i
    ]
    
    critical_patterns.any? { |pattern| output =~ pattern }
  end

  def classify_error_type(output)
    case output
    when /syntax error/i then 'syntax_error'
    when /undefined method/i then 'undefined_method'
    when /uninitialized constant/i then 'uninitialized_constant'
    when /no such file to load|cannot load such file/i then 'load_error'
    when /wrong number of arguments/i then 'argument_error'
    when /name error/i then 'name_error'
    when /TIMEOUT/i then 'timeout'
    else 'unknown_error'
    end
  end

  def classify_failure_type(output)
    case output
    when /assertion failed/i then 'assertion_failure'
    when /expected.*but got/i then 'expectation_mismatch'
    when /test.*failed/i then 'test_failure'
    when /minitest/i then 'minitest_failure'
    else 'unknown_failure'
    end
  end

  def analyze_error_patterns
    all_errors = []
    @results['categories'].each do |category, data|
      all_errors += data['errors']
      all_errors += data['failures']
    end

    patterns = Hash.new(0)
    all_errors.each do |error|
      type = error['error_type'] || error['failure_type']
      patterns[type] += 1
    end

    @results['error_patterns'] = patterns.sort_by { |k, v| -v }.to_h
  end

  def generate_prioritized_fixes
    fixes = []

    # Priority 1: Critical errors affecting multiple files
    @results['error_patterns'].each do |error_type, count|
      if count >= 3 && ['undefined_method', 'uninitialized_constant', 'load_error'].include?(error_type)
        fixes << {
          'priority' => 1,
          'type' => error_type,
          'count' => count,
          'description' => describe_fix(error_type),
          'impact' => 'high'
        }
      end
    end

    # Priority 2: Single-file critical errors
    @results['categories'].each do |category, data|
      data['errors'].each do |error|
        if ['syntax_error', 'name_error'].include?(error['error_type'])
          fixes << {
            'priority' => 2,
            'type' => error['error_type'],
            'file' => error['file'],
            'category' => category,
            'description' => describe_fix(error['error_type']),
            'impact' => 'medium'
          }
        end
      end
    end

    # Priority 3: Test logic failures
    @results['categories'].each do |category, data|
      data['failures'].each do |failure|
        fixes << {
          'priority' => 3,
          'type' => failure['failure_type'],
          'file' => failure['file'],
          'category' => category,
          'description' => describe_fix(failure['failure_type']),
          'impact' => 'low'
        }
      end
    end

    @results['prioritized_fixes'] = fixes.sort_by { |fix| [fix['priority'], -fix.fetch('count', 1)] }
  end

  def describe_fix(error_type)
    case error_type
    when 'undefined_method' then 'Implement missing methods'
    when 'uninitialized_constant' then 'Define missing constants/classes'
    when 'load_error' then 'Fix require paths or missing files'
    when 'syntax_error' then 'Fix syntax issues'
    when 'name_error' then 'Fix variable/method naming issues'
    when 'argument_error' then 'Fix method argument mismatches'
    when 'assertion_failure' then 'Update test assertions'
    when 'expectation_mismatch' then 'Fix expected vs actual value issues'
    when 'test_failure' then 'Fix test logic'
    else 'Investigate and fix'
    end
  end

  def save_results
    output_file = File.join(@base_path, 'COMPREHENSIVE_ERROR_ANALYSIS_REPORT.json')
    File.write(output_file, JSON.pretty_generate(@results))
    puts "📄 Detailed results saved to: #{output_file}"
  end

  def display_summary
    puts "=" * 60
    puts "📊 COMPREHENSIVE ERROR ANALYSIS SUMMARY"
    puts "=" * 60
    
    summary = @results['summary']
    puts "📅 Timestamp: #{summary['timestamp']}"
    puts "📁 Total Files: #{summary['total_files']}"
    puts "✅ Successful: #{summary['total_success']} (#{summary['success_rate']}%)"
    puts "❌ Errors: #{summary['total_errors']}"
    puts "⚠️  Failures: #{summary['total_failures']}"
    puts

    puts "🏷️  ERROR PATTERNS:"
    @results['error_patterns'].each do |type, count|
      puts "   #{type.ljust(25)}: #{count} occurrences"
    end
    puts

    puts "🎯 TOP PRIORITY FIXES:"
    @results['prioritized_fixes'].first(5).each_with_index do |fix, index|
      puts "   [#{index + 1}] Priority #{fix['priority']}: #{fix['description']}"
      if fix['count']
        puts "       Affects #{fix['count']} files (#{fix['impact']} impact)"
      else
        puts "       File: #{fix['file']} in #{fix['category']} (#{fix['impact']} impact)"
      end
    end
    puts
  end
end

# Main execution
if __FILE__ == $0
  analyzer = ComprehensiveErrorAnalysis.new
  
  begin
    results = analyzer.analyze_all_categories
    puts "🎉 Comprehensive error analysis completed!"
    
    if results['summary']['total_errors'] == 0 && results['summary']['total_failures'] == 0
      puts "🎉 No errors or failures detected!"
      exit 0
    else
      puts "⚠️  #{results['summary']['total_errors']} errors and #{results['summary']['total_failures']} failures detected"
      puts "📋 Check COMPREHENSIVE_ERROR_ANALYSIS_REPORT.json for detailed information"
      exit 1
    end
  rescue => e
    puts "❌ Analysis failed: #{e.class}: #{e.message}"
    puts "Backtrace:"
    e.backtrace&.each { |line| puts "  #{line}" }
    exit 1
  end
end