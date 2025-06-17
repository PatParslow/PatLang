#!/usr/bin/env ruby

# Verbose execution debugger for the reasoning syntax examples
# This will show exactly where the execution fails

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/ast_nodes'
require_relative 'src/evaluator'

def debug_verbose_execution
  filename = 'examples/unified_reasoning_syntax_examples.patlang'
  
  puts "🔍 VERBOSE EXECUTION DEBUGGING"
  puts "=" * 60
  puts "File: #{filename}"
  puts "Size: #{File.size(filename)} bytes"
  puts

  begin
    puts "📖 Step 1: Reading file content..."
    content = File.read(filename)
    puts "✅ File read successfully (#{content.length} characters)"
    puts

    puts "🔤 Step 2: Tokenizing..."
    lexer = Lexer.new(content)
    tokens = lexer.tokenize
    puts "✅ Tokenization completed (#{tokens.length} tokens)"
    puts "First 10 tokens: #{tokens.first(10).map { |t| "#{t.type}:#{t.value}" }.join(' ')}"
    puts

    puts "🌳 Step 3: Parsing..."
    parser = Parser.new(tokens)
    ast = parser.parse
    puts "✅ Parsing completed"
    puts "AST type: #{ast.class.name}"
    if ast.is_a?(BlockNode)
      puts "Block contains #{ast.statements.length} statements"
      puts "Statement types: #{ast.statements.map(&:class).map(&:name).uniq.join(', ')}"
    end
    puts

    puts "⚡ Step 4: Creating evaluator..."
    evaluator = Evaluator.new
    puts "✅ Evaluator created"
    puts

    puts "🧮 Step 5: Beginning evaluation..."
    puts "  This is where issues likely occur - monitoring each statement..."
    
    if ast.is_a?(BlockNode)
      ast.statements.each_with_index do |stmt, index|
        puts "  📍 Evaluating statement #{index + 1}/#{ast.statements.length}: #{stmt.class.name}"
        begin
          result = evaluator.evaluate(stmt)
          puts "  ✅ Statement #{index + 1} completed: #{result.class.name rescue 'nil'}"
        rescue => e
          puts "  ❌ Statement #{index + 1} FAILED: #{e.class.name} - #{e.message}"
          puts "  📍 This statement caused the failure: #{stmt.class.name}"
          puts "  🔍 Statement details: #{stmt.inspect.slice(0, 200)}"
          puts "  📚 Backtrace (first 5 lines):"
          e.backtrace.first(5).each { |line| puts "    #{line}" }
          raise e  # Re-raise to stop execution
        end
      end
    else
      puts "  📍 Evaluating single AST node: #{ast.class.name}"
      result = evaluator.evaluate(ast)
      puts "  ✅ Single AST evaluation completed: #{result.class.name rescue 'nil'}"
    end

    puts "🎉 Step 6: Evaluation completed successfully!"
    puts "No errors detected in verbose execution."

  rescue => e
    puts "💥 EXECUTION FAILED"
    puts "Error type: #{e.class.name}"
    puts "Error message: #{e.message}"
    puts "Location: #{e.backtrace.first}"
    puts
    puts "🔍 DETAILED BACKTRACE:"
    e.backtrace.each { |line| puts "  #{line}" }
    
    exit 1
  end
end

if __FILE__ == $0
  debug_verbose_execution
end