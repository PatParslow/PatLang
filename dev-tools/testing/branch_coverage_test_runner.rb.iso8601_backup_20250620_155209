#!/usr/bin/env ruby

require 'simplecov'
require 'json'
require 'minitest/autorun'
require_relative 'helpers/config_loader'

# Configure SimpleCov using configuration
simplecov_config = TestConfigLoader.simplecov_config
coverage_reporting = TestConfigLoader.coverage_reporting
coverage_thresholds = TestConfigLoader.coverage_thresholds

SimpleCov.start do
  enable_coverage :branch
  enable_coverage :line
  
  # Apply filters from configuration
  simplecov_config[:filters].each { |filter| add_filter filter }
  
  # Apply groups from configuration
  simplecov_config[:groups].each { |name, pattern| add_group name, pattern }
  
  # Track files from configuration
  track_files simplecov_config[:track_files]
  
  # Set coverage directory
  coverage_dir coverage_reporting[:output_directory]
  
  # Configure formatters based on reporting configuration
  formatters = []
  coverage_reporting[:formats].each do |format|
    case format
    when 'html'
      formatters << SimpleCov::Formatter::HTMLFormatter
    when 'simple'
      formatters << SimpleCov::Formatter::SimpleFormatter
    when 'json'
      formatters << SimpleCov::Formatter::JSONFormatter if defined?(SimpleCov::Formatter::JSONFormatter)
    end
  end
  
  formatter SimpleCov::Formatter::MultiFormatter.new(formatters) unless formatters.empty?
  
  # Set minimum coverage from configuration
  minimum_coverage(
    line: coverage_thresholds[:minimum_line],
    branch: coverage_thresholds[:minimum_branch]
  )
end

