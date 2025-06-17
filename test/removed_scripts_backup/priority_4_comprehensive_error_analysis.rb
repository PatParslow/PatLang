#!/usr/bin/env ruby

require 'json'
require 'timeout'
require_relative '../test/helpers/test_helper'

class Priority4ComprehensiveErrorAnalysis
  def initialize
    @results = {
      analysis_timestamp: Time.now.iso8601,
      priority_levels_completed: ["Priority 1: evaluate_string method", "Priority 2: EventSystem instantiation", "Priority 3: Lexer '@' character support"],
      remaining_errors: {},
      priority_4_candidates: [],
      fix_recommendations: {},
      impact_analysis: {}
    }
    
    @test_files = Dir.glob(['test/**/*.rb', 'test/*.rb']).reject do |file|
      file.include?('test_helper.rb') ||
      file.include?('coverage_analysis.rb') ||
      file.include?('error_analysis.rb') ||
      file.include?('priority_4_comprehensive_error_analysis.rb')
    end
    
    @timeout_duration = 15
    @error_categories = {}
    @fix_recommendations = {}
    @test_count = 0
    @error_count = 0
  end

  def run_analysis
    puts "🔍 Starting Priority 4+ Comprehensive Error Analysis"
    puts "📋 Analyzing #{@test_files.length} test files for remaining errors..."
    puts "⏱️  Using #{@timeout_duration}s timeout protection per test"
    puts "=" * 60

    analyze_current_errors
    categorize_priority_4_errors  
    generate_fix_recommendations
    create_impact_analysis
    save_results
    
    display_summary
    self
  end

  private

  def analyze_current_errors
    puts "\n📊 Phase 1: Current Error Landscape Analysis"
    
    @test_files.each_with_index do |test_file, index|
      next if should_skip_file?(test_file)
      
      print "\r🔍 [#{index + 1}/#{@test_files.length}] #{File.basename(test_file)}..."
      $stdout.flush
      
      begin
        Timeout::timeout(@timeout_duration) do
          result = capture_test_errors(test_file)
          if result[:errors].any?
            @error_categories[test_file] = result
            @error_count += result[:errors].length
          end
          @test_count += 1
        end
      rescue Timeout::Error
        @error_categories[test_file] = {
          status: 'timeout',
          errors: [{ type: 'timeout', message: "Test exceeded #{@timeout_duration}s timeout" }],
          execution_time: @timeout_duration
        }
        @error_count += 1
      rescue => e
        @error_categories[test_file] = {
          status: 'analysis_error', 
          errors: [{ type: 'analysis_error', message: e.message }],
          execution_time: 0
        }
        @error_count += 1
      end
    end
    
    puts "\n✅ Phase 1 Complete: #{@test_count} tests analyzed, #{@error_count} errors found"
  end

  def capture_test_errors(test_file)
    start_time = Time.now
    errors = []
    
    # Try to load and run the test file
    begin
      # Capture both syntax and runtime errors
      output = `ruby -I./src -I./test #{test_file} 2>&1`
      exit_code = $?.exitstatus
      
      if exit_code != 0 || output.include?('Error') || output.include?('Exception')
        errors = parse_errors_from_output(output)
      end
      
    rescue => e
      errors << {
        type: 'load_error',
        message: e.message,
        backtrace: e.backtrace&.first(3)
      }
    end
    
    {
      status: errors.empty? ? 'pass' : 'fail',
      errors: errors,
      execution_time: Time.now - start_time
    }
  end

  def parse_errors_from_output(output)
    errors = []
    
    # Common error patterns
    error_patterns = [
      { pattern: /NameError: uninitialized constant (\w+)/, type: 'uninitialized_constant' },
      { pattern: /NoMethodError: undefined method `([^']+)'/, type: 'undefined_method' },
      { pattern: /ArgumentError: wrong number of arguments/, type: 'argument_error' },
      { pattern: /TypeError: no implicit conversion/, type: 'type_error' },
      { pattern: /SyntaxError: (.+)/, type: 'syntax_error' },
      { pattern: /LoadError: cannot load such file -- (.+)/, type: 'load_error' },
      { pattern: /RuntimeError: (.+)/, type: 'runtime_error' },
      { pattern: /StandardError: (.+)/, type: 'standard_error' },
      { pattern: /Exception: (.+)/, type: 'exception' }
    ]
    
    output.split("\n").each do |line|
      error_patterns.each do |pattern_info|
        if match = line.match(pattern_info[:pattern])
          errors << {
            type: pattern_info[:type],
            message: match[0],
            details: match[1] || 'No details'
          }
        end
      end
    end
    
    # If no specific patterns matched but there's clearly an error
    if errors.empty? && (output.include?('Error') || output.include?('Exception'))
      errors << {
        type: 'unknown_error',
        message: output.strip,
        details: 'Unmatched error pattern'
      }
    end
    
    errors
  end

  def categorize_priority_4_errors
    puts "\n🎯 Phase 2: Priority 4+ Error Categorization"
    
    error_frequency = Hash.new(0)
    error_impact = Hash.new(0)
    
    @error_categories.each do |file, result|
      result[:errors].each do |error|
        error_frequency[error[:type]] += 1
        
        # Calculate impact based on error type and affected files
        impact_score = calculate_error_impact(error[:type], file)
        error_impact[error[:type]] += impact_score
      end
    end
    
    # Generate Priority 4 candidates based on frequency and impact
    @priority_4_candidates = error_frequency.map do |error_type, frequency|
      {
        error_type: error_type,
        frequency: frequency,
        impact_score: error_impact[error_type],
        priority_score: (frequency * error_impact[error_type]) / @test_files.length.to_f,
        affected_files: get_affected_files(error_type)
      }
    end.sort_by { |e| -e[:priority_score] }
    
    puts "✅ Phase 2 Complete: #{@priority_4_candidates.length} error categories identified"
    puts "🏆 Top Priority 4 candidate: #{@priority_4_candidates.first[:error_type]}" if @priority_4_candidates.any?
  end

  def calculate_error_impact(error_type, file)
    # Base impact scores for different error types
    base_scores = {
      'uninitialized_constant' => 8,
      'undefined_method' => 7,
      'load_error' => 9,
      'argument_error' => 6,
      'type_error' => 7,
      'syntax_error' => 9,
      'runtime_error' => 5,
      'timeout' => 10,
      'analysis_error' => 4
    }
    
    base_score = base_scores[error_type] || 3
    
    # Additional impact factors
    if file.include?('infrastructure/')
      base_score += 2  # Infrastructure errors affect more
    elsif file.include?('patlang_language/')
      base_score += 1  # Language errors are important
    end
    
    base_score
  end

  def get_affected_files(error_type)
    @error_categories.select do |file, result|
      result[:errors].any? { |error| error[:type] == error_type }
    end.keys
  end

  def generate_fix_recommendations
    puts "\n💡 Phase 3: Fix Recommendation Generation"
    
    @priority_4_candidates.each do |candidate|
      @fix_recommendations[candidate[:error_type]] = generate_fix_strategy(candidate)
    end
    
    puts "✅ Phase 3 Complete: Fix strategies generated for #{@fix_recommendations.length} error types"
  end

  def generate_fix_strategy(candidate)
    case candidate[:error_type]
    when 'uninitialized_constant'
      {
        strategy: 'missing_constant_resolution',
        complexity: 'medium',
        steps: [
          'Identify missing constants in affected files',
          'Add proper require statements or constant definitions',
          'Validate constant resolution across test suite'
        ],
        estimated_effort: 'medium',
        risk_level: 'low'
      }
    when 'undefined_method'
      {
        strategy: 'method_implementation',
        complexity: 'medium',
        steps: [
          'Analyze missing method signatures',
          'Implement missing methods with proper parameters',
          'Add comprehensive method validation'
        ],
        estimated_effort: 'medium',
        risk_level: 'medium'
      }
    when 'load_error'
      {
        strategy: 'dependency_resolution',
        complexity: 'low',
        steps: [
          'Fix require paths and file references',
          'Ensure all dependencies are properly loaded',
          'Validate load order dependencies'
        ],
        estimated_effort: 'low',
        risk_level: 'low'
      }
    when 'timeout'
      {
        strategy: 'performance_optimization',
        complexity: 'high',
        steps: [
          'Identify performance bottlenecks causing timeouts',
          'Optimize algorithms or add early termination',
          'Enhance timeout protection mechanisms'
        ],
        estimated_effort: 'high',
        risk_level: 'medium'
      }
    else
      {
        strategy: 'custom_analysis_required',
        complexity: 'unknown',
        steps: ['Requires detailed analysis of specific error pattern'],
        estimated_effort: 'unknown',
        risk_level: 'unknown'
      }
    end
  end

  def create_impact_analysis
    puts "\n📈 Phase 4: Impact Analysis"
    
    @impact_analysis = {
      total_test_files: @test_files.length,
      error_free_files: @test_files.length - @error_categories.length,
      files_with_errors: @error_categories.length,
      total_errors: @error_count,
      error_reduction_from_priority_123: calculate_error_reduction,
      priority_4_impact_potential: calculate_priority_4_potential
    }
    
    puts "✅ Phase 4 Complete: Impact analysis generated"
  end

  def calculate_error_reduction
    # This would ideally compare with previous comprehensive analysis
    # For now, we'll use the current state as baseline
    {
      note: "Baseline established after Priority 1-3 fixes",
      current_error_rate: (@error_count.to_f / @test_files.length * 100).round(2),
      stabilized_files: @test_files.length - @error_categories.length
    }
  end

  def calculate_priority_4_potential
    return {} if @priority_4_candidates.empty?
    
    top_candidate = @priority_4_candidates.first
    {
      top_priority_4_error: top_candidate[:error_type],
      potential_files_fixed: top_candidate[:affected_files].length,
      potential_error_reduction: ((top_candidate[:frequency].to_f / @error_count) * 100).round(2),
      estimated_complexity: @fix_recommendations[top_candidate[:error_type]][:complexity]
    }
  end

  def should_skip_file?(file)
    skip_patterns = [
      'priority_4_comprehensive_error_analysis.rb',
      'comprehensive_error_analysis.rb',
      'error_analysis.rb', 
      'coverage_analysis.rb',
      'test_helper.rb'
    ]
    
    skip_patterns.any? { |pattern| file.include?(pattern) }
  end

  def save_results
    @results[:remaining_errors] = @error_categories
    @results[:priority_4_candidates] = @priority_4_candidates
    @results[:fix_recommendations] = @fix_recommendations
    @results[:impact_analysis] = @impact_analysis
    
    File.write('test/PRIORITY_4_COMPREHENSIVE_ERROR_ANALYSIS.json', JSON.pretty_generate(@results))
    puts "\n💾 Results saved to: test/PRIORITY_4_COMPREHENSIVE_ERROR_ANALYSIS.json"
  end

  def display_summary
    puts "\n" + "=" * 60
    puts "🎯 PRIORITY 4+ COMPREHENSIVE ERROR ANALYSIS SUMMARY"
    puts "=" * 60
    
    puts "\n📊 Current Error Landscape:"
    puts "   • Total test files analyzed: #{@test_files.length}"
    puts "   • Files with errors: #{@error_categories.length}"
    puts "   • Error-free files: #{@test_files.length - @error_categories.length}"
    puts "   • Total errors found: #{@error_count}"
    puts "   • Current error rate: #{(@error_count.to_f / @test_files.length * 100).round(2)}%"
    
    if @priority_4_candidates.any?
      puts "\n🏆 Top Priority 4 Error Categories:"
      @priority_4_candidates.first(5).each_with_index do |candidate, index|
        puts "   #{index + 1}. #{candidate[:error_type]}: #{candidate[:frequency]} occurrences, #{candidate[:affected_files].length} files"
      end
      
      top_candidate = @priority_4_candidates.first
      puts "\n🎯 Recommended Priority 4 Focus:"
      puts "   • Error Type: #{top_candidate[:error_type]}"
      puts "   • Frequency: #{top_candidate[:frequency]} occurrences"
      puts "   • Affected Files: #{top_candidate[:affected_files].length}"
      puts "   • Fix Complexity: #{@fix_recommendations[top_candidate[:error_type]][:complexity]}"
      puts "   • Potential Impact: #{((top_candidate[:frequency].to_f / @error_count) * 100).round(2)}% error reduction"
    else
      puts "\n🎉 Excellent! No Priority 4+ errors detected!"
      puts "   All remaining errors appear to be lower priority or edge cases."
    end
    
    puts "\n" + "=" * 60
  end
end

# Run the analysis
if __FILE__ == $0
  analyzer = Priority4ComprehensiveErrorAnalysis.new
  analyzer.run_analysis
end