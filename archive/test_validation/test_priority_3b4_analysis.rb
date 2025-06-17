#!/usr/bin/env ruby
# Priority 3B-4 Target Analysis
# Systematic analysis to identify next high-impact quick win

require_relative 'test/test_helper'

class Priority3B4Analysis
  def initialize
    @results = {}
    @test_files = []
    @pattern_analysis = {}
  end

  def run_analysis
    puts "=== Priority 3B-4 Target Analysis ==="
    puts "Continuing successful 3B series (8-9% improvement achieved)"
    puts

    identify_candidate_test_files
    analyze_error_patterns
    calculate_impact_scores
    recommend_target

    puts "\n=== Analysis Complete ==="
  end

  private

  def identify_candidate_test_files
    puts "1. Identifying Candidate Test Files"
    puts "================================="
    
    # Focus on test files that likely have multiple failing tests
    candidates = [
      'test/patlang_language/test_reasoning_integration.rb',
      'test/ruby_implementation/test_reasoning_evaluator_integration.rb',
      'test/ruby_implementation/test_type_constraints.rb',
      'test/ruby_implementation/test_goal_system.rb',
      'test/ruby_implementation/test_object_model.rb',
      'test/ruby_implementation/test_evaluator_edge_cases.rb'
    ]

    candidates.each do |file|
      if File.exist?(file)
        @test_files << file
        puts "✓ Found: #{file}"
      else
        puts "✗ Missing: #{file}"
      end
    end

    puts "Total candidates: #{@test_files.length}"
    puts
  end

  def analyze_error_patterns
    puts "2. Analyzing Error Patterns"
    puts "=========================="
    
    @test_files.each do |file|
      puts "\nAnalyzing: #{file}"
      
      begin
        # Run individual test file to capture specific errors
        output = `ruby -I. #{file} 2>&1`
        
        @results[file] = {
          output: output,
          exit_code: $?.exitstatus,
          error_patterns: extract_error_patterns(output),
          test_count: count_tests(file)
        }
        
        puts "Exit code: #{@results[file][:exit_code]}"
        puts "Test count: #{@results[file][:test_count]}"
        puts "Error patterns: #{@results[file][:error_patterns].keys.join(', ')}"
        
      rescue => e
        puts "Error analyzing #{file}: #{e.message}"
        @results[file] = { error: e.message }
      end
    end
    puts
  end

  def extract_error_patterns(output)
    patterns = {}
    
    # Pattern 1: Missing methods (like 3B-3)
    missing_methods = output.scan(/undefined method [`']([^'`]+)['`] for ([^:]+):([^(]+)/)
    missing_methods.each do |method, object, class_name|
      patterns["missing_method"] ||= []
      patterns["missing_method"] << { method: method, object: object, class: class_name }
    end
    
    # Pattern 2: Exception type mismatches (like 3B-1)
    exception_mismatches = output.scan(/Expected ([A-Za-z:]+) but got ([A-Za-z:]+)/)
    exception_mismatches.each do |expected, got|
      patterns["exception_mismatch"] ||= []
      patterns["exception_mismatch"] << { expected: expected, got: got }
    end
    
    # Pattern 3: Syntax/parser issues (like 3B-2)
    syntax_errors = output.scan(/(syntax error|unexpected token|parse error)/i)
    if syntax_errors.any?
      patterns["syntax_error"] = syntax_errors.length
    end
    
    # Pattern 4: NoMethodError patterns
    no_method_errors = output.scan(/NoMethodError: undefined method [`']([^'`]+)['`]/)
    no_method_errors.each do |method|
      patterns["no_method_error"] ||= []
      patterns["no_method_error"] << method[0]
    end
    
    # Pattern 5: ArgumentError patterns
    argument_errors = output.scan(/ArgumentError: (.+)/)
    if argument_errors.any?
      patterns["argument_error"] = argument_errors.length
    end
    
    # Pattern 6: NameError patterns
    name_errors = output.scan(/NameError: (.+)/)
    if name_errors.any?
      patterns["name_error"] = name_errors.length
    end
    
    patterns
  end

  def count_tests(file)
    return 0 unless File.exist?(file)
    
    content = File.read(file)
    # Count test methods and test blocks
    test_methods = content.scan(/def test_\w+/).length
    test_blocks = content.scan(/test ["'][^"']+["']/).length
    
    test_methods + test_blocks
  end

  def calculate_impact_scores
    puts "3. Calculating Impact Scores"
    puts "============================"
    
    @test_files.each do |file|
      next unless @results[file] && !@results[file][:error]
      
      result = @results[file]
      patterns = result[:error_patterns]
      
      # Impact = (number_of_tests * pattern_frequency) / implementation_effort
      # Higher is better for quick wins
      
      impact_factors = {
        missing_method: 3,      # High impact like 3B-3
        exception_mismatch: 3,  # High impact like 3B-1  
        syntax_error: 2,        # Medium impact like 3B-2
        no_method_error: 3,     # High impact, easy fix
        argument_error: 2,      # Medium impact
        name_error: 2          # Medium impact
      }
      
      total_impact = 0
      patterns.each do |pattern, data|
        count = data.is_a?(Array) ? data.length : (data || 0)
        total_impact += count * (impact_factors[pattern.to_sym] || 1)
      end
      
      # Effort estimation (1-5, lower is better)
      effort = estimate_effort(patterns)
      
      # Impact score = (test_count * pattern_impact) / effort
      impact_score = (result[:test_count] * total_impact) / [effort, 1].max
      
      @results[file][:impact_score] = impact_score
      @results[file][:effort] = effort
      @results[file][:total_impact] = total_impact
      
      puts "#{file}:"
      puts "  Tests: #{result[:test_count]}"
      puts "  Pattern Impact: #{total_impact}"
      puts "  Effort: #{effort}/5"
      puts "  Impact Score: #{impact_score.round(2)}"
      puts
    end
  end

  def estimate_effort(patterns)
    # Estimate implementation effort based on pattern types
    effort_weights = {
      missing_method: 1,      # Very easy - just add stub methods
      exception_mismatch: 1,  # Very easy - change assertion types
      syntax_error: 2,        # Easy - fix syntax issues
      no_method_error: 1,     # Very easy - add missing methods
      argument_error: 2,      # Easy - fix argument issues
      name_error: 2          # Easy - fix name issues
    }
    
    total_effort = 0
    patterns.each do |pattern, data|
      count = data.is_a?(Array) ? data.length : (data || 0)
      total_effort += count * (effort_weights[pattern.to_sym] || 3)
    end
    
    # Cap at 5, minimum 1
    [[total_effort / 3, 1].max, 5].min
  end

  def recommend_target
    puts "4. Target Recommendation"
    puts "======================="
    
    # Sort by impact score (highest first)
    sorted_results = @results.select { |k, v| v[:impact_score] }
                            .sort_by { |k, v| -v[:impact_score] }
    
    if sorted_results.empty?
      puts "⚠️  No suitable targets found"
      return
    end
    
    puts "Ranked targets by impact score:"
    puts
    
    sorted_results.each_with_index do |(file, result), index|
      puts "#{index + 1}. #{file}"
      puts "   Impact Score: #{result[:impact_score].round(2)}"
      puts "   Tests: #{result[:test_count]}"
      puts "   Effort: #{result[:effort]}/5"
      puts "   Patterns: #{result[:error_patterns].keys.join(', ')}"
      
      # Show detailed error patterns for top candidate
      if index == 0
        puts "   Detailed Patterns:"
        result[:error_patterns].each do |pattern, data|
          if data.is_a?(Array)
            puts "     #{pattern}: #{data.length} instances"
            data.take(3).each { |item| puts "       - #{item.inspect}" }
          else
            puts "     #{pattern}: #{data} instances"
          end
        end
      end
      puts
    end
    
    top_target = sorted_results.first
    if top_target
      puts "🎯 RECOMMENDED PRIORITY 3B-4 TARGET:"
      puts "    File: #{top_target[0]}"
      puts "    Impact Score: #{top_target[1][:impact_score].round(2)}"
      puts "    Expected Test Improvement: #{top_target[1][:test_count]} tests"
      puts "    Implementation Effort: #{top_target[1][:effort]}/5"
      puts
    end
  end
end

# Run the analysis
analyzer = Priority3B4Analysis.new
analyzer.run_analysis