#!/usr/bin/env ruby

puts "🔧 Fixing Remaining Require Path Issues"
puts "======================================"

# Fix specific require path issues found during testing
fixes = [
  # Fix expression_parser.rb
  {
    file: 'patlang-core/parser/expression_parser.rb',
    pattern: /require_relative ['"]\.\.\/ast_nodes['"]/,
    replacement: "require_relative '../ast/ast_nodes'"
  },
  {
    file: 'patlang-core/parser/expression_parser.rb',
    pattern: /require_relative ['"]\.\.\/token['"]/,
    replacement: "require_relative '../lexer/token'"
  },
  
  # Fix function_parser.rb
  {
    file: 'patlang-core/parser/function_parser.rb',
    pattern: /require_relative ['"]\.\.\/ast_nodes['"]/,
    replacement: "require_relative '../ast/ast_nodes'"
  },
  {
    file: 'patlang-core/parser/function_parser.rb',
    pattern: /require_relative ['"]\.\.\/token['"]/,
    replacement: "require_relative '../lexer/token'"
  },
  
  # Fix control_flow_parser.rb
  {
    file: 'patlang-core/parser/control_flow_parser.rb',
    pattern: /require_relative ['"]\.\.\/ast_nodes['"]/,
    replacement: "require_relative '../ast/ast_nodes'"
  },
  {
    file: 'patlang-core/parser/control_flow_parser.rb',
    pattern: /require_relative ['"]\.\.\/token['"]/,
    replacement: "require_relative '../lexer/token'"
  },
  
  # Fix type_constraint_parser.rb
  {
    file: 'patlang-core/parser/type_constraint_parser.rb',
    pattern: /require_relative ['"]\.\.\/ast_nodes['"]/,
    replacement: "require_relative '../ast/ast_nodes'"
  },
  {
    file: 'patlang-core/parser/type_constraint_parser.rb',
    pattern: /require_relative ['"]\.\.\/token['"]/,
    replacement: "require_relative '../lexer/token'"
  },
  
  # Fix reasoning_parser_extensions.rb
  {
    file: 'patlang-core/parser/reasoning_parser_extensions.rb',
    pattern: /require_relative ['"]\.\.\/ast_nodes['"]/,
    replacement: "require_relative '../ast/ast_nodes'"
  },
  {
    file: 'patlang-core/parser/reasoning_parser_extensions.rb',
    pattern: /require_relative ['"]\.\.\/token['"]/,
    replacement: "require_relative '../lexer/token'"
  },
  
  # Fix evaluator files
  {
    file: 'patlang-core/evaluator/evaluator.rb',
    pattern: /require_relative ['"]\.\.\/ast_nodes['"]/,
    replacement: "require_relative '../ast/ast_nodes'"
  },
  {
    file: 'patlang-core/evaluator/evaluator.rb',
    pattern: /require_relative ['"]\.\.\/parser['"]/,
    replacement: "require_relative '../parser/parser'"
  },
  {
    file: 'patlang-core/evaluator/evaluator.rb',
    pattern: /require_relative ['"]\.\.\/lexer['"]/,
    replacement: "require_relative '../lexer/lexer'"
  },
  {
    file: 'patlang-core/evaluator/evaluator.rb',
    pattern: /require_relative ['"]evaluator\/([^'"]+)['"]/,
    replacement: "require_relative '\\1'"
  },
  
  # Fix lexer files
  {
    file: 'patlang-core/lexer/lexer.rb',
    pattern: /require_relative ['"]token['"]/,
    replacement: "require_relative 'token'"
  },
  {
    file: 'patlang-core/lexer/ambiguous_token.rb',
    pattern: /require_relative ['"]token['"]/,
    replacement: "require_relative 'token'"
  }
]

def apply_fix(fix)
  file_path = fix[:file]
  
  unless File.exist?(file_path)
    puts "  ⚠️  File not found: #{file_path}"
    return
  end
  
  puts "  🔧 Fixing: #{file_path}"
  
  begin
    content = File.read(file_path)
    original_content = content.dup
    
    if fix[:pattern].is_a?(Regexp)
      content.gsub!(fix[:pattern], fix[:replacement])
    else
      content.gsub!(fix[:pattern], fix[:replacement])
    end
    
    if content != original_content
      File.write(file_path, content)
      puts "    ✅ Updated"
    else
      puts "    ➡️  No changes needed"
    end
    
  rescue => e
    puts "    ❌ Error: #{e.message}"
  end
end

# Apply all fixes
fixes.each { |fix| apply_fix(fix) }

puts "\n✅ Require Path Fixes Complete!"
puts "Now testing bootstrap..."

# Test the bootstrap
puts "\n🧪 Testing Bootstrap..."
system('ruby ruby-host/bootstrap/patlang_bootstrap.rb')