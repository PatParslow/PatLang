#!/usr/bin/env ruby

require 'simplecov'
require_relative 'src/lexer'

# Lexer Coverage Gap Analyzer
# Goal: Identify specific uncovered lines in src/lexer.rb to boost coverage from 44.76% to 80%+

class LexerCoverageGapAnalyzer
  def initialize
    @lexer_path = File.expand_path('src/lexer.rb', __dir__)
    @lexer_lines = File.readlines(@lexer_path)
    @total_lines = @lexer_lines.length
    @current_covered = 128  # From task description: 128/547 lines covered (44.76%)
    @total_relevant = 547   # Total lines from task description
    @target_coverage = 0.80 # 80% target
    @target_lines_needed = (@total_relevant * @target_coverage).to_i
    @additional_lines_needed = @target_lines_needed - @current_covered
  end

  def analyze_lexer_structure
    puts "🔍 LEXER COVERAGE GAP ANALYSIS"
    puts "=" * 50
    puts "Current Coverage: #{@current_covered}/#{@total_relevant} lines (44.76%)"
    puts "Target Coverage:  #{@target_lines_needed}/#{@total_relevant} lines (80.00%)"
    puts "Additional Lines Needed: #{@additional_lines_needed} lines"
    puts "Improvement Required: #{(@target_coverage - 0.4476) * 100}%"
    puts ""

    analyze_method_blocks
    identify_uncovered_patterns
    suggest_efficient_test_strategies
  end

  def analyze_method_blocks
    puts "📊 METHOD-BY-METHOD ANALYSIS"
    puts "-" * 30

    method_blocks = {
      'initialize' => (22..28),
      'error' => (30..49),      # CRITICAL: Core error handling - likely uncovered
      'advance' => (51..63),
      'skip_whitespace' => (65..69),
      'skip_comment' => (71..80),
      'read_number' => (82..95), # Edge cases likely uncovered
      'get_next_token' => (97..271), # Main method - some branches uncovered
      'next_token' => (274..276),
      'tokenize' => (278..287),
      'peek_char' => (291..294),
      'alpha?' => (296..300),
      'alphanumeric?' => (302..304),
      'read_identifier' => (306..429), # Complex logic - ambiguous tokens likely uncovered
      'tokenize_string' => (431..475), # String handling edge cases
      'in_function_definition_context?' => (477..485), # Private helper - likely uncovered
      'in_arithmetic_context?' => (487..498), # Private helper - likely uncovered
      'peek_word' => (503..519), # Utility method - likely uncovered
      'skip_word' => (521..526), # Utility method - likely uncovered
      'read_word' => (528..536), # Utility method - likely uncovered
      'comment_context?' => (538..546) # Context detection - likely uncovered
    }

    method_blocks.each do |method_name, range|
      lines_in_method = range.size
      puts "#{method_name.ljust(25)} Lines #{range.first}-#{range.last} (#{lines_in_method} lines)"
    end
    puts ""
  end

  def identify_uncovered_patterns
    puts "🎯 HIGH-PRIORITY UNCOVERED AREAS"
    puts "-" * 35

    critical_gaps = [
      {
        area: "Error Method (lines 30-49)",
        lines: 20,
        priority: "CRITICAL",
        reason: "Core error handling - creates UNKNOWN tokens",
        test_strategy: "Invalid characters: @, #, $, &, ~, unicode"
      },
      {
        area: "Private Helper Methods (lines 477-546)",
        lines: 70,
        priority: "HIGH",
        reason: "Context detection & utility methods completely untested",
        test_strategy: "Complex parsing scenarios that trigger helpers"
      },
      {
        area: "String Tokenization Edge Cases (lines 460-461)",
        lines: 15,
        priority: "HIGH",
        reason: "Incomplete escape sequence error handling",
        test_strategy: "Malformed escape sequences in strings"
      },
      {
        area: "Ambiguous Token Resolution (lines 323-349)",
        lines: 27,
        priority: "MEDIUM",
        reason: "AmbiguousToken creation for context-dependent keywords",
        test_strategy: "Keywords in different contexts: make, a, function, called, end"
      },
      {
        area: "Backslash Handling (lines 247-258)",
        lines: 12,
        priority: "MEDIUM",
        reason: "Standalone backslash outside string context",
        test_strategy: "Backslash characters in various contexts"
      },
      {
        area: "Number Parsing Edge Cases (lines 86-94)",
        lines: 9,
        priority: "MEDIUM",
        reason: "Decimal number validation logic",
        test_strategy: "Complex number formats and edge cases"
      }
    ]

    total_gap_lines = 0
    critical_gaps.each do |gap|
      puts "#{gap[:priority].ljust(8)} #{gap[:area]}"
      puts "         Lines: #{gap[:lines]}, Reason: #{gap[:reason]}"
      puts "         Strategy: #{gap[:test_strategy]}"
      puts ""
      total_gap_lines += gap[:lines]
    end

    puts "Total Identified Gap Lines: #{total_gap_lines}"
    puts "Needed for 80% Target: #{@additional_lines_needed}"
    puts "Coverage Potential: #{total_gap_lines >= @additional_lines_needed ? '✅ SUFFICIENT' : '⚠️ MAY NEED MORE'}"
    puts ""
  end

  def suggest_efficient_test_strategies
    puts "🚀 EFFICIENT TEST STRATEGIES FOR 80% COVERAGE"
    puts "-" * 45

    strategies = [
      {
        strategy: "Invalid Character Battery Test",
        target_lines: "30-49 (error method)",
        coverage_boost: "~20 lines",
        test_code: "Test: ['@', '#', '$', '&', '~', '§', 'ñ', 'ü'].each { |char| lexer.tokenize(char) }"
      },
      {
        strategy: "Context-Dependent Keyword Test",
        target_lines: "323-349, 477-498 (ambiguous tokens + context detection)",
        coverage_boost: "~40 lines",
        test_code: "Test: 'make a function called end' in different syntactic contexts"
      },
      {
        strategy: "String Edge Case Battery",
        target_lines: "460-461, 438-475 (string tokenization)",
        coverage_boost: "~15 lines",
        test_code: "Test: malformed escape sequences, unterminated strings"
      },
      {
        strategy: "Utility Method Trigger Test",
        target_lines: "503-546 (private helpers)",
        coverage_boost: "~44 lines",
        test_code: "Test: complex identifier parsing, comment contexts, word operations"
      },
      {
        strategy: "Backslash Handling Test",
        target_lines: "247-258 (backslash logic)",
        coverage_boost: "~12 lines",
        test_code: "Test: standalone backslash, invalid escape contexts"
      }
    ]

    total_potential_boost = 0
    strategies.each_with_index do |strategy, index|
      lines_match = strategy[:coverage_boost].match(/(\d+)/)
      boost = lines_match ? lines_match[1].to_i : 0
      total_potential_boost += boost

      puts "#{index + 1}. #{strategy[:strategy]}"
      puts "   Target: #{strategy[:target_lines]}"
      puts "   Boost: #{strategy[:coverage_boost]}"
      puts "   Implementation: #{strategy[:test_code]}"
      puts ""
    end

    puts "Total Potential Coverage Boost: ~#{total_potential_boost} lines"
    puts "Current: 128 lines (44.76%)"
    puts "With All Strategies: #{128 + total_potential_boost} lines (~#{((128 + total_potential_boost).to_f / 547 * 100).round(1)}%)"
    puts ""

    if (128 + total_potential_boost) >= @target_lines_needed
      puts "✅ SUCCESS: These strategies should achieve 80%+ coverage target!"
    else
      puts "⚠️  WARNING: May need additional coverage strategies"
    end
  end

  def run_coverage_analysis
    puts "🏃 RUNNING CURRENT LEXER TESTS TO ESTABLISH BASELINE"
    puts "-" * 50

    # Configure SimpleCov for lexer-specific analysis
    SimpleCov.configure do
      add_filter '/test/'
      add_group 'Lexer Only', 'src/lexer.rb'
      minimum_coverage 44.76
    end

    SimpleCov.start

    # Load and run basic lexer test to see current coverage
    begin
      require_relative 'test/infrastructure/test_lexer'
      puts "✅ Lexer tests loaded successfully"
    rescue LoadError => e
      puts "⚠️  Could not load lexer tests: #{e.message}"
    end

    puts ""
  end
end

# Chain of Drafts Summary: Lexer has uncovered error handling and private methods
if __FILE__ == $0
  analyzer = LexerCoverageGapAnalyzer.new
  analyzer.run_coverage_analysis
  analyzer.analyze_lexer_structure
end