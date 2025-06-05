#!/usr/bin/env ruby

# Fix Source File Require Paths
# Updates require_relative paths to source files after test reorganization

require 'fileutils'

class SourceRequiresFixer
  def initialize
    @base_path = File.dirname(__FILE__)
    @updates_performed = []
    @errors = []
  end

  def fix!
    puts "=== FIXING SOURCE FILE REQUIRE PATHS ==="
    puts "Updating source file requires for new test directory structure..."
    puts

    # Fix each category
    fix_infrastructure_requires
    fix_ruby_implementation_requires
    fix_patlang_language_requires

    # Report results
    report_results
  end

  private

  def fix_infrastructure_requires
    puts "Fixing Infrastructure test source requires..."
    fix_category_source_requires('infrastructure')
  end

  def fix_ruby_implementation_requires
    puts "Fixing Ruby Implementation test source requires..."
    fix_category_source_requires('ruby_implementation')
  end

  def fix_patlang_language_requires
    puts "Fixing Patlang Language test source requires..."
    fix_category_source_requires('patlang_language')
  end

  def fix_category_source_requires(category)
    category_dir = File.join(@base_path, category)
    return unless Dir.exist?(category_dir)

    Dir.glob(File.join(category_dir, 'test_*.rb')).each do |file_path|
      filename = File.basename(file_path)
      
      # Common require mappings for source files
      require_mappings = {
        # Source file requires - now need to go up two levels
        "require_relative '../src/" => "require_relative '../../src/",
        'require_relative "../src/' => 'require_relative "../../src/',
        
        # Common source files that might be required directly
        "require_relative 'src/" => "require_relative '../../src/",
        'require_relative "src/' => 'require_relative "../../src/',
        
        # Handle any remaining single level ups that should be double
        /require_relative ['"]\.\.\/([^\/'"]+)['"]/ => lambda { |match|
          file = match[1]
          # Check if this looks like a source file
          if file.end_with?('.rb') || %w[lexer parser evaluator patlang ast_nodes token].any? { |src| file.include?(src) }
            "require_relative '../../#{file}'"
          else
            match[0] # Leave unchanged
          end
        }
      }

      update_file_requires(file_path, filename, require_mappings)
    end
    puts
  end

  def update_file_requires(file_path, filename, mappings)
    begin
      content = File.read(file_path)
      original_content = content.dup
      updates_made = []

      mappings.each do |pattern, replacement|
        if pattern.is_a?(Regexp)
          # Handle regex replacements
          content.gsub!(pattern) do |match|
            if replacement.is_a?(Proc)
              result = replacement.call(Regexp.last_match)
              if result != match
                updates_made << "#{match} → #{result}"
              end
              result
            else
              updates_made << "#{match} → #{replacement}"
              replacement
            end
          end
        else
          # Handle string replacements
          if content.include?(pattern)
            content.gsub!(pattern, replacement)
            updates_made << "#{pattern} → #{replacement}"
          end
        end
      end

      if updates_made.any?
        File.write(file_path, content)
        @updates_performed << { 
          file: filename, 
          changes: updates_made 
        }
        puts "  ✓ Updated #{filename}"
        updates_made.each { |change| puts "    - #{change}" }
      else
        puts "  - No updates needed for #{filename}"
      end

    rescue => e
      @errors << { file: filename, error: e.message }
      puts "  ✗ Failed to update #{filename}: #{e.message}"
    end
  end

  def report_results
    puts "=== SOURCE REQUIRES FIX SUMMARY ==="
    puts "✓ Successfully updated #{@updates_performed.length} files"
    
    if @errors.any?
      puts "✗ #{@errors.length} errors occurred:"
      @errors.each do |error|
        puts "  - #{error[:file]}: #{error[:error]}"
      end
    end
    
    if @updates_performed.any?
      puts
      puts "Files updated:"
      @updates_performed.each do |update|
        puts "  #{update[:file]}:"
        update[:changes].each { |change| puts "    - #{change}" }
      end
    end
    
    puts
    puts "=== NEXT STEPS ==="
    puts "Now try running the tests again:"
    puts "  rake test:infrastructure"
    puts "  rake test:all"
  end
end

# Execute fix if script is run directly
if __FILE__ == $0
  fixer = SourceRequiresFixer.new
  fixer.fix!
end