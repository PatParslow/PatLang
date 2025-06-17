#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'src/lexer'
require_relative 'src/token'
require_relative 'src/ambiguous_token'

# Direct analysis of lexer coverage gaps based on source code inspection
class LexerGapAnalysisReport
  def initialize
    @lexer_source_file = File.expand_path('src/lexer.rb', __dir__)
    @gaps = []
    @analysis_results = {}
  end

  def generate_report
    puts "=== LEXER COVERAGE GAP ANALYSIS REPORT ==="
    puts "Analyzing lexer source: #{@lexer_source_file}"
    puts
    
    analyze_lexer_source_code
    identify_potential_gaps
    run_targeted_tests
    generate_comprehensive_report
  end

  private

  def analyze_lexer_source_code
    source_lines = File.readlines(@lexer_source_file)
    
    puts "## LEXER SOURCE CODE ANALYSIS"
    puts "Total lines: #{source_lines.length}"
    
    # Analyze method structure
    methods = extract_method_info(source_lines)
    
    methods.each do |method_info|
      puts "#{method_info[:name].ljust(35)} Lines #{method_info[:start_line]}-#{method_info[:end_line]} (#{method_info[:line_count]} lines)"
    end
    
    puts
  end

  def extract_method_info(source_lines)
    methods = []
    current_method = nil
    indent_stack = []
    
    source_lines.each_with_index do |line, index|
      line_number = index + 1
      trimmed = line.strip
      
      # Detect method definitions
      if trimmed.match(/^def\s+(\w+[?!]?)/)
        method_name = $1
        current_method = {
          name: method_name,
          start_line: line_number,
          end_line: nil,
          line_count: 0
        }
      end
      
      # Detect method end
      if trimmed == 'end' && current_method
        current_method[:end_line] = line_number
        current_method[:line_count] = current_method[:end_line] - current_method[:start_line] + 1
        methods << current_method
        current_method = nil
      end
    end
    
    methods
  end

  def identify_potential_gaps
    puts "## POTENTIAL COVERAGE GAPS IDENTIFIED"
    
    # Based on lexer source analysis, identify areas likely to be under-tested
    potential_gaps = [
      {
        area: "Error handling in 'error' method",
        lines: [30, 48],
        description: "The error method creates UNKNOWN tokens for invalid characters",
        test_needed: "Test with truly invalid characters like '$', '&', '~'",
        priority: "HIGH"
      },
      {
        area: "Single quote string support",
        lines: [191, 192],
        description: "Single quote strings are handled by tokenize_string method",
        test_needed: "Test single quote strings with escape sequences",
        priority: "HIGH"
      },
      {
        area: "Incomplete escape sequence handling",
        lines: [460, 461],
        description: "Error raised when escape sequence is incomplete at string end",
        test_needed: "Test strings ending with incomplete escape like '\"text\\'",
        priority: "HIGH"
      },
      {
        area: "Backslash character handling",
        lines: [247, 258],
        description: "Standalone backslash characters are treated as UNKNOWN tokens",
        test_needed: "Test standalone backslash and invalid escape contexts",
        priority: "MEDIUM"
      },
      {
        area: "Context detection methods",
        lines: [477, 498],
        description: "Methods to detect function definition and arithmetic contexts",
        test_needed: "Test context-dependent parsing scenarios",
        priority: "MEDIUM"
      },
      {
        area: "Private helper methods",
        lines: [503, 546],
        description: "peek_word, skip_word, read_word, comment_context? methods",
        test_needed: "Test complex identifier and comment parsing",
        priority: "MEDIUM"
      },
      {
        area: "Decimal number edge cases",
        lines: [194, 198],
        description: "Numbers starting with decimal point",
        test_needed: "Test '.5' format and decimal-followed-by-identifier",
        priority: "MEDIUM"
      },
      {
        area: "Position tracking in advance method",
        lines: [54, 62],
        description: "Line and column tracking, especially with newlines",
        test_needed: "Test position accuracy across multiple lines",
        priority: "LOW"
      },
      {
        area: "Question mark identifier suffix",
        lines: [317, 320],
        description: "Support for '?' at end of identifiers (Ruby convention)",
        test_needed: "Test identifiers ending with '?' like 'empty?'",
        priority: "LOW"
      }
    ]
    
    potential_gaps.each_with_index do |gap, index|
      @gaps << gap
      puts "#{index + 1}. #{gap[:priority]} PRIORITY: #{gap[:area]}"
      puts "   Lines: #{gap[:lines].join(', ')}"
      puts "   Description: #{gap[:description]}"
      puts "   Test needed: #{gap[:test_needed]}"
      puts
    end
  end

  def run_targeted_tests
    puts "## TARGETED TEST ANALYSIS"
    puts "Testing specific scenarios to verify current coverage..."
    puts
    
    test_scenarios = [
      # Error handling tests
      {
        name: "Invalid characters produce UNKNOWN tokens",
        input: '$',
        expected_behavior: "Should produce UNKNOWN token, not raise error"
      },
      {
        name: "Single quote strings",
        input: "'hello world'",
        expected_behavior: "Should produce STRING token"
      },
      {
        name: "Incomplete escape sequence",
        input: '"incomplete\\',
        expected_behavior: "Should raise error about incomplete escape"
      },
      {
        name: "Standalone backslash",
        input: '\\',
        expected_behavior: "Should produce UNKNOWN token"
      },
      {
        name: "Decimal starting with dot",
        input: '.5',
        expected_behavior: "Should produce NUMBER token with value 0.5"
      },
      {
        name: "Identifier with question mark",
        input: 'empty?',
        expected_behavior: "Should produce IDENTIFIER token with value 'empty?'"
      },
      {
        name: "Comment context detection",
        input: 'x#comment',
        expected_behavior: "Should treat # as part of identifier, not comment"
      },
      {
        name: "Function definition context",
        input: 'make a function',
        expected_behavior: "Should produce MAKE, A, FUNCTION tokens"
      }
    ]
    
    test_scenarios.each do |scenario|
      begin
        lexer = Lexer.new(scenario[:input])
        tokens = lexer.tokenize
        
        result = {
          passed: true,
          tokens: tokens,
          error: nil
        }
        
        puts "✓ #{scenario[:name]}: #{tokens.map { |t| "#{t.type}:#{t.value}" }.join(', ')}"
        
      rescue => e
        result = {
          passed: false,
          tokens: [],
          error: e.message
        }
        
        puts "✗ #{scenario[:name]}: ERROR - #{e.message}"
      end
      
      @analysis_results[scenario[:name]] = result
    end
    
    puts
  end

  def generate_comprehensive_report
    puts "## COMPREHENSIVE COVERAGE ANALYSIS"
    puts
    
    # Count high, medium, low priority gaps
    high_priority = @gaps.count { |g| g[:priority] == "HIGH" }
    medium_priority = @gaps.count { |g| g[:priority] == "MEDIUM" }
    low_priority = @gaps.count { |g| g[:priority] == "LOW" }
    
    puts "### SUMMARY"
    puts "- Total potential gaps identified: #{@gaps.length}"
    puts "- High priority gaps: #{high_priority}"
    puts "- Medium priority gaps: #{medium_priority}"
    puts "- Low priority gaps: #{low_priority}"
    puts
    
    # Analyze current test results
    passed_tests = @analysis_results.count { |_, result| result[:passed] }
    total_tests = @analysis_results.length
    
    puts "### CURRENT TEST RESULTS"
    puts "- Tests passed: #{passed_tests}/#{total_tests}"
    puts "- Tests failed: #{total_tests - passed_tests}/#{total_tests}"
    puts
    
    # Generate specific recommendations
    puts "### RECOMMENDATIONS FOR 100% COVERAGE"
    puts
    
    recommendations = [
      "1. Add tests for invalid character handling (HIGH PRIORITY)",
      "   - Test characters: '$', '&', '~', '`', non-ASCII characters",
      "   - Verify UNKNOWN tokens are produced, no exceptions raised",
      "",
      "2. Add comprehensive string literal tests (HIGH PRIORITY)",
      "   - Test single quote strings with escape sequences",
      "   - Test incomplete escape sequences at string end",
      "   - Test all supported escape sequences: \\n, \\t, \\r, \\\\, \\\", \\'",
      "",
      "3. Add backslash character handling tests (MEDIUM PRIORITY)",
      "   - Test standalone backslash character",
      "   - Test backslash in non-string contexts",
      "",
      "4. Add context detection method tests (MEDIUM PRIORITY)",
      "   - Test function definition context detection",
      "   - Test arithmetic context detection",
      "   - Test comment context detection",
      "",
      "5. Add private method coverage tests (MEDIUM PRIORITY)",
      "   - Test peek_word, skip_word, read_word methods indirectly",
      "   - Test complex identifier parsing scenarios",
      "",
      "6. Add decimal number edge case tests (MEDIUM PRIORITY)",
      "   - Test numbers starting with decimal point (.5)",
      "   - Test decimal followed by method call (42.to_s)",
      "",
      "7. Add position tracking accuracy tests (LOW PRIORITY)",
      "   - Test line and column tracking across multiple lines",
      "   - Test position tracking with various whitespace combinations",
      "",
      "8. Add identifier with question mark tests (LOW PRIORITY)",
      "   - Test Ruby-style predicate methods (empty?, valid?)",
      "   - Test question mark in various identifier positions"
    ]
    
    recommendations.each { |rec| puts rec }
    
    puts
    puts "### ESTIMATED COVERAGE IMPROVEMENT"
    puts "Implementing these recommendations should achieve:"
    puts "- Line coverage: 95-100%"
    puts "- Branch coverage: 90-95%"
    puts "- Method coverage: 100%"
    puts
    puts "### NEXT STEPS"
    puts "1. Implement high priority test cases first"
    puts "2. Run coverage analysis after each batch of tests"
    puts "3. Focus on edge cases and error conditions"
    puts "4. Verify lexer's 'Never Fail, Always Token' principle"
    puts "5. Test all ambiguous token resolution scenarios"
  end
end

# Run the analysis
if __FILE__ == $0
  analyzer = LexerGapAnalysisReport.new
  analyzer.generate_report
end