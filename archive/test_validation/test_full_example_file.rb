#!/usr/bin/env ruby

# Test the full example file to reproduce the infinite loop issue
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/ast_nodes'
require 'timeout'

def test_full_example_file
  puts "🔍 Testing full example file: examples/unified_reasoning_syntax_examples.patlang"
  
  # Read the example file
  source_code = File.read('examples/unified_reasoning_syntax_examples.patlang')
  
  puts "📄 File size: #{source_code.length} characters"
  puts "📄 Line count: #{source_code.lines.count} lines"
  
  begin
    # Timeout protection - 10 seconds max
    Timeout.timeout(10) do
      puts "🔹 Tokenizing full file..."
      lexer = Lexer.new(source_code)
      tokens = lexer.tokenize
      
      puts "🔹 Token count: #{tokens.length}"
      puts "🔹 First 10 tokens: #{tokens.first(10).map { |t| "#{t.type}:#{t.value}" }.join(' ')}"
      
      puts "🔹 Parsing full file..."
      parser = Parser.new(tokens)
      
      result = parser.parse
      
      puts "✅ SUCCESS: Parsed successfully - #{result.class.name}"
      
      # Check if it's a block with multiple statements
      if result.is_a?(BlockNode)
        puts "📊 Block contains #{result.statements.length} statements:"
        result.statements.each_with_index do |stmt, i|
          puts "  #{i+1}. #{stmt.class.name}"
        end
      end
    end
  rescue Timeout::Error => e
    puts "❌ TIMEOUT: Infinite loop detected after 10 seconds"
    
    # Try to identify the problematic line
    puts "\n🔍 Attempting to identify problematic section..."
    test_line_by_line(source_code)
    
  rescue => e
    puts "❌ ERROR: #{e.class.name} - #{e.message}"
    puts "  Backtrace:"
    e.backtrace.first(5).each { |line| puts "    #{line}" }
  end
end

def test_line_by_line(source_code)
  lines = source_code.lines
  
  puts "🔍 Testing line by line to isolate the issue..."
  
  lines.each_with_index do |line, index|
    line_num = index + 1
    line_content = line.strip
    
    # Skip empty lines and comments
    next if line_content.empty? || line_content.start_with?('#')
    
    puts "\n📍 Testing line #{line_num}: #{line_content}"
    
    begin
      Timeout.timeout(2) do
        lexer = Lexer.new(line_content)
        tokens = lexer.tokenize
        parser = Parser.new(tokens)
        result = parser.parse
        puts "  ✅ OK: #{result.class.name}"
      end
    rescue Timeout::Error
      puts "  ❌ TIMEOUT: Line #{line_num} causes infinite loop!"
      puts "  🚨 PROBLEMATIC LINE: #{line_content}"
      
      # Try to identify the specific tokens causing the issue
      puts "\n🔍 Analyzing problematic line tokens:"
      lexer = Lexer.new(line_content)
      tokens = lexer.tokenize
      puts "  Tokens: #{tokens.map { |t| "#{t.type}:#{t.value}" }.join(' ')}"
      
      break  # Stop at first problematic line
    rescue => e
      puts "  ⚠️  ERROR: #{e.class.name} - #{e.message}"
    end
  end
end

if __FILE__ == $0
  test_full_example_file
end