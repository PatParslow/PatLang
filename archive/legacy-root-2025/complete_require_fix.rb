#!/usr/bin/env ruby

puts "🔧 Complete Require Path Fix"
puts "============================"

# Define systematic fixes for all modules
fixes = {
  'patlang-core/evaluator/arithmetic_evaluator.rb' => [
    [/require_relative ['"]\.\.\/ast_nodes['"]/, "require_relative '../ast/ast_nodes'"]
  ],
  'patlang-core/evaluator/function_evaluator.rb' => [
    [/require_relative ['"]\.\.\/ast_nodes['"]/, "require_relative '../ast/ast_nodes'"]
  ],
  'patlang-core/evaluator/object_evaluator.rb' => [
    [/require_relative ['"]\.\.\/ast_nodes['"]/, "require_relative '../ast/ast_nodes'"]
  ],
  'patlang-core/evaluator/reasoning_evaluator.rb' => [
    [/require_relative ['"]\.\.\/ast_nodes['"]/, "require_relative '../ast/ast_nodes'"]
  ],
  'patlang-core/evaluator/scope_manager.rb' => [
    [/require_relative ['"]\.\.\/ast_nodes['"]/, "require_relative '../ast/ast_nodes'"]
  ],
  'patlang-core/evaluator/string_evaluator.rb' => [
    [/require_relative ['"]\.\.\/ast_nodes['"]/, "require_relative '../ast/ast_nodes'"]
  ],
}

def apply_fixes_to_file(file_path, fixes_list)
  return unless File.exist?(file_path)
  
  puts "  🔧 Fixing: #{file_path}"
  
  begin
    content = File.read(file_path)
    original = content.dup
    
    fixes_list.each do |pattern, replacement|
      content.gsub!(pattern, replacement)
    end
    
    if content != original
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
fixes.each do |file_path, fixes_list|
  apply_fixes_to_file(file_path, fixes_list)
end

puts "\n✅ Complete require path fixes applied!"
puts "Testing bootstrap..."

# Test bootstrap
puts "\n🧪 Testing Bootstrap..."
success = system('ruby ruby-host/bootstrap/patlang_bootstrap.rb')

if success
  puts "\n🎉 SUCCESS! Migration completed successfully!"
else
  puts "\n⚠️  Still some issues to resolve..."
end