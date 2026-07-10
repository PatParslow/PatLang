#!/usr/bin/env ruby

require 'find'
require 'open3'
require 'pathname'
require 'timeout'

ROOT = Pathname.new(__dir__).parent.parent.expand_path
PATLANG_BIN = ROOT.join('bin', 'patlang').to_s
TESTS_DIR = Pathname.new(__dir__)

def discover_patlang_tests
  tests = []
  Find.find(TESTS_DIR.to_s) do |path|
    next unless path.end_with?('.patlang')
    # Exclude golden data files (e.g., .tokens, .ast)
    next if path =~ /\.(tokens|ast)$/
    tests << path if File.read(path) =~ /test\s+"[^"]+"\s+{/
  end
  tests
end

def discover_ruby_test_scripts
  scripts = []
  Find.find(TESTS_DIR.to_s) do |path|
    next unless path.end_with?('.rb')
    # Include all test_*.rb scripts except this script and helpers (exclude fuzz, golden, and files not matching test_*.rb)
    #only include them if they contain one or more 'test' block -- simple text match on 'test' is not sufficient to be sure of that
    #need to check for test <string> { ... } blocks
    fname = File.basename(path)
    next if fname == File.basename(__FILE__)
    next if path.include?('fuzz') || path.include?('golden')
    scripts << path if fname =~ /^test_.*\.rb$/ && File.read(path) =~ /test\s+"[^"]+"\s+{/
  end
  scripts
end

def run_patlang_test(test_file)
  require 'open3'
  require 'timeout'
  stdout, stderr, status = '', '', nil
  begin
    Timeout.timeout(20) do
      Open3.popen3('ruby', PATLANG_BIN, test_file) do |i, o, e, t|
        i.close
        out_reader = Thread.new { o.read }
        err_reader = Thread.new { e.read }
        status = t.value
        stdout = out_reader.value
        stderr = err_reader.value
      end
    end
  rescue Timeout::Error
    # Find and kill the process if still running
    if defined?(t) && t&.alive?
      Process.kill('KILL', t.pid) rescue nil
    end
    return {
      file: test_file,
      status: false,
      stdout: stdout,
      stderr: 'Timeout'
    }
  end
  {
    file: test_file,
    status: status&.success?,
    stdout: stdout,
    stderr: stderr
  }
end

def run_ruby_test_script(script_file)
  stdout, stderr, status = Open3.capture3('ruby', script_file)
  {
    file: script_file,
    status: status.success?,
    stdout: stdout,
    stderr: stderr
  }
end

puts "=== Patlang Integration Test Runner ==="
puts "Interpreter: #{PATLANG_BIN}"
puts "Test root:   #{TESTS_DIR}"

results = []

# Run .patlang tests
patlang_tests = discover_patlang_tests
puts "\nRunning .patlang tests (#{patlang_tests.size} found)..."
patlang_tests.each_with_index do |test, idx|
  print "\nRunning: #{test} ... "
  begin
    res = nil
    Timeout.timeout(20) do
      res = run_patlang_test(test)
    end
    results << res
    if res[:status]
      print '.'
    else
      print 'F'
      puts "\n[DIAGNOSTIC] Test failed: #{test}"
      puts "[DIAGNOSTIC] Failure details: #{res[:stderr].to_s.strip.empty? ? res[:stdout].to_s.strip : res[:stderr].to_s.strip}"
      puts "[DIAGNOSTIC] Continuing to next test file (#{idx + 1}/#{patlang_tests.size})"
    end
  rescue Timeout::Error
    results << { file: test, status: false, stdout: '', stderr: 'Timeout' }
    print 'T'
    puts "\n[DIAGNOSTIC] Test timed out: #{test}"
    puts "[DIAGNOSTIC] Continuing to next test file (#{idx + 1}/#{patlang_tests.size})"
  end
end
puts

# Run Ruby test scripts (fuzz/golden)
ruby_scripts = discover_ruby_test_scripts
puts "\nRunning Ruby test scripts (#{ruby_scripts.size} found)..."
ruby_scripts.each do |script|
  print "\nRunning: #{script} ... "
  begin
    res = nil
    Timeout.timeout(30) do
      res = run_ruby_test_script(script)
    end
    results << res
    print res[:status] ? '.' : 'F'
  rescue Timeout::Error
    results << { file: script, status: false, stdout: '', stderr: 'Timeout' }
    print 'T'
  end
end
puts

# Summary
failures = results.reject { |r| r[:status] }
puts "\n=== Test Summary ==="

# Enhanced per-test reporting for .patlang files
total_cases = 0
passed_cases = 0
failed_cases = 0
detailed_failures = []


results.each do |res|
  if res[:file].end_with?('.patlang')
    test_lines = res[:stdout].lines.grep(/^(PASS|FAIL): /)
    # If no explicit PASS/FAIL lines, synthesize PASS for each test block if exit was 0
    if test_lines.empty? && res[:status]
      # Parse test block names from the test file
      test_names = []
      File.read(res[:file]).scan(/test\s+"([^"]+)"\s*{/) { |m| test_names << m[0] }
      if test_names.empty?
        puts "\nFile: #{res[:file]} - No per-test output detected."
      else
        puts "\nResults for #{res[:file]}:"
        test_names.each do |name|
          puts "  PASS: #{name}"
          passed_cases += 1
          total_cases += 1
        end
      end
      next
    end
    if test_lines.empty?
      puts "\nFile: #{res[:file]} - No per-test output detected."
      next
    end
    puts "\nResults for #{res[:file]}:"
    # Group PASS/FAIL lines by test name
    test_block_results = Hash.new { |h, k| h[k] = [] }
    test_lines.each do |line|
      if line =~ /^(PASS|FAIL):\s*(.+)$/
        result = $1 == 'PASS'
        name = $2.strip
        test_block_results[name] << result
      end
    end
    test_block_results.each do |name, results|
      if results.all?
        puts "  PASS: #{name}"
        passed_cases += 1
      else
        puts "  FAIL: #{name}"
        failed_cases += 1
        detailed_failures << { file: res[:file], detail: "FAIL: #{name}" }
      end
      total_cases += 1
    end
  end
end

puts "\nTotal test cases: #{total_cases}, Passed: #{passed_cases}, Failed: #{failed_cases}"

if failed_cases > 0
  puts "\n--- Failed Test Cases ---"
  detailed_failures.each do |fail|
    puts "File: #{fail[:file]} | #{fail[:detail]}"
  end
end

# Legacy file-level summary
failures = results.reject { |r| r[:status] }
puts "\n(File-level) Total: #{results.size}, Passed: #{results.size - failures.size}, Failed: #{failures.size}"

if failures.any?
  puts "\n--- File-level Failures ---"
  failures.each do |fail|
    puts "\nFile: #{fail[:file]}"
    puts "Stdout:\n#{fail[:stdout]}"
    puts "Stderr:\n#{fail[:stderr]}"
  end
end

exit(failures.empty? ? 0 : 1)