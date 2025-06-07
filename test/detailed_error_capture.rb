#!/usr/bin/env ruby

# Detailed Error Capture Script
# Captures actual error messages and categorizes them properly

require 'fileutils'
require 'json'
require 'time'

class DetailedErrorCapture
  def initialize
    @base_path = File.dirname(__FILE__)
    @categories = {
      'infrastructure' => 120,
      'ruby_implementation' => 60,
      'patlang_language' => 180
    }
    @results = {
      'summary' => {},
      'detailed_errors' => {},
      'error_categorization' => {}
    }
  end

  def analyze_all_categories
    puts "🔍 DETAILED ERROR CAPTURE STARTING"
    puts "=" * 60
    puts

    @categories.each do |category, timeout|
      puts "🧪 Capturing errors for #{category.upcase}..."
      @results['detailed_errors'][category] = capture_category_errors(category)
      puts
    end

    categorize_all_errors
    save_detailed_results
    display_error_summary

    @results
  end

  def capture_category_errors(category)
    category_dir = File.join(@base_path, category)
    test_files = Dir.glob(File.join(category_dir, 'test_*.rb')).sort
    
    category_results = {
      'files_analyzed' => test_files.length,
      'file_details' => {}
    }

    test_files.each do |file_path|
      filename = File.basename(file_path, '.rb')
      puts "  📄 Capturing #{filename}..."
      
      file_result = capture_file_errors(file_path)
      category_results['file_details'][filename] = file_result
    end

    category_results
  end

  def capture_file_errors(file_path)
    filename = File.basename(file_path, '.rb')
    
    # Create a script that runs the test and captures all output
    output_file = File.join(@base_path, "temp_#{filename}_output.txt")
    
    # Use system to run ruby with output redirection
    cmd = "ruby -Itest -I. #{file_path} > #{output_file} 2>&1"
    
    start_time = Time.now
    success = system(cmd)
    execution_time = Time.now - start_time
    
    # Read the captured output
    output = File.exist?(output_file) ? File.read(output_file) : ""
    
    # Clean up
    File.delete(output_file) if File.exist?(output_file)
    
    # Analyze the output
    result = {
      'success' => success,
      'execution_time' => execution_time.round(2),
      'exit_status' => $?.exitstatus,
      'raw_output' => output,
      'error_analysis' => analyze_output(output, success)
    }
    
    result
  end

  def analyze_output(output, success)
    analysis = {
      'has_errors' => false,
      'has_failures' => false,
      'error_types' => [],
      'failure_types' => [],
      'critical_issues' => [],
      'summary_stats' => extract_test_stats(output)
    }

    if !success || output.include?('Error:') || output.include?('error')
      analysis['has_errors'] = true
      analysis['error_types'] = extract_error_types(output)
    end

    if output.include?('Failure:') || output.include?('failure')
      analysis['has_failures'] = true
      analysis['failure_types'] = extract_failure_types(output)
    end

    # Look for critical issues
    critical_patterns = [
      'NameError: uninitialized constant',
      'NoMethodError: undefined method',
      'LoadError:',
      'SyntaxError:',
      'ArgumentError:',
      'RuntimeError:'
    ]

    critical_patterns.each do |pattern|
      if output.include?(pattern)
        analysis['critical_issues'] << pattern
      end
    end

    analysis
  end

  def extract_test_stats(output)
    stats = {}
    
    # Look for minitest output patterns
    if match = output.match(/(\d+) runs?, (\d+) assertions?, (\d+) failures?, (\d+) errors?, (\d+) skips?/)
      stats['runs'] = match[1].to_i
      stats['assertions'] = match[2].to_i
      stats['failures'] = match[3].to_i
      stats['errors'] = match[4].to_i
      stats['skips'] = match[5].to_i
    end

    stats
  end

  def extract_error_types(output)
    error_types = []
    
    # Common error patterns
    error_patterns = {
      'NameError' => /NameError: (.+)/,
      'NoMethodError' => /NoMethodError: (.+)/,
      'LoadError' => /LoadError: (.+)/,
      'SyntaxError' => /SyntaxError: (.+)/,
      'ArgumentError' => /ArgumentError: (.+)/,
      'RuntimeError' => /RuntimeError: (.+)/,
      'TypeError' => /TypeError: (.+)/,
      'StandardError' => /Error: (.+)/
    }

    error_patterns.each do |type, pattern|
      matches = output.scan(pattern)
      matches.each do |match|
        error_types << {
          'type' => type,
          'message' => match.is_a?(Array) ? match[0] : match
        }
      end
    end

    error_types
  end

  def extract_failure_types(output)
    failure_types = []
    
    # Look for failure patterns
    failure_lines = output.split("\n").select { |line| line.include?('Failure:') }
    failure_lines.each do |line|
      if match = line.match(/Failure:\s*(.+)/)
        failure_types << {
          'type' => 'TestFailure',
          'description' => match[1]
        }
      end
    end

    failure_types
  end

  def categorize_all_errors
    error_summary = {
      'total_files' => 0,
      'files_with_errors' => 0,
      'files_with_failures' => 0,
      'most_common_errors' => {},
      'most_common_failures' => {},
      'critical_issues_summary' => {}
    }

    @results['detailed_errors'].each do |category, data|
      error_summary['total_files'] += data['files_analyzed']
      
      data['file_details'].each do |filename, details|
        analysis = details['error_analysis']
        
        if analysis['has_errors']
          error_summary['files_with_errors'] += 1
          
          analysis['error_types'].each do |error|
            type = error['type']
            error_summary['most_common_errors'][type] ||= 0
            error_summary['most_common_errors'][type] += 1
          end
        end

        if analysis['has_failures']
          error_summary['files_with_failures'] += 1
        end

        analysis['critical_issues'].each do |issue|
          error_summary['critical_issues_summary'][issue] ||= 0
          error_summary['critical_issues_summary'][issue] += 1
        end
      end
    end

    @results['error_categorization'] = error_summary
  end

  def save_detailed_results
    output_file = File.join(@base_path, 'DETAILED_ERROR_CAPTURE_REPORT.json')
    File.write(output_file, JSON.pretty_generate(@results))
    puts "📄 Detailed error capture saved to: #{output_file}"
  end

  def display_error_summary
    puts "=" * 60
    puts "📊 DETAILED ERROR ANALYSIS SUMMARY"
    puts "=" * 60
    
    summary = @results['error_categorization']
    
    puts "📁 Total Files Analyzed: #{summary['total_files']}"
    puts "❌ Files with Errors: #{summary['files_with_errors']}"
    puts "⚠️  Files with Failures: #{summary['files_with_failures']}"
    puts

    if summary['most_common_errors'].any?
      puts "🔥 MOST COMMON ERROR TYPES:"
      summary['most_common_errors'].sort_by { |k, v| -v }.each do |error_type, count|
        puts "   #{error_type.ljust(20)}: #{count} occurrences"
      end
      puts
    end

    if summary['critical_issues_summary'].any?
      puts "⚡ CRITICAL ISSUES:"
      summary['critical_issues_summary'].sort_by { |k, v| -v }.each do |issue, count|
        puts "   #{issue.ljust(40)}: #{count} files affected"
      end
      puts
    end

    puts "📋 CATEGORY BREAKDOWN:"
    @results['detailed_errors'].each do |category, data|
      error_count = 0
      failure_count = 0
      
      data['file_details'].each do |filename, details|
        analysis = details['error_analysis']
        error_count += 1 if analysis['has_errors']
        failure_count += 1 if analysis['has_failures']
      end
      
      puts "   #{category.ljust(20)}: #{data['files_analyzed']} files, #{error_count} errors, #{failure_count} failures"
    end
  end
end

# Main execution
if __FILE__ == $0
  capturer = DetailedErrorCapture.new
  
  begin
    results = capturer.analyze_all_categories
    puts "🎉 Detailed error capture completed!"
  rescue => e
    puts "❌ Error capture failed: #{e.class}: #{e.message}"
    puts "Backtrace:"
    e.backtrace&.each { |line| puts "  #{line}" }
    exit 1
  end
end