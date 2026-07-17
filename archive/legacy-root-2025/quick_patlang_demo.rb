#!/usr/bin/env ruby

# =============================================================================
# QUICK PATLANG DEMONSTRATION SCRIPT
# =============================================================================
# 
# A simple, focused demonstration of PaTLang's most impressive working features.
# Perfect for quick showcases, presentations, and "wow factor" demonstrations.
#
# Usage: ruby quick_patlang_demo.rb
#
# =============================================================================

require_relative 'patlang-core/lexer/lexer'
require_relative 'patlang-core/parser/parser'
require_relative 'patlang-core/evaluator/evaluator'

class QuickPaTLangDemo
  def initialize
    @evaluator = Evaluator.new
    puts "🎉 QUICK PATLANG DEMONSTRATION"
    puts "=" * 40
    puts "Showcasing PaTLang's most impressive features!\n"
  end
  
  def run_demo
    puts "🚀 BREAKTHROUGH: Natural Language Functions"
    puts "-" * 40
    
    # The killer feature - natural language functions
    demo_code([
      {
        title: "Natural Function Definition",
        code: 'make a function called hello { return "Hello, PaTLang!" }; call hello',
        wow: "Functions defined in plain English!"
      },
      {
        title: "Function with Parameters", 
        code: 'make a function called add takes: x, y { return x + y }; call add with 15, 27',
        wow: "Parameter passing that reads like English!"
      }
    ])
    
    puts "\n✨ INTELLIGENT STRING OPERATIONS"
    puts "-" * 40
    
    demo_code([
      {
        title: "Multi-String Concatenation",
        code: '"Hello" + " " + "Beautiful" + " " + "World!"',
        wow: "Seamless string building!"
      },
      {
        title: "String-Number Integration",
        code: '"Total: " + (10 * 5) + " items"',
        wow: "Automatic type conversion!"
      }
    ])
    
    puts "\n🧠 SMART CONTROL FLOW"
    puts "-" * 40
    
    demo_code([
      {
        title: "Nested Conditionals",
        code: 'if 10 > 5 then if 3 < 7 then "Both true!" else "Mixed" end else "False" end',
        wow: "Complex logic made simple!"
      },
      {
        title: "Real-World Example",
        code: 'age = 25; if age >= 18 then "Adult" else "Minor" end',
        wow: "Natural decision making!"
      }
    ])
    
    puts "\n🔢 MATHEMATICAL PRECISION"
    puts "-" * 40
    
    demo_code([
      {
        title: "Complex Expression",
        code: '((5 + 3) * 2 - 1) / 3',
        wow: "Perfect operator precedence!"
      },
      {
        title: "Mixed Numbers",
        code: '42 + 3.14159',
        wow: "Seamless integer/float handling!"
      }
    ])
    
    puts "\n🎯 FINAL SHOWCASE"
    puts "-" * 40
    
    demo_code([
      {
        title: "Everything Together",
        code: 'make a function called analyze takes: score { if score >= 90 then "Excellent: " + score else "Good: " + score end }; call analyze with 95',
        wow: "Functions + logic + strings + math = POWERFUL!"
      }
    ])
    
    puts "\n" + "=" * 40
    puts "🎉 DEMO COMPLETE!"
    puts "PaTLang: Programming that reads like English!"
    puts "=" * 40
  end
  
  private
  
  def demo_code(examples)
    examples.each do |example|
      puts "  💡 #{example[:title]}"
      puts "     Code: #{example[:code]}"
      
      begin
        result = evaluate(example[:code])
        puts "     ✅ Result: #{result}"
        puts "     🌟 #{example[:wow]}"
      rescue => e
        puts "     ❌ Error: #{e.message}"
      end
      
      puts
    end
  end
  
  def evaluate(code)
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    @evaluator.evaluate(ast)
  end
end

# Run the demo
if __FILE__ == $0
  demo = QuickPaTLangDemo.new
  demo.run_demo
end