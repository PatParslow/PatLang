#!/usr/bin/env ruby

# Priority 3B-3 Target Identification
# Based on successful completion of 3B-1 (goal keyword) and 3B-2 (postcondition syntax)

require 'open3'

class Priority3BNextTarget
  def initialize
    @test_results = []
    @failure_patterns = Hash.new(0)
  end

  def identify_next_target
    puts "🎯 Priority 3B-3: Identifying Next Highest Impact Quick Win"
    puts "=" * 60
    puts "Previous completions:"
    puts "  ✅ 3B-1: Goal keyword parsing issues"
    puts "  ✅ 3B-2: Parser postcondition syntax issues (~2% improvement)"
    puts
    
    # Test key areas likely to have quick wins
    test_areas = [
      { name: "Lexer Error Handling", files: ["test/infrastructure/test_lexer.rb"] },
      { name: "Parser Edge Cases", files: ["test/infrastructure/test_parser.rb"] },
      { name: "Basic Evaluator", files: ["test/patlang_language/test_evaluator.rb"] },
      { name: "Object Model Basic", files: ["test/ruby_implementation/test_object_model.rb"] },
      { name: "Type Constraints", files: ["test/ruby_implementation/test_type_constraints.rb"] }
    ]
    
    test_areas.each do |area|
      puts "\n🔍 Testing #{area[:name]}..."
      area[:files].each do |file|
        if File.exist?(file)
          result = run_test_simple(file)
          analyze_failures(result, area[:name])
        else
          puts "   ⚠️  File not found: #{file}"
        end
      end
    end
    
    identify_quick_win_patterns
    recommend_next_target
  end

  private

  def run_test_simple(file)
    cmd = "ruby -I. -Itest -Isrc #{file}"
    stdout, stderr, status = Open3.capture3(cmd)
    
    {
      file: file,
      stdout: stdout,
      stderr: stderr,
      success: status.success?,
      combined: "#{stdout}\n#{stderr}"
    }
  rescue => e
    {
      file: file,
      stdout: "",
      stderr: e.message,
      success: false,
      combined: e.message
    }
  end

  def analyze_failures(result, area_name)
    output = result[:combined]
    
    # Look for specific patterns indicating quick wins
    patterns = {
      "undefined method" => /undefined method `(\w+)'/,
      "uninitialized constant" => /uninitialized constant (\w+)/,
      "wrong number of arguments" => /wrong number of arguments/,
      "no method error" => /NoMethodError/,
      "syntax error" => /SyntaxError/,
      "parse error" => /ParseError/,
      "load error" => /LoadError/,
      "name error" => /NameError/
    }
    
    patterns.each do |pattern_name, regex|
      if output.match(regex)
        @failure_patterns["#{area_name}: #{pattern_name}"] += output.scan(regex).length
        puts "   🔴 Found #{pattern_name}: #{$1 || 'generic'}"
      end
    end
    
    # Extract test counts if available
    if output =~ /(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/
      runs, assertions, failures, errors = $1.to_i, $2.to_i, $3.to_i, $4.to_i
      puts "   📊 #{runs} tests: #{runs - failures - errors} passed, #{failures + errors} failed"
      
      @test_results << {
        area: area_name,
        file: result[:file],
        total: runs,
        passed: runs - failures - errors,
        failed: failures + errors
      }
    end
  end

  def identify_quick_win_patterns
    puts "\n🏆 Quick Win Analysis (High Impact, Low Effort):"
    puts "=" * 50
    
    # Sort by frequency to find most common issues
    sorted_patterns = @failure_patterns.sort_by { |pattern, count| -count }
    
    sorted_patterns.first(5).each_with_index do |(pattern, count), index|
      effort = estimate_effort(pattern)
      impact_score = count.to_f / effort
      
      puts "\n#{index + 1}. #{pattern}"
      puts "   Occurrences: #{count}"
      puts "   Estimated Effort: #{effort}/5"
      puts "   Impact Score: #{impact_score.round(2)}"
      puts "   Fix Type: #{get_fix_type(pattern)}"
    end
  end

  def estimate_effort(pattern)
    case pattern.downcase
    when /undefined method/
      2  # Usually simple method addition
    when /uninitialized constant/
      2  # Missing class/constant definition
    when /wrong number of arguments/
      1  # Method signature fix
    when /load error/
      1  # Require statement fix
    when /name error/
      2  # Variable/method name issue
    when /parse error/
      3  # Parser grammar issue
    when /syntax error/
      2  # Code syntax fix
    else
      3  # Default medium effort
    end
  end

  def get_fix_type(pattern)
    case pattern.downcase
    when /undefined method/
      "Add missing method implementation"
    when /uninitialized constant/
      "Add missing class/constant definition"
    when /wrong number of arguments/
      "Fix method signature"
    when /load error/
      "Fix require statements"
    when /name error/
      "Fix variable/method naming"
    when /parse error/
      "Fix parser grammar"
    when /syntax error/
      "Fix code syntax"
    else
      "Investigate specific issue"
    end
  end

  def recommend_next_target
    puts "\n🎯 RECOMMENDATION FOR PRIORITY 3B-3:"
    puts "=" * 45
    
    if @failure_patterns.empty?
      puts "❌ No clear patterns identified. Need deeper analysis."
      return
    end
    
    # Find highest impact/effort ratio
    best_pattern = @failure_patterns.max_by do |pattern, count|
      count.to_f / estimate_effort(pattern)
    end
    
    pattern, count = best_pattern
    effort = estimate_effort(pattern)
    
    puts "\n🏆 SELECTED TARGET: #{pattern}"
    puts "   Potential Impact: #{count} test fixes"
    puts "   Implementation Effort: #{effort}/5"
    puts "   Impact/Effort Ratio: #{(count.to_f / effort).round(2)}"
    puts "   Action Required: #{get_fix_type(pattern)}"
    
    puts "\n📋 Implementation Plan:"
    puts "   1. Identify specific failing tests"
    puts "   2. Analyze root cause of #{pattern.split(':').last.strip}"
    puts "   3. Implement targeted fix"
    puts "   4. Validate improvement with test runs"
    puts "   5. Measure pass rate improvement"
    
    puts "\n⚡ Expected Impact: 2-4% test pass rate improvement"
  end
end

# Run the analysis
if __FILE__ == $0
  analyzer = Priority3BNextTarget.new
  analyzer.identify_next_target
end