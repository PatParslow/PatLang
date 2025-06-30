#!/usr/bin/env ruby

require 'json'
require 'timeout'

# Patlang Example Files Validation Runner
# Systematically tests all example files to validate Phase 1 implementation

class PatlangExampleValidator
  def initialize
    @results = {
      total_files: 0,
      successful: 0,
      failed: 0,
      skipped: 0,
      execution_results: [],
      summary: {},
      timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z')
    }
    
    @timeout_seconds = 30
    @base_dir = File.expand_path('.')
  end

  def run_validation
    puts "🧪 PATLANG PHASE 1 EXAMPLE VALIDATION"
    puts "=" * 50
    puts "Validating Patlang example files execution..."
    puts "Base directory: #{@base_dir}"
    puts "Timeout per file: #{@timeout_seconds} seconds"
    puts

    # Discover example files
    example_files = discover_example_files
    @results[:total_files] = example_files.length

    puts "📁 DISCOVERED EXAMPLE FILES:"
    example_files.each_with_index do |file, index|
      puts "  #{index + 1}. #{file}"
    end
    puts

    # Test each file
    example_files.each do |file|
      test_example_file(file)
    end

    # Generate final report
    generate_report
    save_results_to_file
  end

  private

  def discover_example_files
    example_files = []
    
    # Look for different Patlang file extensions
    patterns = [
      'examples/**/*.patlang',
      'examples/**/*.pat', 
      'examples/**/*.rb'
    ]
    
    patterns.each do |pattern|
      Dir.glob(pattern).each do |file|
        # Skip certain files that are clearly not executable examples
        next if file.include?('README') || file.include?('.md')
        example_files << file
      end
    end
    
    example_files.sort
  end

  def test_example_file(file)
    puts "🔄 Testing: #{file}"
    
    result = {
      file: file,
      status: nil,
      output: nil,
      error: nil,
      execution_time: nil,
      file_size: File.size(file),
      interpreter_used: determine_interpreter(file)
    }

    start_time = Time.now
    
    begin
      # Check if file is marked as "not implemented"
      if file_marked_as_unimplemented?(file)
        result[:status] = 'skipped'
        result[:error] = 'File marked as not yet implemented'
        @results[:skipped] += 1
        puts "  ⏭️  SKIPPED: #{result[:error]}"
      else
        # Execute the file with appropriate interpreter
        output, error = execute_file_safely(file)
        
        result[:execution_time] = Time.now - start_time
        result[:output] = output
        result[:error] = error
        
        if error.nil? || error.strip.empty?
          result[:status] = 'success'
          @results[:successful] += 1
          puts "  ✅ SUCCESS (#{sprintf('%.2f', result[:execution_time])}s)"
          puts "     Output: #{output.length > 100 ? output[0..97] + '...' : output}" if output && !output.strip.empty?
        else
          result[:status] = 'failed'
          @results[:failed] += 1
          puts "  ❌ FAILED (#{sprintf('%.2f', result[:execution_time])}s)"
          puts "     Error: #{error.length > 200 ? error[0..197] + '...' : error}"
        end
      end
    rescue => e
      result[:status] = 'failed'
      result[:error] = e.message
      result[:execution_time] = Time.now - start_time
      @results[:failed] += 1
      puts "  💥 EXCEPTION: #{e.message}"
    end
    
    @results[:execution_results] << result
    puts
  end

  def file_marked_as_unimplemented?(file)
    return false unless File.exist?(file)
    
    # Read first 20 lines to check markers
    content = File.readlines(file).first(20).join
    
    markers = [
      'not yet implemented',
      'planned for v0.7.0+',
      'IMPLEMENTATION STATUS',
      'Roadmap Feature',
      '⚠️'
    ]
    
    markers.any? { |marker| content.include?(marker) }
  end

  def determine_interpreter(file)
    case File.extname(file)
    when '.patlang'
      'ruby src/patlang.rb'
    when '.pat'
      'ruby src/patlang.rb'
    when '.rb'
      'ruby'
    else
      'ruby src/patlang.rb'  # default
    end
  end

  def execute_file_safely(file)
    interpreter = determine_interpreter(file)
    command = "#{interpreter} #{file}"
    
    output = nil
    error = nil
    
    begin
      Timeout::timeout(@timeout_seconds) do
        # Capture both stdout and stderr
        require 'open3'
        output, error, status = Open3.capture3(command)
        
        # If command failed but no explicit error, check status
        if !status.success? && (error.nil? || error.strip.empty?)
          error = "Command exited with status #{status.exitstatus}"
        end
      end
    rescue Timeout::Error
      error = "Execution timed out after #{@timeout_seconds} seconds"
    rescue => e
      error = "Execution failed: #{e.message}"
    end
    
    [output, error]
  end

  def generate_report
    puts "📊 VALIDATION SUMMARY"
    puts "=" * 50
    
    success_rate = @results[:total_files] > 0 ? 
      (@results[:successful].to_f / @results[:total_files] * 100).round(1) : 0
    
    puts "Total files tested: #{@results[:total_files]}"
    puts "✅ Successful: #{@results[:successful]}"
    puts "❌ Failed: #{@results[:failed]}"  
    puts "⏭️  Skipped: #{@results[:skipped]}"
    puts "📈 Success rate: #{success_rate}%"
    puts
    
    @results[:summary] = {
      success_rate: success_rate,
      ready_for_phase_2: assess_phase_2_readiness,
      critical_issues: identify_critical_issues,
      recommendations: generate_recommendations
    }
    
    puts "🎯 PHASE 2 READINESS ASSESSMENT"
    puts "-" * 30
    puts "Ready for Phase 2: #{@results[:summary][:ready_for_phase_2] ? '✅ YES' : '❌ NO'}"
    
    if @results[:summary][:critical_issues].any?
      puts "\n🚨 CRITICAL ISSUES:"
      @results[:summary][:critical_issues].each do |issue|
        puts "  • #{issue}"
      end
    end
    
    if @results[:summary][:recommendations].any?
      puts "\n💡 RECOMMENDATIONS:"
      @results[:summary][:recommendations].each do |rec|
        puts "  • #{rec}"
      end
    end
    
    puts "\n" + "=" * 50
  end

  def assess_phase_2_readiness
    # Phase 2 readiness criteria:
    # 1. Core reasoning examples (.patlang) should work
    # 2. At least 70% success rate on implemented features
    # 3. No critical parsing/evaluation errors
    
    reasoning_files = @results[:execution_results].select { |r| r[:file].end_with?('.patlang') }
    reasoning_success = reasoning_files.all? { |r| r[:status] == 'success' || r[:status] == 'skipped' }
    
    implemented_files = @results[:execution_results].reject { |r| r[:status] == 'skipped' }
    success_rate = implemented_files.empty? ? 0 : 
      (implemented_files.count { |r| r[:status] == 'success' }.to_f / implemented_files.length * 100)
    
    reasoning_success && success_rate >= 70
  end

  def identify_critical_issues
    issues = []
    
    # Look for parsing errors
    parsing_errors = @results[:execution_results].select do |r|
      r[:status] == 'failed' && r[:error] && 
      (r[:error].include?('parse') || r[:error].include?('syntax'))
    end
    
    if parsing_errors.any?
      issues << "Parsing errors detected in #{parsing_errors.length} files"
    end
    
    # Look for evaluation errors
    eval_errors = @results[:execution_results].select do |r|
      r[:status] == 'failed' && r[:error] && 
      (r[:error].include?('evaluate') || r[:error].include?('undefined'))
    end
    
    if eval_errors.any?
      issues << "Evaluation errors detected in #{eval_errors.length} files"
    end
    
    # Look for reasoning system errors
    reasoning_errors = @results[:execution_results].select do |r|
      r[:file].end_with?('.patlang') && r[:status] == 'failed'
    end
    
    if reasoning_errors.any?
      issues << "Reasoning system errors in core .patlang files"
    end
    
    issues
  end

  def generate_recommendations
    recommendations = []
    
    failed_files = @results[:execution_results].select { |r| r[:status] == 'failed' }
    
    if failed_files.any?
      recommendations << "Review and fix #{failed_files.length} failed example files"
    end
    
    if @results[:successful] == 0
      recommendations << "Critical: No examples executed successfully - check interpreter setup"
    elsif @results[:successful] < @results[:total_files] / 2
      recommendations << "Low success rate - focus on core language features first"
    end
    
    # Check for reasoning-specific recommendations
    reasoning_files = @results[:execution_results].select { |r| r[:file].end_with?('.patlang') }
    failed_reasoning = reasoning_files.select { |r| r[:status] == 'failed' }
    
    if failed_reasoning.any?
      recommendations << "Priority: Fix reasoning system integration for Phase 1 validation"
    end
    
    if @results[:skipped] > @results[:successful]
      recommendations << "Many features not yet implemented - consider implementation priorities"
    end
    
    recommendations
  end

  def save_results_to_file
    filename = "patlang_example_validation_results.json"
    File.write(filename, JSON.pretty_generate(@results))
    puts "📄 Detailed results saved to: #{filename}"
  end
end

# Run validation if script executed directly
if __FILE__ == $0
  validator = PatlangExampleValidator.new
  validator.run_validation
end