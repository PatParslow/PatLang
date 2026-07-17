#!/usr/bin/env ruby

# Patlang Custom Test Runner
# Discovers and runs all .patlang test files, collects per-test results, and prints a summary.

require 'pathname'
require 'find'
require 'simplecov'

# Start coverage if available
begin
  SimpleCov.start do
    add_filter '/test/'
    add_group 'Patlang Core', 'patlang-core/'
    add_group 'Ruby Host', 'ruby-host/'
    add_group 'Selfhost', 'patlang-selfhost/'
  end
rescue LoadError
  # SimpleCov not available, continue without coverage
end

# Add project directories to load path
project_root = Pathname.new(__dir__).expand_path
$LOAD_PATH.unshift(project_root.join('patlang-core').to_s)
$LOAD_PATH.unshift(project_root.join('ruby-host').to_s)

require_relative 'patlang-core/lexer/lexer'
require_relative 'patlang-core/parser/parser'
require_relative 'patlang-core/evaluator/evaluator'
require 'set'
require 'stringio'

def discover_patlang_test_files
  files = Dir.glob('patlang-selfhost/tests/**/*.patlang')
    .reject { |f| f.include?('hierarchical_comprehensive_tests.patlang') }
    .reject { |f| f.include?('test_utilities.patlang') }
  puts "[TEST RUNNER DIAG] Discovered test files: #{files.inspect}"
  files
end

def extract_test_blocks(ast)
  # Recursively find all TestBlockNode nodes in the AST, including nested ones
  result = []
  queue = [ast]
  until queue.empty?
    node = queue.shift
    next unless node.is_a?(Object)
    if node.class.name =~ /TestBlockNode/
      result << node
    end
    # Recursively check all instance variables for AST nodes or arrays of nodes
    node.instance_variables.each do |ivar|
      val = node.instance_variable_get(ivar)
      if val.is_a?(Array)
        val.each { |v| queue << v if v.is_a?(Object) }
      elsif val.is_a?(Object)
        queue << val
      end
    end
  end
  result
end

def run_patlang_test_file(filename)
  begin
    source = File.read(filename)
    lexer = Lexer.new(source)
    tokens = lexer.tokenize
    parser = Parser.new(tokens, filename)
    ast = parser.parse
    puts "[TEST RUNNER DIAG] Parsed AST for #{filename}: #{ast.inspect}"

    # Print all top-level AST node types for diagnostics
    if ast.respond_to?(:statements)
      puts "[TEST RUNNER DIAG] Top-level AST node types:"
      ast.statements.each_with_index do |node, idx|
        puts "  Node #{idx}: #{node.class} (#{node.respond_to?(:type) ? node.type : 'no type'})"
      end
    else
      puts "[TEST RUNNER DIAG] AST is not a block with statements: #{ast.class}"
    end

    # DEBUG: Print AST structure for inspection
    begin
      require 'pp'
      puts "DEBUG: AST for #{filename}:"
      PP.pp(ast, $stdout, 80)
    rescue => e
      puts "DEBUG: Failed to print AST for #{filename}: #{e.class}: #{e.message}"
    end

    test_blocks = extract_test_blocks(ast)
    puts "[TEST RUNNER DIAG] Found #{test_blocks.size} test blocks in #{filename}"
    evaluator = Evaluator.new

    results = []
    if test_blocks.empty?
      results << { name: '(no test blocks found)', status: :skipped, error: 'No test blocks found in file' }
    else
      # Always execute all discovered test blocks as independent tests, regardless of nesting
      test_blocks.each do |test_block|
        begin
          # If the test block contains nested test blocks, skip evaluating its body directly
          nested = extract_test_blocks(test_block.body) rescue []
          if nested.any?
            results << { name: test_block.respond_to?(:name) ? test_block.name : '(unnamed)', status: :skipped, error: 'Nested test block (container only)' }
            next
          end
          begin
            evaluator.evaluate(test_block)
            results << { name: test_block.respond_to?(:name) ? test_block.name : '(unnamed)', status: :passed }
          rescue => e
            puts "[TEST RUNNER DIAG] Exception during evaluation: #{e.class}: #{e.message}"
            puts "[TEST RUNNER DIAG] Backtrace:\n#{e.backtrace.join("\n")}"
            results << { name: test_block.respond_to?(:name) ? test_block.name : '(unnamed)', status: :error, error: e.message }
          end
        rescue => e
          results << { name: test_block.respond_to?(:name) ? test_block.name : '(unnamed)', status: :failed, error: e.message }
        end
      end
    end
    results
  rescue => e
    # If parsing or lexing fails, report as a single failed test for this file
    [{ name: '(file error)', status: :failed, error: "#{e.class}: #{e.message}" }]
  end
end

def main
  test_files = discover_patlang_test_files
  total = 0
  passed = 0
  failed = 0
  all_results = []

  puts "🔎 Found #{test_files.size} Patlang test files."
  test_files.each do |file|
    puts "\n🧪 Running: #{file}"
    begin
      # Suppress stdout during test execution to avoid duplicate output
      #begin
      #  original_stdout = $stdout
      #  $stdout = StringIO.new
    results = run_patlang_test_file(file)
      #ensure
      #  $stdout = original_stdout
      #end
    rescue => e
      results = [{ name: '(file error)', status: :failed, error: "#{e.class}: #{e.message}" }]
      puts "  ❌ (file error) - #{e.class}: #{e.message}"
    end
    all_results << { file: file, results: results }
    results.each do |r|
      total += 1
      if r[:status] == :passed
        puts "  ✅ #{r[:name]}"
        passed += 1
      elsif r[:status] == :skipped
        puts "  ⚠️  #{r[:name]} - #{r[:error]}"
      else
        puts "  ❌ #{r[:name]} - #{r[:error]}"
        failed += 1
      end
    end
  end

  puts "\n===== Patlang Test Summary ====="
  puts "Total tests: #{total}"
  puts "Passed:      #{passed}"
  puts "Failed:      #{failed}"
  puts "==============================="

  # Patlang coverage summary
  puts "\n================ Patlang Coverage Report ================"
  coverage = PatlangCoverage.coverage
  p "DEBUG: Raw PatlangCoverage.coverage = #{coverage.inspect}"
  if coverage.empty?
    puts "No Patlang code was executed."
  else
    coverage.each do |file, lines|
      puts "File: #{file}"
      sorted = lines.to_a.sort
      puts "  Covered lines: #{sorted.join(', ')}"
      # Optionally, show percent coverage if desired
      begin
        total_lines = File.readlines(file).size
        percent = (sorted.size.to_f / total_lines * 100).round(2)
        puts "  Coverage: #{sorted.size}/#{total_lines} lines (#{percent}%)"
      rescue
        # File may not exist or be readable
      end
    end
  end
  puts "========================================================"

  exit(failed == 0 ? 0 : 1)
end

main if __FILE__ == $PROGRAM_NAME