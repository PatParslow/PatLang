#!/usr/bin/env ruby

puts "🔧 Updating Require Paths After Migration"
puts "========================================"

# Define path mappings for the migration
PATH_MAPPINGS = {
  # Core language files moved from src/ to patlang-core/
  "require_relative '../patlang-core/lexer/lexer'" => "require_relative '../patlang-core/lexer/lexer'",
  "require_relative '../patlang-core/lexer/token'" => "require_relative '../patlang-core/lexer/token'",
  "require_relative '../patlang-core/parser/parser'" => "require_relative '../patlang-core/parser/parser'",
  "require_relative '../patlang-core/evaluator/evaluator'" => "require_relative '../patlang-core/evaluator/evaluator'",
  "require_relative '../patlang-core/exceptions'" => "require_relative '../patlang-core/exceptions'",
  
  # Relative paths within patlang-core need updating
  "require_relative '../ast/ast_nodes'" => "require_relative '../ast/ast_nodes'",
  "require_relative '../lexer/token'" => "require_relative '../lexer/token'",
  "require_relative '../lexer/lexer'" => "require_relative '../lexer/lexer'",
  "require_relative '../parser/parser'" => "require_relative '../parser/parser'",
  "require_relative '../evaluator/evaluator'" => "require_relative '../evaluator/evaluator'",
  "require_relative '../exceptions'" => "require_relative '../exceptions'",
  
  # Ruby host bootstrap paths
  "require_relative 'ruby-host/bootstrap/patlang'" => "require_relative 'ruby-host/bootstrap/patlang'",
  "require_relative 'ruby-host/bootstrap/hash_extensions'" => "require_relative 'ruby-host/bootstrap/hash_extensions'",
  
  # Directory-based requires within modules
  "require_relative '" => "require_relative '",
  "require_relative '" => "require_relative '",
  "require_relative '" => "require_relative '",
  "require_relative '" => "require_relative '",
  "require_relative '" => "require_relative '"
}

def update_file_requires(file_path)
  puts "  Updating: #{file_path}"
  
  begin
    content = File.read(file_path)
    original_content = content.dup
    
    # Apply path mappings
    PATH_MAPPINGS.each do |old_path, new_path|
      content.gsub!(old_path, new_path)
    end
    
    # Special handling for files within patlang-core subdirectories
    if file_path.include?('patlang-core/')
      # Update internal cross-module references
      content.gsub!(/require_relative ['"]\.\.\/src\/([^'"]+)['"]/) do |match|
        module_name = $1
        case module_name
        when /^lexer/
          "require_relative '../lexer/#{File.basename(module_name)}'"
        when /^parser/
          "require_relative '../parser/#{File.basename(module_name)}'"
        when /^evaluator/
          "require_relative '../evaluator/#{File.basename(module_name)}'"
        when /^reasoning/
          "require_relative '../reasoning/#{File.basename(module_name)}'"
        when /^object_model/
          "require_relative '../object_model/#{File.basename(module_name)}'"
        when /^ast/
          "require_relative '../ast/#{File.basename(module_name)}'"
        else
          "require_relative '../#{module_name}'"
        end
      end
    end
    
    # Only write if content changed
    if content != original_content
      File.write(file_path, content)
      puts "    ✅ Updated require paths"
    else
      puts "    ➡️  No changes needed"
    end
    
  rescue => e
    puts "    ❌ Error updating #{file_path}: #{e.message}"
  end
end

def update_requires_in_directory(directory)
  return unless Dir.exist?(directory)
  
  puts "📁 Processing directory: #{directory}"
  
  Dir.glob("#{directory}/**/*.rb").each do |file|
    update_file_requires(file)
  end
end

# Update require paths in all moved files
puts "\n🎯 Phase 1: Updating patlang-core files..."
update_requires_in_directory('patlang-core')

puts "\n🎯 Phase 2: Updating ruby-host files..."
update_requires_in_directory('ruby-host')

puts "\n🎯 Phase 3: Updating dev-tools files..."
update_requires_in_directory('dev-tools')

puts "\n🎯 Phase 4: Updating test files..."
update_requires_in_directory('test')

puts "\n🎯 Phase 5: Updating root-level scripts..."
# Update any root-level Ruby files that might reference the old paths
root_files = Dir.glob('*.rb')
root_files.each do |file|
  update_file_requires(file)
end

puts "\n✅ Require Path Update Complete!"
puts "=================================="
puts "Summary:"
puts "- Updated require paths in patlang-core/"
puts "- Updated require paths in ruby-host/"
puts "- Updated require paths in dev-tools/"
puts "- Updated require paths in test/"
puts "- Updated require paths in root scripts"
puts ""
puts "Next step: Test that files can be loaded correctly"