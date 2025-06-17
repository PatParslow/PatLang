#!/usr/bin/env ruby

require 'simplecov'
require 'json'
require_relative 'helpers/test_helper'

# Configure SimpleCov for detailed branch coverage analysis
SimpleCov.start do
  enable_coverage :branch
  enable_coverage :line
  add_filter '/test/'
  track_files 'src/**/*.rb'
  
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
  
  minimum_coverage line: 95, branch: 85
end

class BranchCoverageAnalyzer
  def initialize
    @gaps = {}
    @priority_files = [
      'src/lexer.rb',
      'src/parser.rb', 
      'src/evaluator.rb',
      'src/reasoning/reasoning_coordinator.rb',
      'src/evaluator/string_evaluator.rb',
      'src/evaluator/arithmetic_evaluator.rb',
      'src/parser/expression_parser.rb',
      'src/parser/function_parser.rb'
    ]
  end

  def analyze_coverage_gaps
    puts "=== BRANCH COVERAGE ANALYSIS ==="
    puts "Current Line Coverage: 0.03% (4 / 14314)"
    puts "Current Branch Coverage: 0.0% (0 / 4)"
    puts "\nThis indicates virtually no test coverage currently exists."
    
    # Analyze source files for potential branch points
    analyze_source_files
    
    # Generate coverage improvement recommendations
    generate_recommendations
  end

  private

  def analyze_source_files
    puts "\n--- Analyzing Source Files for Branch Points ---"
    
    @priority_files.each do |file_path|
      next unless File.exist?(file_path)
      
      content = File.read(file_path)
      branch_points = find_branch_points(content, file_path)
      
      if branch_points.any?
        puts "\n#{file_path}:"
        high_priority = branch_points.select { |bp| bp[:priority] == 'high' }
        medium_priority = branch_points.select { |bp| bp[:priority] == 'medium' }
        
        puts "  HIGH PRIORITY (#{high_priority.length} branches):"
        high_priority.first(5).each do |bp|
          puts "    Line #{bp[:line]}: #{bp[:type]} - #{bp[:description].slice(0, 60)}..."
        end
        
        puts "  MEDIUM PRIORITY (#{medium_priority.length} branches):"
        medium_priority.first(3).each do |bp|
          puts "    Line #{bp[:line]}: #{bp[:type]} - #{bp[:description].slice(0, 60)}..."
        end
      end
    end
  end

  def find_branch_points(content, file_path)
    branch_points = []
    lines = content.split("\n")
    
    lines.each_with_index do |line, idx|
      line_num = idx + 1
      
      # Conditional statements
      if line =~ /\b(if|unless|case|when)\s/
        branch_points << {
          line: line_num,
          type: 'conditional',
          description: line.strip,
          priority: determine_priority(line, file_path)
        }
      end
      
      # Ternary operators
      if line =~ /\?\s*.*\s*:/
        branch_points << {
          line: line_num,
          type: 'ternary',
          description: line.strip,
          priority: determine_priority(line, file_path)
        }
      end
      
      # Logical operators with short-circuit
      if line =~ /&&|\|\|/
        branch_points << {
          line: line_num,
          type: 'logical_operator',
          description: line.strip,
          priority: determine_priority(line, file_path)
        }
      end
      
      # Exception handling
      if line =~ /\b(rescue|ensure|begin)\s/
        branch_points << {
          line: line_num,
          type: 'exception_handling',
          description: line.strip,
          priority: 'high'
        }
      end
      
      # Method calls that might raise exceptions
      if line =~ /\b(raise|throw|error)\s/
        branch_points << {
          line: line_num,
          type: 'error_path',
          description: line.strip,
          priority: 'high'
        }
      end
      
      # Nil checks and safety guards
      if line =~ /\.nil\?|&\.|return.*if|return.*unless/
        branch_points << {
          line: line_num,
          type: 'safety_check',
          description: line.strip,
          priority: 'high'
        }
      end
    end
    
    branch_points.sort_by { |bp| [priority_order(bp[:priority]), bp[:line]] }
  end

  def determine_priority(line, file_path)
    # High priority for error handling and core logic
    return 'high' if line =~ /(error|exception|rescue|raise|nil\?|empty\?|return.*if|return.*unless)/
    
    # High priority for parser and evaluator core logic
    return 'high' if file_path.include?('parser') || file_path.include?('evaluator')
    
    # Medium priority for control flow
    return 'medium' if line =~ /(if|unless|case|when)/
    
    'low'
  end

  def priority_order(priority)
    case priority
    when 'high' then 1
    when 'medium' then 2
    when 'low' then 3
    else 4
    end
  end

  def generate_recommendations
    puts "\n=== COVERAGE IMPROVEMENT RECOMMENDATIONS ==="
    
    recommendations = {
      'src/lexer.rb' => [
        'Test error handling for invalid characters',
        'Test edge cases in number parsing (leading zeros, decimals)',
        'Test comment handling at end of file',
        'Test string parsing with escape sequences',
        'Test ambiguous token resolution paths',
        'Test nil character handling in advance method',
        'Test whitespace detection edge cases'
      ],
      'src/parser.rb' => [
        'Test timeout protection mechanisms',
        'Test error recovery in expression parsing',
        'Test malformed function definitions',
        'Test nested expression edge cases',
        'Test type constraint parsing errors',
        'Test token resolver ambiguous cases',
        'Test parser initialization with different input types'
      ],
      'src/evaluator.rb' => [
        'Test arithmetic division by zero',
        'Test string operations on nil values',
        'Test function call with wrong arguments',
        'Test reasoning mode transitions',
        'Test variable scope edge cases',
        'Test return value handling',
        'Test builtin class initialization'
      ]
    }
    
    recommendations.each do |file, tests|
      puts "\n#{file}:"
      tests.each { |test| puts "  - #{test}" }
    end
    
    # Save recommendations to file
    File.write('test/coverage_recommendations.json', JSON.pretty_generate(recommendations))
    puts "\nRecommendations saved to test/coverage_recommendations.json"
    
    puts "\n=== ACTION PLAN ==="
    puts "1. Start with basic functionality tests to establish baseline coverage"
    puts "2. Focus on high-priority branches in lexer, parser, and evaluator"
    puts "3. Add comprehensive error handling tests"
    puts "4. Test edge cases and boundary conditions"
    puts "5. Aim for 90%+ branch coverage in core components"
  end
end

# Run analysis if called directly
if __FILE__ == $0
  analyzer = BranchCoverageAnalyzer.new
  analyzer.analyze_coverage_gaps
end