#!/usr/bin/env ruby

# Debug script to understand why .patlang file execution fails

require_relative 'src/patlang'

def test_small_patlang_snippet
  puts "🔍 DEBUGGING PATLANG EXECUTION"
  puts "=" * 50
  
  # Test 1: Simple expression
  puts "\n📝 Test 1: Simple arithmetic"
  begin
    result = Patlang.evaluate("2 + 3")
    puts "✅ Success: #{result}"
  rescue => e
    puts "❌ Failed: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  end
  
  # Test 2: Simple constraint (from unified reasoning syntax)
  puts "\n📝 Test 2: Type constraint syntax"
  begin
    result = Patlang.evaluate("constrain x :: Number")
    puts "✅ Success: #{result}"
  rescue => e
    puts "❌ Failed: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  end
  
  # Test 3: Goal declaration
  puts "\n📝 Test 3: Goal declaration syntax"
  begin
    result = Patlang.evaluate("goal test_goal { postcondition: result > 0 }")
    puts "✅ Success: #{result}"
  rescue => e
    puts "❌ Failed: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  end
  
  # Test 4: Reasoning mode
  puts "\n📝 Test 4: Reasoning mode syntax"
  begin
    result = Patlang.evaluate("reasoning mode on")
    puts "✅ Success: #{result}"
  rescue => e
    puts "❌ Failed: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  end
  
  # Test 5: First few lines of the actual file
  puts "\n📝 Test 5: File parsing (first few lines)"
  begin
    content = "# Unified Reasoning Syntax Examples for PATLANG\nconstrain x :: Number"
    result = Patlang.evaluate(content)
    puts "✅ Success: #{result}"
  rescue => e
    puts "❌ Failed: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  end
end

def test_file_execution_step_by_step
  puts "\n🔧 STEP-BY-STEP FILE PARSING"
  puts "=" * 50
  
  filename = "examples/unified_reasoning_syntax_examples.patlang"
  
  unless File.exist?(filename)
    puts "❌ File not found: #{filename}"
    return
  end
  
  content = File.read(filename)
  puts "📄 File size: #{content.length} characters"
  puts "📄 File lines: #{content.lines.count}"
  
  # Test lexing
  puts "\n🔤 Testing Lexer..."
  begin
    require_relative 'src/lexer'
    lexer = Lexer.new(content)
    tokens = lexer.tokenize
    puts "✅ Lexer success: #{tokens.length} tokens generated"
  rescue => e
    puts "❌ Lexer failed: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
    return
  end
  
  # Test parsing
  puts "\n🌳 Testing Parser..."
  begin
    require_relative 'src/parser'
    parser = Parser.new(tokens)
    ast = parser.parse
    puts "✅ Parser success: AST generated"
  rescue => e
    puts "❌ Parser failed: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
    return
  end
  
  # Test evaluation
  puts "\n⚙️  Testing Evaluator..."
  begin
    require_relative 'src/evaluator'
    evaluator = Evaluator.new
    result = evaluator.evaluate(ast)
    puts "✅ Evaluator success: #{result}"
  rescue => e
    puts "❌ Evaluator failed: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  end
end

def test_line_by_line_parsing
  puts "\n📋 LINE-BY-LINE PARSING TEST"
  puts "=" * 50
  
  filename = "examples/unified_reasoning_syntax_examples.patlang"
  content = File.read(filename)
  
  lines = content.lines
  lines.each_with_index do |line, index|
    line = line.strip
    next if line.empty? || line.start_with?('#')
    
    puts "\n📝 Line #{index + 1}: #{line[0..60]}#{line.length > 60 ? '...' : ''}"
    
    begin
      result = Patlang.evaluate(line)
      puts "   ✅ Success: #{result}"
    rescue => e
      puts "   ❌ Failed: #{e.message.split("\n").first}"
    end
    
    # Stop after first 10 non-comment lines to avoid overwhelming output
    break if index > 50
  end
end

if __FILE__ == $0
  test_small_patlang_snippet
  test_file_execution_step_by_step
  test_line_by_line_parsing
end