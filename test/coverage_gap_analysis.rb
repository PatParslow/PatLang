#!/usr/bin/env ruby
# Coverage Gap Analysis - Get accurate coverage figures and identify quick wins

require 'simplecov'
require 'pathname'

# Configure SimpleCov for detailed analysis
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  track_files 'src/**/*.rb'
  coverage_dir 'test/coverage'
end

# Load all source files to get accurate coverage baseline
puts "🔍 Loading source files for coverage analysis..."

source_files = Dir.glob('src/**/*.rb').sort
source_files.each do |file|
  begin
    require_relative "../#{file}"
    puts "✅ Loaded: #{file}"
  rescue => e
    puts "⚠️  Warning loading #{file}: #{e.message}"
  end
end

# Run a minimal test to establish coverage baseline
puts "\n📊 Establishing coverage baseline..."

# Import key test infrastructure
require_relative 'helpers/test_helper'

# Run basic functionality tests to see current coverage
puts "🧪 Running baseline functionality tests..."

begin
  # Test lexer
  lexer = Lexer.new("x = 42")
  tokens = lexer.tokenize
  puts "✅ Lexer: #{tokens.length} tokens generated"
  
  # Test parser
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "✅ Parser: AST generated"
  
  # Test evaluator if available
  begin
    evaluator = Evaluator.new
    result = evaluator.evaluate(ast)
    puts "✅ Evaluator: Result = #{result}"
  rescue => e
    puts "⚠️  Evaluator test failed: #{e.message}"
  end
  
rescue => e
  puts "⚠️  Baseline test failed: #{e.message}"
end

# Generate coverage report
puts "\n📈 Generating detailed coverage report..."

# Force SimpleCov to generate report
SimpleCov.result.format!

puts "\n📊 COVERAGE ANALYSIS SUMMARY"
puts "=" * 50

# Get coverage data
result = SimpleCov.result
total_lines = result.total_lines
covered_lines = result.covered_lines
line_coverage = result.covered_percent

puts "📍 Overall Coverage:"
puts "   Lines: #{covered_lines}/#{total_lines} (#{line_coverage.round(2)}%)"

# Analyze by directory
puts "\n📂 Coverage by Directory:"
coverage_by_dir = {}

result.files.each do |file|
  dir = File.dirname(file.filename).gsub(Dir.pwd + '/', '')
  coverage_by_dir[dir] ||= { total: 0, covered: 0, files: [] }
  coverage_by_dir[dir][:total] += file.lines_of_code
  coverage_by_dir[dir][:covered] += file.covered_lines.count
  coverage_by_dir[dir][:files] << {
    name: File.basename(file.filename),
    lines: file.lines_of_code,
    covered: file.covered_lines.count,
    percentage: file.covered_percent.round(2)
  }
end

coverage_by_dir.sort_by { |dir, data| -data[:total] }.each do |dir, data|
  percentage = data[:total] > 0 ? (data[:covered].to_f / data[:total] * 100).round(2) : 0
  puts "   #{dir}: #{data[:covered]}/#{data[:total]} (#{percentage}%)"
end

# Identify quick wins - files with low coverage but high importance
puts "\n🎯 QUICK WIN OPPORTUNITIES:"
puts "=" * 50

quick_wins = []
result.files.each do |file|
  filename = File.basename(file.filename)
  relative_path = file.filename.gsub(Dir.pwd + '/', '')
  
  # Skip if already well covered
  next if file.covered_percent > 50
  
  # Prioritize important files
  importance_score = 0
  importance_score += 10 if filename.include?('parser')
  importance_score += 10 if filename.include?('evaluator')
  importance_score += 8 if filename.include?('lexer')
  importance_score += 6 if filename.include?('token')
  importance_score += 5 if filename.include?('ast')
  importance_score += 4 if filename.include?('reasoning')
  importance_score += 3 if filename.include?('object')
  
  if importance_score > 0 && file.lines_of_code > 10
    quick_wins << {
      file: relative_path,
      lines: file.lines_of_code,
      covered: file.covered_lines.count,
      percentage: file.covered_percent.round(2),
      importance: importance_score,
      potential_gain: file.lines_of_code - file.covered_lines.count
    }
  end
end

# Sort by importance and potential gain
quick_wins.sort_by! { |f| [-f[:importance], -f[:potential_gain]] }

puts "\n🚀 TOP QUICK WIN TARGETS:"
quick_wins.first(10).each_with_index do |file, index|
  puts "#{index + 1}. #{file[:file]}"
  puts "   Current: #{file[:covered]}/#{file[:lines]} (#{file[:percentage]}%)"
  puts "   Potential gain: #{file[:potential_gain]} lines"
  puts "   Importance: #{file[:importance]}/10"
  puts ""
end

# Look for completely untested files
puts "\n🚨 COMPLETELY UNTESTED FILES:"
untested = result.files.select { |f| f.covered_lines.count == 0 && f.lines_of_code > 5 }
untested.each do |file|
  relative_path = file.filename.gsub(Dir.pwd + '/', '')
  puts "   #{relative_path} (#{file.lines_of_code} lines)"
end

puts "\n✅ Coverage analysis complete!"
puts "📊 Detailed report: test/coverage/index.html"