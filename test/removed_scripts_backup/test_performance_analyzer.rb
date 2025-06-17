#!/usr/bin/env ruby

# Test Performance Analyzer for PATLANG
# Analyzes test execution patterns, identifies bottlenecks, and provides optimization recommendations

require 'json'
require 'benchmark'
require 'fileutils'

class TestPerformanceAnalyzer
  def initialize
    @base_path = File.dirname(__FILE__)
    @categories = %w[infrastructure ruby_implementation patlang_language]
    @results = {}
    @benchmarks = {}
  end

  def analyze_all_tests
    puts "🔍 PATLANG Test Performance Analysis"
    puts "=" * 50
    puts "📅 Analysis started at: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    puts

    @categories.each do |category|
      analyze_category(category)
    end

    generate_performance_report
    save_performance_data
    provide_optimization_recommendations
  end

  def analyze_test_file(test_file)
    puts "🧪 Analyzing individual test: #{test_file}"
    
    start_time = Time.now
    
    # Measure memory before
    memory_before = get_memory_usage
    
    # Execute test with detailed timing
    execution_result = nil
    execution_time = Benchmark.realtime do
      execution_result = execute_test_with_profiling(test_file)
    end
    
    # Measure memory after
    memory_after = get_memory_usage
    memory_delta = memory_after - memory_before
    
    {
      file: test_file,
      execution_time: execution_time,
      memory_usage: memory_delta,
      success: execution_result[:success],
      output_size: execution_result[:output].length,
      test_count: count_tests_in_file(test_file),
      complexity_score: calculate_complexity_score(test_file)
    }
  end

  private

  def analyze_category(category)
    puts "📂 Analyzing category: #{category.upcase}"
    
    category_path = File.join(@base_path, category)
    unless Dir.exist?(category_path)
      puts "   ❌ Directory not found: #{category_path}"
      return
    end

    test_files = Dir.glob(File.join(category_path, 'test_*.rb')).sort
    
    if test_files.empty?
      puts "   ⚠️  No test files found"
      return
    end

    puts "   🔍 Found #{test_files.length} test files"
    
    category_results = []
    total_time = 0
    
    test_files.each_with_index do |test_file, index|
      filename = File.basename(test_file)
      puts "   [#{index + 1}/#{test_files.length}] Analyzing #{filename}..."
      
      result = analyze_test_file(test_file)
      category_results << result
      total_time += result[:execution_time]
      
      # Show immediate feedback for slow tests
      if result[:execution_time] > 10
        puts "     ⚠️  Slow test detected: #{result[:execution_time].round(2)}s"
      end
    end
    
    @results[category] = {
      files: category_results,
      total_time: total_time,
      average_time: total_time / test_files.length,
      total_tests: category_results.sum { |r| r[:test_count] }
    }
    
    puts "   ✅ Category analysis complete: #{total_time.round(2)}s total"
    puts
  end

  def execute_test_with_profiling(test_file)
    output = nil
    success = false
    
    begin
      # Change to test directory and run test
      output = `cd #{@base_path} && ruby #{test_file} 2>&1`
      success = $?.success?
    rescue => e
      output = "Error executing test: #{e.message}"
      success = false
    end
    
    { success: success, output: output }
  end

  def get_memory_usage
    # Simple memory tracking (works on Unix-like systems)
    if File.exist?('/proc/self/status')
      status = File.read('/proc/self/status')
      if match = status.match(/VmRSS:\s+(\d+)\s+kB/)
        return match[1].to_i
      end
    end
    
    # Fallback for other systems
    0
  end

  def count_tests_in_file(test_file)
    return 0 unless File.exist?(test_file)
    
    content = File.read(test_file)
    
    # Count test method definitions
    test_methods = content.scan(/def test_\w+/).length
    
    # Count test blocks (for newer test frameworks)
    test_blocks = content.scan(/\btest\s+["'].*?["']/).length
    
    [test_methods + test_blocks, 1].max  # At least 1 if file exists
  end

  def calculate_complexity_score(test_file)
    return 0 unless File.exist?(test_file)
    
    content = File.read(test_file)
    
    # Simple complexity scoring based on various factors
    score = 0
    
    # File size factor
    score += (content.length / 1000.0).round(1)
    
    # Control flow complexity
    score += content.scan(/\b(if|else|elsif|while|for|case|when)\b/).length * 0.5
    
    # Method calls complexity
    score += content.scan(/\.\w+\(/).length * 0.1
    
    # String operations complexity
    score += content.scan(/(eval|instance_eval|class_eval)/).length * 2
    
    # Test assertion complexity
    score += content.scan(/assert_/).length * 0.2
    
    score.round(1)
  end

  def generate_performance_report
    puts "📊 PERFORMANCE ANALYSIS REPORT"
    puts "=" * 50
    
    total_execution_time = @results.values.sum { |r| r[:total_time] }
    total_test_count = @results.values.sum { |r| r[:total_tests] }
    
    puts "🏁 OVERALL SUMMARY:"
    puts "   Total execution time: #{total_execution_time.round(2)}s"
    puts "   Total test count: #{total_test_count}"
    puts "   Average time per test: #{(total_execution_time / total_test_count).round(3)}s"
    puts

    # Category breakdown
    puts "📂 CATEGORY BREAKDOWN:"
    @results.each do |category, data|
      puts "   #{category.upcase}:"
      puts "     Files: #{data[:files].length}"
      puts "     Tests: #{data[:total_tests]}"
      puts "     Total time: #{data[:total_time].round(2)}s"
      puts "     Average time: #{data[:average_time].round(2)}s"
      puts "     Time per test: #{(data[:total_time] / data[:total_tests]).round(3)}s"
      puts
    end

    # Performance classifications
    classify_test_performance
    
    # Bottleneck identification
    identify_bottlenecks
  end

  def classify_test_performance
    puts "⚡ PERFORMANCE CLASSIFICATION:"
    
    fast_tests = []
    medium_tests = []
    slow_tests = []
    very_slow_tests = []
    
    @results.each do |category, data|
      data[:files].each do |file_data|
        avg_time_per_test = file_data[:execution_time] / file_data[:test_count]
        
        file_info = {
          category: category,
          file: File.basename(file_data[:file]),
          total_time: file_data[:execution_time],
          avg_per_test: avg_time_per_test,
          test_count: file_data[:test_count]
        }
        
        case avg_time_per_test
        when 0...1
          fast_tests << file_info
        when 1...5
          medium_tests << file_info
        when 5...15
          slow_tests << file_info
        else
          very_slow_tests << file_info
        end
      end
    end
    
    puts "   🚀 Fast tests (< 1s avg): #{fast_tests.length}"
    puts "   🏃 Medium tests (1-5s avg): #{medium_tests.length}"
    puts "   🐌 Slow tests (5-15s avg): #{slow_tests.length}"
    puts "   🐌🐌 Very slow tests (> 15s avg): #{very_slow_tests.length}"
    puts
    
    # Show slowest tests
    if slow_tests.any? || very_slow_tests.any?
      puts "   ⚠️  SLOWEST TESTS:"
      (slow_tests + very_slow_tests)
        .sort_by { |t| t[:avg_per_test] }
        .reverse
        .first(5)
        .each do |test|
          puts "     - #{test[:category]}/#{test[:file]}: #{test[:avg_per_test].round(2)}s avg (#{test[:test_count]} tests)"
        end
      puts
    end

    @performance_classification = {
      fast: fast_tests,
      medium: medium_tests,
      slow: slow_tests,
      very_slow: very_slow_tests
    }
  end

  def identify_bottlenecks
    puts "🔍 BOTTLENECK ANALYSIS:"
    
    # Identify files taking > 20% of total time
    total_time = @results.values.sum { |r| r[:total_time] }
    bottlenecks = []
    
    @results.each do |category, data|
      data[:files].each do |file_data|
        time_percentage = (file_data[:execution_time] / total_time) * 100
        
        if time_percentage > 20
          bottlenecks << {
            category: category,
            file: File.basename(file_data[:file]),
            time: file_data[:execution_time],
            percentage: time_percentage,
            complexity: file_data[:complexity_score]
          }
        end
      end
    end
    
    if bottlenecks.any?
      puts "   ⚠️  Major bottlenecks (> 20% of total time):"
      bottlenecks.sort_by { |b| b[:percentage] }.reverse.each do |bottleneck|
        puts "     - #{bottleneck[:category]}/#{bottleneck[:file]}: #{bottleneck[:time].round(2)}s (#{bottleneck[:percentage].round(1)}%)"
      end
    else
      puts "   ✅ No major bottlenecks detected"
    end
    
    puts
  end

  def provide_optimization_recommendations
    puts "💡 OPTIMIZATION RECOMMENDATIONS:"
    puts "=" * 50
    
    # Fast feedback recommendations
    fast_tests = @performance_classification[:fast]
    medium_tests = @performance_classification[:medium]
    
    if fast_tests.length >= 10
      puts "✅ FAST FEEDBACK SUITE:"
      puts "   You have #{fast_tests.length} fast tests suitable for rapid feedback"
      puts "   Recommended fast suite:"
      fast_tests.first(10).each do |test|
        puts "     - #{test[:category]}/#{test[:file]}"
      end
      puts
    end
    
    # Parallelization recommendations
    medium_plus_tests = medium_tests + @performance_classification[:slow]
    if medium_plus_tests.length >= 4
      puts "🔀 PARALLELIZATION OPPORTUNITIES:"
      puts "   #{medium_plus_tests.length} tests suitable for parallel execution"
      puts "   Estimated speedup: #{(medium_plus_tests.length / 4.0).round(1)}x with 4 workers"
      puts
    end
    
    # Caching recommendations
    stable_tests = identify_stable_tests
    if stable_tests.any?
      puts "💾 CACHING OPPORTUNITIES:"
      puts "   #{stable_tests.length} tests suitable for result caching"
      puts "   Potential time savings: #{stable_tests.sum { |t| t[:total_time] }.round(2)}s per run"
      puts
    end
    
    # Performance improvements
    very_slow_tests = @performance_classification[:very_slow]
    if very_slow_tests.any?
      puts "🔧 PERFORMANCE IMPROVEMENTS NEEDED:"
      very_slow_tests.each do |test|
        puts "   - #{test[:category]}/#{test[:file]}:"
        puts "     Current: #{test[:avg_per_test].round(2)}s per test"
        puts "     Target: < 5s per test"
        puts "     Recommendation: #{get_performance_recommendation(test)}"
      end
      puts
    end
    
    # Test scheduling strategies
    puts "📋 RECOMMENDED TEST SCHEDULING STRATEGIES:"
    puts "   1. Smoke tests: #{fast_tests.first(5).map { |t| t[:file] }.join(', ')}"
    puts "   2. Fast feedback: Tests completing in < 30s total"
    puts "   3. Parallel execution: #{medium_plus_tests.length} tests across 4 workers"
    puts "   4. Full suite: All #{@results.values.sum { |r| r[:files].length }} tests with monitoring"
    puts
  end

  def identify_stable_tests
    # Tests that rarely change and have consistent results
    stable_tests = []
    
    @results.each do |category, data|
      data[:files].each do |file_data|
        # Consider tests stable if they're not too complex and have reasonable execution time
        if file_data[:complexity_score] < 10 && file_data[:execution_time] > 2
          stable_tests << {
            category: category,
            file: File.basename(file_data[:file]),
            total_time: file_data[:execution_time],
            complexity: file_data[:complexity_score]
          }
        end
      end
    end
    
    stable_tests
  end

  def get_performance_recommendation(test)
    if test[:test_count] > 20
      "Consider splitting into smaller test files"
    elsif test[:avg_per_test] > 30
      "Individual tests are too slow - review test setup/teardown"
    elsif test[:category] == 'patlang_language'
      "End-to-end tests - consider mocking heavy dependencies"
    else
      "Review for unnecessary complexity or setup overhead"
    end
  end

  def save_performance_data
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    
    # Save detailed results
    results_file = File.join(@base_path, "performance_analysis_#{timestamp}.json")
    File.write(results_file, JSON.pretty_generate({
      timestamp: Time.now.to_i,
      total_execution_time: @results.values.sum { |r| r[:total_time] },
      categories: @results,
      classification: @performance_classification
    }))
    
    # Save timing data for scheduler
    timing_data = {}
    @results.each do |category, data|
      timing_data[category] = {}
      data[:files].each do |file_data|
        filename = File.basename(file_data[:file])
        timing_data[category][filename] = file_data[:execution_time].round(2)
      end
    end
    
    timing_file = File.join(@base_path, 'test_timings.json')
    File.write(timing_file, JSON.pretty_generate(timing_data))
    
    puts "💾 Performance data saved:"
    puts "   Detailed report: #{results_file}"
    puts "   Timing data: #{timing_file}"
    puts
  end
end

# CLI Interface
if __FILE__ == $0
  analyzer = TestPerformanceAnalyzer.new
  analyzer.analyze_all_tests
  
  puts "🎉 Performance analysis complete!"
  puts "📊 Use the timing data with the intelligent test scheduler for optimal performance"
end