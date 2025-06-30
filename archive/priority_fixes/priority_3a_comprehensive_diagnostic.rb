#!/usr/bin/env ruby

# Priority 3A Comprehensive Diagnostic
# Systematic investigation of remaining unknown error epidemic

require 'json'
require 'timeout'

class Priority3ADiagnostic
  def initialize
    @results = {}
    @error_patterns = {}
    @timeout_duration = 10
  end

  def run_diagnostic
    puts "🔍 PRIORITY 3A COMPREHENSIVE DIAGNOSTIC"
    puts "=" * 60
    puts "Investigating remaining unknown error epidemic..."
    puts "Time: #{Time.now}"
    puts

    # Step 1: Load and analyze existing results
    load_existing_results
    
    # Step 2: Identify the core issue
    identify_core_syntax_issue
    
    # Step 3: Test individual files
    test_sample_files
    
    # Step 4: Pattern analysis
    analyze_error_patterns
    
    # Step 5: Generate action plan
    generate_action_plan
    
    puts "\n🎯 DIAGNOSTIC COMPLETE"
    puts "Results saved to: priority_3a_diagnostic_results.json"
  end

private

  def load_existing_results
    puts "📊 STEP 1: Loading existing validation results..."
    
    if File.exist?('unknown_error_validation_results.json')
      content = File.read('unknown_error_validation_results.json')
      @existing_results = JSON.parse(content)
      
      puts "   ✅ Loaded #{@existing_results.size} test file results"
      
      # Categorize by status
      @status_counts = @existing_results.group_by { |k, v| v['status'] }
                                       .transform_values(&:size)
      
      puts "   📈 Status breakdown:"
      @status_counts.each { |status, count| puts "      #{status}: #{count} files" }
      puts
    else
      puts "   ❌ No existing results found"
      @existing_results = {}
    end
  end

  def identify_core_syntax_issue
    puts "🔍 STEP 2: Analyzing core syntax issue..."
    
    # Check test_helper.rb syntax
    syntax_check = `ruby -c test/helpers/test_helper.rb 2>&1`
    
    if syntax_check.include?("syntax error") || $?.exitstatus != 0
      puts "   🚨 CRITICAL: test_helper.rb has syntax errors!"
      puts "   📝 Syntax check output:"
      puts "      #{syntax_check.strip}"
      
      @core_issue = {
        type: "syntax_error_in_test_helper",
        description: "test_helper.rb has syntax errors causing widespread failures",
        impact: "high",
        affects: "all tests requiring test_helper.rb"
      }
    else
      puts "   ✅ test_helper.rb syntax is valid"
      @core_issue = nil
    end
    puts
  end

  def test_sample_files
    puts "🧪 STEP 3: Testing sample files individually..."
    
    # Select representative files from each category
    sample_files = [
      'test/patlang_language/test_function_integration.rb',  # unknown_error
      'test/ruby_implementation/test_evaluator_edge_cases.rb',  # timeout
      'test/infrastructure/test_reasoning_coordinator.rb',  # timeout
      'test/patlang_language/test_evaluator_error_handling.rb',  # timeout
      'test/helpers/test_constants.rb'  # success (control)
    ]
    
    sample_files.each do |file|
      next unless File.exist?(file)
      
      puts "   🔬 Testing: #{file}"
      
      begin
        # Test syntax first
        syntax_result = `ruby -c #{file} 2>&1`
        syntax_ok = $?.exitstatus == 0
        
        if syntax_ok
          puts "      ✅ Syntax: Valid"
          
          # Test loading
          load_result = test_file_loading(file)
          puts "      📦 Loading: #{load_result[:status]}"
          puts "      💬 Details: #{load_result[:details]}" if load_result[:details]
          
        else
          puts "      ❌ Syntax: Invalid"
          puts "      📝 Error: #{syntax_result.strip}"
        end
        
        @results[file] = {
          syntax_valid: syntax_ok,
          syntax_output: syntax_result.strip,
          load_test: syntax_ok ? load_result : nil
        }
        
      rescue => e
        puts "      💥 Exception: #{e.message}"
        @results[file] = { exception: e.message }
      end
      
      puts
    end
  end

  def test_file_loading(file)
    begin
      Timeout::timeout(@timeout_duration) do
        # Try to load the file without running tests
        output = `ruby -r #{file} -e "puts 'Load successful'" 2>&1`
        exit_status = $?.exitstatus
        
        if exit_status == 0 && output.include?('Load successful')
          { status: 'success', details: 'File loads without errors' }
        else
          { status: 'error', details: output.strip }
        end
      end
    rescue Timeout::Error
      { status: 'timeout', details: "Loading timed out after #{@timeout_duration}s" }
    rescue => e
      { status: 'exception', details: e.message }
    end
  end

  def analyze_error_patterns
    puts "🔬 STEP 4: Analyzing error patterns..."
    
    # Group errors by type from existing results
    @existing_results.each do |file, data|
      error_type = classify_error(data)
      @error_patterns[error_type] ||= []
      @error_patterns[error_type] << file
    end
    
    puts "   📊 Error pattern analysis:"
    @error_patterns.each do |pattern, files|
      puts "      #{pattern}: #{files.size} files"
      
      # Show sample error for each pattern
      if files.any?
        sample_file = files.first
        sample_error = @existing_results[sample_file]
        puts "         Sample: #{File.basename(sample_file)}"
        if sample_error['output'] && sample_error['output'].length > 0
          error_preview = sample_error['output'].split("\n").first || "No output"
          puts "         Error: #{error_preview[0..80]}#{'...' if error_preview.length > 80}"
        end
      end
      puts
    end
  end

  def classify_error(error_data)
    output = error_data['output'] || ""
    status = error_data['status'] || "unknown"
    
    case
    when status == 'unknown_error'
      'unknown_error_hanging'
    when output.include?('syntax error')
      'syntax_error_in_helper'
    when output.include?('require_relative')
      'require_loading_error'
    when status == 'timeout'
      'timeout_during_execution'
    when status == 'success'
      'working_correctly'
    else
      'unclassified_error'
    end
  end

  def generate_action_plan
    puts "🎯 STEP 5: Generating action plan..."
    
    puts "   📋 FINDINGS SUMMARY:"
    puts "   " + "=" * 50
    
    if @core_issue
      puts "   🚨 CRITICAL ISSUE FOUND:"
      puts "      Type: #{@core_issue[:type]}"
      puts "      Description: #{@core_issue[:description]}"
      puts "      Impact: #{@core_issue[:impact].upcase}"
      puts "      Affects: #{@core_issue[:affects]}"
      puts
    end
    
    puts "   📊 ERROR BREAKDOWN:"
    @error_patterns.each do |pattern, files|
      puts "      #{pattern}: #{files.size} files"
    end
    puts
    
    puts "   🛠️  RECOMMENDED ACTION PLAN:"
    puts "   " + "-" * 40
    
    if @core_issue&.dig(:type) == "syntax_error_in_test_helper"
      puts "   PRIORITY 1 (CRITICAL): Fix test_helper.rb syntax errors"
      puts "      • This is blocking ALL tests that require test_helper.rb"
      puts "      • Root cause: Syntax error in test/helpers/test_helper.rb"
      puts "      • Expected impact: Will fix majority of timeout errors"
      puts
    end
    
    puts "   PRIORITY 2: Address remaining unknown_error files"
    unknown_count = @error_patterns['unknown_error_hanging']&.size || 0
    puts "      • #{unknown_count} files showing unknown_error status"
    puts "      • These appear to be hanging during test execution"
    puts "      • Likely need improved timeout handling"
    puts
    
    puts "   PRIORITY 3: Investigate specific error patterns"
    puts "      • Focus on files that load but don't execute properly"
    puts "      • Add better error capture for hanging tests"
    puts "      • Improve test runner timeout mechanisms"
    
    # Save detailed results
    save_results
  end

  def save_results
    detailed_results = {
      timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
      core_issue: @core_issue,
      error_patterns: @error_patterns,
      sample_test_results: @results,
      status_breakdown: @status_counts,
      recommendations: generate_recommendations
    }
    
    File.write('priority_3a_diagnostic_results.json', JSON.pretty_generate(detailed_results))
  end

  def generate_recommendations
    recommendations = []
    
    if @core_issue&.dig(:type) == "syntax_error_in_test_helper"
      recommendations << {
        priority: 1,
        type: "syntax_fix",
        description: "Fix syntax errors in test/helpers/test_helper.rb",
        estimated_impact: "high",
        files_affected: @error_patterns['syntax_error_in_helper']&.size || 0
      }
    end
    
    if @error_patterns['unknown_error_hanging']
      recommendations << {
        priority: 2,
        type: "timeout_handling",
        description: "Improve timeout handling for hanging unknown_error tests",
        estimated_impact: "medium",
        files_affected: @error_patterns['unknown_error_hanging'].size
      }
    end
    
    recommendations << {
      priority: 3,
      type: "test_runner_improvement",
      description: "Enhance test runner error detection and reporting",
      estimated_impact: "medium",
      files_affected: "all"
    }
    
    recommendations
  end
end

# Run the diagnostic
if __FILE__ == $0
  diagnostic = Priority3ADiagnostic.new
  diagnostic.run_diagnostic
end