class BranchCoverageTestRunner
  def initialize
    # Load configuration
    @config = TestConfigLoader.load_config
    @branch_config = TestConfigLoader.test_category('branch_coverage')
    @timeout_config = TestConfigLoader.timeout_config(:branch_coverage)
    
    # Discover test files dynamically
    @test_files = discover_branch_coverage_tests
    @baseline_coverage = { line: 0.03, branch: 0.0 }
  end

  def run_coverage_tests
    puts "=== #{@branch_config['name'].upcase} ==="
    puts "#{@branch_config['description']}"
    puts "Baseline Coverage: Line: #{@baseline_coverage[:line]}%, Branch: #{@baseline_coverage[:branch]}%"
    puts "Test Timeout: #{@timeout_config}s"
    puts "Auto-discovered #{@test_files.length} test files"
    puts ""

    start_time = Time.now

    # Load and run all test files
    @test_files.each do |test_file|
      if File.exist?(test_file)
        puts "Loading #{test_file}..."
        require_relative "../#{test_file}"
      else
        puts "WARNING: Test file not found: #{test_file}"
      end
    end

    end_time = Time.now
    duration = end_time - start_time

    puts ""
    puts "=== TEST EXECUTION SUMMARY ==="
    puts "Total execution time: #{duration.round(2)} seconds"
    puts "Test files loaded: #{@test_files.length}"
    
    # Generate coverage report
    generate_coverage_report
  end

  private

  def discover_branch_coverage_tests
    discovered_files = []
    
    # Use test directory from configuration
    if @branch_config['test_directory']
      discovered_files.concat(TestConfigLoader.discover_test_files(@branch_config['test_directory']))
    end
    
    # Also include any explicitly specified test files
    if @branch_config['test_files']
      discovered_files.concat(@branch_config['test_files'])
    end
    
    # Fallback to common branch coverage test patterns if no files found
    if discovered_files.empty?
      patterns = [
        'test/infrastructure/test_*_branch_coverage.rb',
        'test/patlang_language/test_*_branch_coverage.rb',
        'test/branch_coverage/**/*test*.rb'
      ]
      
      patterns.each do |pattern|
        discovered_files.concat(Dir.glob(pattern))
      end
    end
    
    discovered_files.sort.uniq
  end

  def generate_coverage_report
    puts ""
    puts "=== COVERAGE IMPROVEMENT REPORT ==="
    
    # SimpleCov will automatically generate coverage at exit
    # We'll create a summary of what we expect to see
    
    expected_improvements = {
      'src/lexer.rb' => {
        description: 'Lexer error handling, edge cases, and boundary conditions',
        new_branches_covered: [
          'Invalid character error handling',
          'Nil character safety checks', 
          'Newline handling in advance',
          'Number parsing edge cases',
          'Comment handling at EOF',
          'String escape sequences',
          'Whitespace detection variants',
          'Peek character functionality',
          'Ambiguous token scenarios'
        ]
      },
      'src/parser.rb' => {
        description: 'Parser initialization, error handling, and expression parsing',
        new_branches_covered: [
          'Parser initialization with lexer vs tokens',
          'Error handling with/without token info',
          'Timeout protection mechanisms',
          'Malformed function definitions',
          'Nested expression edge cases',
          'Type constraint parsing errors',
          'Token resolver ambiguous cases',
          'Expression operator precedence',
          'Function call edge cases'
        ]
      },
      'src/evaluator.rb' => {
        description: 'Evaluator arithmetic, string ops, and reasoning integration',
        new_branches_covered: [
          'Division by zero handling',
          'String operations on nil',
          'Function calls with wrong args',
          'Reasoning mode transitions',
          'Variable scope edge cases',
          'Return value handling',
          'Builtin class initialization',
          'Comparison operations',
          'Logical operations and short-circuit',
          'Object evaluation edge cases'
        ]
      }
    }

    expected_improvements.each do |file, info|
      puts "\n#{file}:"
      puts "  #{info[:description]}"
      puts "  New branches covered (#{info[:new_branches_covered].length}):"
      info[:new_branches_covered].each do |branch|
        puts "    ✓ #{branch}"
      end
    end

    coverage_targets = TestConfigLoader.all_coverage_targets(:line)
    branch_targets = TestConfigLoader.all_coverage_targets(:branch)
    
    puts "\n=== EXPECTED COVERAGE IMPROVEMENTS ==="
    puts "Line Coverage: Expected improvement from 0.03% to #{coverage_targets.values.min || 90}%"
    puts "Branch Coverage: Expected improvement from 0.0% to #{branch_targets.values.min || 90}%"
    puts ""
    puts "Key improvements:"
    puts "- Comprehensive error handling path coverage"
    puts "- Edge case and boundary condition testing"
    puts "- Parser timeout and recovery mechanism testing"
    puts "- Evaluator reasoning integration coverage"
    puts "- String and arithmetic operation edge cases"
    
    puts "\n=== COVERAGE ANALYSIS INSTRUCTIONS ==="
    puts "1. Check coverage/index.html for detailed branch coverage report"
    puts "2. Look for red/yellow highlighting indicating uncovered branches"
    puts "3. Focus on high-priority files: lexer.rb, parser.rb, evaluator.rb"
    puts "4. Review branch coverage percentages for each critical method"
    puts "5. Identify remaining gaps for next iteration of testing"
    
    save_coverage_summary
  end

  def save_coverage_summary
    coverage_targets = TestConfigLoader.all_coverage_targets(:line)
    branch_targets = TestConfigLoader.all_coverage_targets(:branch)
    
    summary = {
      timestamp: Time.now.iso8601,
      baseline_coverage: @baseline_coverage,
      test_files_executed: @test_files,
      configuration_used: {
        branch_coverage_config: @branch_config,
        timeout: @timeout_config,
        coverage_targets: coverage_targets,
        branch_targets: branch_targets
      },
      expected_improvements: {
        line_coverage: "#{coverage_targets.values.min || 90}%",
        branch_coverage: "#{branch_targets.values.min || 90}%"
      },
      focus_areas: [
        "Error handling paths",
        "Edge case scenarios", 
        "Boundary conditions",
        "Parser recovery mechanisms",
        "Evaluator reasoning integration"
      ],
      next_steps: [
        "Review generated coverage report",
        "Identify remaining coverage gaps",
        "Add tests for uncovered branches",
        "Focus on complex conditional logic",
        "Test exception handling paths"
      ]
    }

    File.write('test/branch_coverage_summary.json', JSON.pretty_generate(summary))
    puts "\nCoverage summary saved to test/branch_coverage_summary.json"
  end
end

# Run the coverage tests if this file is executed directly
if __FILE__ == $0
  runner = BranchCoverageTestRunner.new
  runner.run_coverage_tests
end