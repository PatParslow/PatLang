#!/usr/bin/env ruby
# frozen_string_literal: true

require 'coverage'
require 'json'
require_relative '../src/lexer'
require_relative '../src/token'
require_relative '../src/ambiguous_token'

# Lexer Coverage Analysis Tool
# Analyzes current test coverage for the lexer to identify gaps

class LexerCoverageAnalysis
  def initialize
    @lexer_source_file = File.expand_path('../src/lexer.rb', __dir__)
    @coverage_data = {}
    @line_coverage = {}
    @branch_coverage = {}
    @uncovered_lines = []
    @uncovered_branches = []
  end

  def run_analysis
    puts "=== LEXER COVERAGE ANALYSIS ==="
    puts "Analyzing lexer source: #{@lexer_source_file}"
    puts

    # Read the lexer source code
    read_lexer_source
    
    # Start coverage tracking
    Coverage.start(lines: true, branches: true, methods: true)
    
    # Run comprehensive lexer tests to gather coverage data
    run_comprehensive_lexer_tests
    
    # Get coverage results
    @coverage_data = Coverage.result
    
    # Analyze the results
    analyze_coverage_results
    
    # Generate detailed report
    generate_detailed_report
  end

  private

  def read_lexer_source
    @lexer_source_lines = File.readlines(@lexer_source_file)
    puts "Lexer source contains #{@lexer_source_lines.length} lines"
  end

  def run_comprehensive_lexer_tests
    puts "Running comprehensive lexer tests to gather coverage data..."
    
    # Test cases covering all major lexer functionality
    test_cases = [
      # Basic tokens
      '',
      '42',
      '3.14',
      '"hello"',
      "'world'",
      'identifier',
      'if',
      'then',
      'else',
      'end',
      'true',
      'false',
      'make',
      'a',
      'function',
      'called',
      
      # Operators
      '+',
      '-',
      '*',
      '/',
      '%',
      '^',
      '=',
      '==',
      '!=',
      '<',
      '>',
      '<=',
      '>=',
      '!',
      
      # Delimiters
      '(',
      ')',
      '{',
      '}',
      '[',
      ']',
      ',',
      '.',
      ':',
      '::',
      '@',
      '?',
      '?-',
      
      # Whitespace and comments
      "   \t\n  ",
      "# comment",
      "# comment\ncode",
      "x = 5 # inline comment",
      
      # String edge cases
      '""',
      '"hello\\nworld"',
      '"quote: \\"test\\""',
      '"unterminated string',
      '"incomplete escape\\',
      
      # Number edge cases
      '0',
      '007',
      '.5',
      '42.',
      '3.14.159',
      '999999999999999999',
      
      # Error cases and edge cases
      '$',
      '&',
      '~',
      '`',
      '\u{FEFF}', # BOM
      '\\',
      
      # Complex expressions
      'x + 5 * (y - 2)',
      'if x > 5 then print "big" else print "small" end',
      'make a function called test takes: x, y { return x + y }',
      'call test with 10, 20',
      '"hello" + ", " + "world"',
      'array[0]',
      'object.method',
      'x == y != z <= a >= b',
      
      # Multi-line complex cases
      <<~CODE,
        make a function called fibonacci takes: n {
          if n <= 1 then return n
          else return call fibonacci with (n-1) + call fibonacci with (n-2)
          end
        }
      CODE
      
      # Ambiguous token cases
      'make a function',
      'a = 5',
      'end if',
      
      # Boundary conditions
      'a' * 1000, # Very long identifier
      '(' * 100 + ')' * 100, # Many nested parens
    ]
    
    test_cases.each_with_index do |test_case, index|
      begin
        lexer = Lexer.new(test_case)
        tokens = lexer.tokenize
        
        # Also test get_next_token method directly
        lexer2 = Lexer.new(test_case)
        while (token = lexer2.get_next_token).type != :EOF
          # Process tokens
        end
        
        # Test next_token alias
        lexer3 = Lexer.new(test_case)
        while (token = lexer3.next_token).type != :EOF
          # Process tokens
        end
        
      rescue => e
        # Track errors but continue - lexer should handle most errors gracefully
        puts "  Test case #{index + 1} raised error: #{e.message}" if ENV['VERBOSE']
      end
    end
    
    # Test private methods indirectly through edge cases
    test_private_method_coverage
    
    puts "Completed #{test_cases.length} test cases"
  end

  def test_private_method_coverage
    # Test peek_char method coverage through decimal number parsing
    lexer = Lexer.new('.5')
    lexer.tokenize
    
    # Test alpha? and alphanumeric? methods through identifier parsing
    lexer = Lexer.new('_test123_')
    lexer.tokenize
    
    # Test comment_context? method through various comment scenarios
    ['# start of line comment', 'x # after identifier', '  # after spaces'].each do |test|
      lexer = Lexer.new(test)
      lexer.tokenize
    end
    
    # Test in_function_definition_context? through function syntax
    lexer = Lexer.new('make a function called test')
    lexer.tokenize
    
    # Test in_arithmetic_context? through arithmetic expressions
    lexer = Lexer.new('x = a + b')
    lexer.tokenize
    
    # Test peek_word, skip_word, read_word through complex identifier scenarios
    lexer = Lexer.new('identifier_with_underscores another_identifier')
    lexer.tokenize
    
    # Test advance method edge cases
    lexer = Lexer.new("line1\nline2\n")
    while lexer.instance_variable_get(:@current_char)
      lexer.send(:advance)
    end
  end

  def analyze_coverage_results
    return unless @coverage_data[@lexer_source_file]
    
    coverage_info = @coverage_data[@lexer_source_file]
    
    # Analyze line coverage
    if coverage_info[:lines]
      @line_coverage = coverage_info[:lines]
      analyze_line_coverage
    end
    
    # Analyze branch coverage  
    if coverage_info[:branches]
      @branch_coverage = coverage_info[:branches]
      analyze_branch_coverage
    end
  end

  def analyze_line_coverage
    total_lines = @line_coverage.length
    covered_lines = @line_coverage.count { |count| count && count > 0 }
    
    @line_coverage.each_with_index do |count, index|
      line_number = index + 1
      if count == 0
        @uncovered_lines << line_number
      end
    end
    
    @line_coverage_percentage = (covered_lines.to_f / total_lines * 100).round(2)
    
    puts "Line Coverage: #{covered_lines}/#{total_lines} (#{@line_coverage_percentage}%)"
    puts "Uncovered lines: #{@uncovered_lines.length}"
  end

  def analyze_branch_coverage
    return unless @branch_coverage
    
    total_branches = @branch_coverage.length
    covered_branches = @branch_coverage.count do |_, branches|
      branches.values.all? { |count| count > 0 }
    end
    
    @branch_coverage.each do |line_number, branches|
      branches.each do |branch_id, count|
        if count == 0
          @uncovered_branches << "Line #{line_number}, Branch #{branch_id}"
        end
      end
    end
    
    @branch_coverage_percentage = total_branches > 0 ? (covered_branches.to_f / total_branches * 100).round(2) : 0
    
    puts "Branch Coverage: #{covered_branches}/#{total_branches} (#{@branch_coverage_percentage}%)"
    puts "Uncovered branches: #{@uncovered_branches.length}"
  end

  def generate_detailed_report
    puts "\n=== DETAILED COVERAGE ANALYSIS REPORT ==="
    puts
    
    # Summary
    puts "## COVERAGE SUMMARY"
    puts "- Line Coverage: #{@line_coverage_percentage}%"
    puts "- Branch Coverage: #{@branch_coverage_percentage}%"
    puts "- Uncovered Lines: #{@uncovered_lines.length}"
    puts "- Uncovered Branches: #{@uncovered_branches.length}"
    puts
    
    # Uncovered lines with source code
    if @uncovered_lines.any?
      puts "## UNCOVERED LINES"
      @uncovered_lines.each do |line_number|
        if line_number <= @lexer_source_lines.length
          source_line = @lexer_source_lines[line_number - 1].chomp
          puts "Line #{line_number}: #{source_line}"
        end
      end
      puts
    end
    
    # Method-by-method analysis
    analyze_method_coverage
    
    # Identify specific gaps
    identify_coverage_gaps
    
    # Generate recommendations
    generate_recommendations
  end

  def analyze_method_coverage
    puts "## METHOD COVERAGE ANALYSIS"
    
    method_ranges = {
      'initialize' => (22..28),
      'error' => (30..49),
      'advance' => (51..63),
      'skip_whitespace' => (65..69),
      'skip_comment' => (71..80),
      'read_number' => (82..95),
      'get_next_token' => (97..271),
      'next_token' => (274..276),
      'tokenize' => (278..287),
      'peek_char' => (291..294),
      'alpha?' => (296..300),
      'alphanumeric?' => (302..304),
      'read_identifier' => (306..429),
      'tokenize_string' => (431..475),
      'in_function_definition_context?' => (477..485),
      'in_arithmetic_context?' => (487..498),
      'peek_word' => (503..519),
      'skip_word' => (521..526),
      'read_word' => (528..536),
      'comment_context?' => (538..546)
    }
    
    method_ranges.each do |method_name, range|
      covered_lines = range.count { |line| @line_coverage[line - 1] && @line_coverage[line - 1] > 0 }
      total_lines = range.size
      coverage_pct = (covered_lines.to_f / total_lines * 100).round(1)
      
      status = coverage_pct == 100.0 ? "✓ FULL" : coverage_pct >= 80.0 ? "⚠ PARTIAL" : "✗ LOW"
      puts "#{method_name.ljust(35)} #{status.ljust(10)} #{coverage_pct}% (#{covered_lines}/#{total_lines})"
      
      if coverage_pct < 100.0
        uncovered_in_method = range.select { |line| @line_coverage[line - 1] == 0 }
        if uncovered_in_method.any?
          puts "  Uncovered lines: #{uncovered_in_method.join(', ')}"
        end
      end
    end
    puts
  end

  def identify_coverage_gaps
    puts "## SPECIFIC COVERAGE GAPS"
    
    gaps = []
    
    # Check specific areas that are commonly missed
    critical_areas = {
      'Error handling in tokenize_string' => (460..461), # Incomplete escape sequence error
      'Backslash token handling' => (247..258), # Backslash character handling
      'Single quote string support' => (191..192), # Single quote strings
      'Context detection methods' => (477..498), # Function and arithmetic context
      'Private helper methods' => (503..546), # peek_word, skip_word, etc.
      'Edge cases in read_number' => (86..91), # Decimal number edge cases
      'Comment context detection' => (538..546), # comment_context? method
      'Position tracking edge cases' => (54..62), # Newline handling in advance
    }
    
    critical_areas.each do |area_name, range|
      uncovered_lines = range.select { |line| @line_coverage[line - 1] == 0 }
      if uncovered_lines.any?
        gaps << {
          area: area_name,
          uncovered_lines: uncovered_lines,
          impact: 'HIGH'
        }
      end
    end
    
    gaps.each do |gap|
      puts "#{gap[:impact]} PRIORITY: #{gap[:area]}"
      puts "  Uncovered lines: #{gap[:uncovered_lines].join(', ')}"
      gap[:uncovered_lines].each do |line|
        source_line = @lexer_source_lines[line - 1].chomp
        puts "    Line #{line}: #{source_line}"
      end
      puts
    end
  end

  def generate_recommendations
    puts "## RECOMMENDATIONS FOR 100% COVERAGE"
    puts
    
    recommendations = []
    
    # Analyze uncovered lines and provide specific recommendations
    @uncovered_lines.each do |line_number|
      source_line = @lexer_source_lines[line_number - 1].chomp.strip
      
      case line_number
      when 38
        recommendations << "Test edge case where error method is called for invalid character"
      when 460..461
        recommendations << "Test incomplete escape sequence at end of string (raises error)"
      when 251..257
        recommendations << "Test backslash character handling and escape sequence recognition"
      when 317..320
        recommendations << "Test identifier with trailing '?' character"
      when 477..485
        recommendations << "Test in_function_definition_context? method by checking recent 'make' keyword"
      when 487..498
        recommendations << "Test in_arithmetic_context? method with arithmetic expressions"
      when 503..546
        recommendations << "Test private helper methods (peek_word, skip_word, read_word, comment_context?)"
      else
        if source_line.include?('raise')
          recommendations << "Test error condition at line #{line_number}: #{source_line}"
        elsif source_line.include?('if') || source_line.include?('elsif') || source_line.include?('case')
          recommendations << "Test conditional branch at line #{line_number}: #{source_line}"
        elsif source_line.include?('rescue')
          recommendations << "Test exception handling at line #{line_number}: #{source_line}"
        else
          recommendations << "Test execution path at line #{line_number}: #{source_line}"
        end
      end
    end
    
    # Remove duplicates and sort
    recommendations.uniq.each_with_index do |rec, index|
      puts "#{index + 1}. #{rec}"
    end
    
    puts
    puts "## ADDITIONAL TESTING NEEDED"
    puts "- Test single quote string literals"
    puts "- Test incomplete escape sequences in strings"
    puts "- Test backslash character handling"
    puts "- Test private method coverage through edge cases"
    puts "- Test context detection methods"
    puts "- Test error recovery mechanisms"
    puts "- Test position tracking accuracy"
    puts "- Test all ambiguous token scenarios"
  end
end

# Run the analysis
if __FILE__ == $0
  analyzer = LexerCoverageAnalysis.new
  analyzer.run_analysis
end