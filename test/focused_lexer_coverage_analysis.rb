#!/usr/bin/env ruby

require 'json'

# Read the SimpleCov results
puts "📊 FOCUSED LEXER COVERAGE ANALYSIS"
puts "=" * 50

resultset_path = 'coverage/.resultset.json'

if File.exist?(resultset_path)
  results = JSON.parse(File.read(resultset_path))
  
  # Find the latest test run results
  latest_run = results.values.first
  
  if latest_run && latest_run['coverage']
    coverage_data = latest_run['coverage']
    
    # Find lexer.rb coverage specifically
    lexer_file = coverage_data.keys.find { |key| key.end_with?('src/lexer.rb') }
    
    if lexer_file
      lexer_coverage = coverage_data[lexer_file]
      
      # Calculate lexer-specific coverage
      # Handle different coverage data formats
      if lexer_coverage.is_a?(Hash)
        # Branch coverage format
        total_lines = lexer_coverage.keys.length
        covered_lines = lexer_coverage.count { |line, hits| hits && (hits.is_a?(Array) ? hits.any? { |h| h > 0 } : hits > 0) }
      else
        # Line coverage format
        total_lines = lexer_coverage.length
        covered_lines = lexer_coverage.count { |hits| hits && (hits.is_a?(Array) ? hits.any? { |h| h > 0 } : hits > 0) }
      end
      coverage_percentage = (covered_lines.to_f / total_lines * 100).round(2)
      
      puts "🎯 LEXER COVERAGE RESULTS:"
      puts "  File: #{lexer_file}"
      puts "  Total Lines: #{total_lines}"
      puts "  Covered Lines: #{covered_lines}"
      puts "  Coverage Percentage: #{coverage_percentage}%"
      puts ""
      
      # Check if we hit our 80% target
      if coverage_percentage >= 80.0
        puts "✅ SUCCESS: 80%+ lexer coverage achieved!"
        puts "   Target: 80%"
        puts "   Actual: #{coverage_percentage}%"
        puts "   Improvement: +#{(coverage_percentage - 70.28).round(2)}% from baseline"
      else
        puts "⚠️  TARGET NOT REACHED: #{coverage_percentage}% < 80%"
        puts "   Gap: #{(80.0 - coverage_percentage).round(2)}% remaining"
        puts "   Lines needed: #{((80.0 - coverage_percentage) / 100 * total_lines).ceil} more lines"
      end
      
      puts ""
      puts "📈 COVERAGE BREAKDOWN:"
      # Coverage breakdown (handle different formats)
      if lexer_coverage.is_a?(Hash)
        line_nums = lexer_coverage.keys.sort
        puts "  Lines 1-50 (setup/error): #{line_nums.select { |l| l <= 50 }.count { |l| lexer_coverage[l] && lexer_coverage[l] > 0 }}/#{line_nums.select { |l| l <= 50 }.length}"
        puts "  Lines 51-100: #{line_nums.select { |l| l > 50 && l <= 100 }.count { |l| lexer_coverage[l] && lexer_coverage[l] > 0 }}/#{line_nums.select { |l| l > 50 && l <= 100 }.length}" if line_nums.any? { |l| l > 50 }
      else
        puts "  Lines 1-50 (setup/error): #{lexer_coverage[0,50].count { |h| h && (h.is_a?(Array) ? h.any? { |x| x > 0 } : h > 0) }}/50"
        puts "  Lines 51-100: #{lexer_coverage[50,50]&.count { |h| h && (h.is_a?(Array) ? h.any? { |x| x > 0 } : h > 0) }}/50" if lexer_coverage.length > 50
      end
      
      # Show uncovered critical lines if target not met
      if coverage_percentage < 80.0
        puts ""
        puts "🔍 UNCOVERED CRITICAL LINES:"
        if lexer_coverage.is_a?(Hash)
          lexer_coverage.each do |line_num, hits|
            if !hits || hits == 0
              # Show lines in our target ranges
              if (30..49).include?(line_num) ||
                 (460..475).include?(line_num) ||
                 (477..546).include?(line_num)
                puts "  Line #{line_num}: Not covered (target area)"
              end
            end
          end
        else
          lexer_coverage.each_with_index do |hits, index|
            line_num = index + 1
            covered = hits && (hits.is_a?(Array) ? hits.any? { |h| h > 0 } : hits > 0)
            if !covered
              # Show lines in our target ranges
              if (30..49).include?(line_num) ||
                 (460..475).include?(line_num) ||
                 (477..546).include?(line_num)
                puts "  Line #{line_num}: Not covered (target area)"
              end
            end
          end
        end
      end
      
    else
      puts "❌ ERROR: Could not find lexer.rb in coverage data"
      puts "Available files:"
      coverage_data.keys.each { |key| puts "  - #{key}" }
    end
  else
    puts "❌ ERROR: No coverage data found in results"
  end
else
  puts "❌ ERROR: Coverage results file not found: #{resultset_path}"
end

puts ""
puts "💡 To view detailed coverage report: open test/coverage/index.html"