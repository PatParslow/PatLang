#!/usr/bin/env ruby

# Simple Native Parser Test - Quick validation and demonstration
# This runs a focused test to demonstrate native parser capabilities

require_relative 'native_parser_bridge'
require_relative 'patlang-core/lexer/lexer'
require_relative 'patlang-core/parser/parser'

class SimpleParserTest
  def initialize
    @bridge = NativeParserBridge.new
    @results = []
  end

  def run_tests
    puts "🚀 Simple Native Parser Test"
    puts "=" * 50
    
    # Test cases
    test_cases = [
      { name: "Simple Assignment", code: "x = 5" },
      { name: "Basic Arithmetic", code: "result = 2 + 3 * 4" },
      { name: "Function Call", code: "greet('Alice')" },
      { name: "If Statement", code: "if x > 0 then\n  print('positive')\nend" },
      { name: "Simple Function", code: "def add(a, b)\n  a + b\nend" }
    ]
    
    test_cases.each do |test_case|
      puts "\n📝 Testing: #{test_case[:name]}"
      puts "    Code: #{test_case[:code].gsub("\n", "\\n")}"
      
      # Test with Ruby parser
      ruby_result = test_ruby_parser(test_case[:code])
      
      # Test with native parser
      native_result = test_native_parser(test_case[:code])
      
      # Compare results
      comparison = compare_results(ruby_result, native_result)
      
      puts "    Ruby:   #{ruby_result[:success] ? '✅' : '❌'} (#{ruby_result[:node_count]} nodes)"
      puts "    Native: #{native_result[:success] ? '✅' : '❌'} (#{native_result[:node_count]} nodes)"
      puts "    Match:  #{comparison[:compatible] ? '✅' : '❌'} (Score: #{comparison[:score].round(2)})"
      
      if native_result[:simulated]
        puts "    Note: Native parser simulation mode"
      end
      
      @results << {
        name: test_case[:name],
        code: test_case[:code],
        ruby_result: ruby_result,
        native_result: native_result,
        comparison: comparison
      }
    end
    
    # Generate summary
    generate_summary
    
    @bridge.cleanup
  end

  private

  def test_ruby_parser(code)
    begin
      start_time = Time.now
      lexer = Lexer.new(code)
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      ast = parser.parse
      end_time = Time.now
      
      {
        success: true,
        ast: ast,
        node_count: count_nodes(ast),
        parse_time: end_time - start_time,
        errors: parser.collected_errors || []
      }
    rescue => e
      {
        success: false,
        error: e.message,
        node_count: 0,
        parse_time: 0,
        errors: [e.message]
      }
    end
  end

  def test_native_parser(code)
    @bridge.parse_with_native_parser(code)
  end

  def count_nodes(ast)
    return 0 unless ast
    count = 1
    if ast.respond_to?(:children) && ast.children
      ast.children.each { |child| count += count_nodes(child) }
    end
    count
  end

  def compare_results(ruby_result, native_result)
    score = 0.0
    
    # Check success match
    if ruby_result[:success] == native_result[:success]
      score += 0.5
    end
    
    # Check node count similarity (if both successful)
    if ruby_result[:success] && native_result[:success]
      ruby_nodes = ruby_result[:node_count] || 0
      native_nodes = native_result[:node_count] || 0
      
      if ruby_nodes > 0 && native_nodes > 0
        ratio = [ruby_nodes, native_nodes].min.to_f / [ruby_nodes, native_nodes].max
        score += 0.3 * ratio
      end
    end
    
    # Check error handling
    ruby_errors = ruby_result[:errors]&.length || 0
    native_errors = native_result[:errors]&.length || 0
    
    if ruby_errors == native_errors
      score += 0.2
    elsif (ruby_errors - native_errors).abs <= 1
      score += 0.1
    end
    
    {
      score: score,
      compatible: score >= 0.7
    }
  end

  def generate_summary
    puts "\n" + "=" * 50
    puts "📊 TEST SUMMARY"
    puts "=" * 50
    
    total_tests = @results.length
    compatible_tests = @results.count { |r| r[:comparison][:compatible] }
    avg_score = @results.map { |r| r[:comparison][:score] }.sum / total_tests
    
    puts "Total Tests: #{total_tests}"
    puts "Compatible: #{compatible_tests} (#{(compatible_tests.to_f / total_tests * 100).round(1)}%)"
    puts "Average Compatibility Score: #{avg_score.round(3)}"
    
    puts "\n🏆 RESULTS BY TEST:"
    @results.each do |result|
      status = result[:comparison][:compatible] ? "✅ PASS" : "❌ FAIL"
      puts "  #{status} #{result[:name]} (Score: #{result[:comparison][:score].round(2)})"
    end
    
    puts "\n🎯 ASSESSMENT:"
    if avg_score >= 0.8
      puts "  🟢 EXCELLENT - Native parser shows high compatibility"
    elsif avg_score >= 0.6
      puts "  🟡 GOOD - Native parser shows reasonable compatibility"
    elsif avg_score >= 0.4
      puts "  🟠 FAIR - Native parser needs improvement"
    else
      puts "  🔴 POOR - Native parser requires significant work"
    end
    
    puts "\n📋 DETAILED RESULTS:"
    @results.each do |result|
      puts "\n  #{result[:name]}:"
      puts "    Ruby Success: #{result[:ruby_result][:success]}"
      puts "    Native Success: #{result[:native_result][:success]}"
      puts "    Ruby Nodes: #{result[:ruby_result][:node_count]}"
      puts "    Native Nodes: #{result[:native_result][:node_count]}"
      
      if !result[:ruby_result][:success]
        puts "    Ruby Error: #{result[:ruby_result][:error]}"
      end
      
      if !result[:native_result][:success]
        puts "    Native Error: #{result[:native_result][:error]}"
      end
    end
    
    # Save results
    save_results
  end

  def save_results
    report = {
      timestamp: Time.now,
      total_tests: @results.length,
      compatible_tests: @results.count { |r| r[:comparison][:compatible] },
      average_score: @results.map { |r| r[:comparison][:score] }.sum / @results.length,
      results: @results.map do |r|
        {
          name: r[:name],
          code: r[:code],
          ruby_success: r[:ruby_result][:success],
          native_success: r[:native_result][:success],
          ruby_nodes: r[:ruby_result][:node_count],
          native_nodes: r[:native_result][:node_count],
          compatibility_score: r[:comparison][:score],
          compatible: r[:comparison][:compatible]
        }
      end
    }
    
    File.write('simple_parser_test_results.json', JSON.pretty_generate(report))
    puts "\n💾 Results saved to simple_parser_test_results.json"
  end
end

# Run the test
if __FILE__ == $0
  test = SimpleParserTest.new
  test.run_tests
end