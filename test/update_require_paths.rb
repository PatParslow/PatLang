#!/usr/bin/env ruby

# Test Suite Require Path Update Script
# Updates require paths in moved test files to work with new directory structure

require 'fileutils'

class RequirePathUpdater
  def initialize
    @base_path = File.dirname(__FILE__)
    @updates_performed = []
    @errors = []
  end

  def update!
    puts "=== UPDATING REQUIRE PATHS ==="
    puts "Updating require statements for new directory structure..."
    puts

    # Update each category
    update_infrastructure_requires
    update_ruby_implementation_requires
    update_patlang_language_requires
    update_helper_requires

    # Report results
    report_results
  end

  private

  def update_infrastructure_requires
    puts "Updating Infrastructure test requires..."
    update_category_requires('infrastructure', '../helpers/test_helper')
  end

  def update_ruby_implementation_requires
    puts "Updating Ruby Implementation test requires..."
    update_category_requires('ruby_implementation', '../helpers/test_helper')
  end

  def update_patlang_language_requires
    puts "Updating Patlang Language test requires..."
    update_category_requires('patlang_language', '../helpers/test_helper')
  end

  def update_helper_requires
    puts "Updating helper requires..."
    # test_helper.rb now needs to require from correct paths
    helper_file = File.join(@base_path, 'helpers', 'test_helper.rb')
    if File.exist?(helper_file)
      update_file_requires(helper_file, 'test_helper.rb', {
        # No changes needed for SimpleCov setup, it works from any location
      })
    end
  end

  def update_category_requires(category, helper_path)
    category_dir = File.join(@base_path, category)
    return unless Dir.exist?(category_dir)

    Dir.glob(File.join(category_dir, 'test_*.rb')).each do |file_path|
      filename = File.basename(file_path)
      
      require_mappings = {
        "require_relative 'test_helper'" => "require_relative '#{helper_path}'",
        'require_relative "test_helper"' => "require_relative '#{helper_path}'",
        "require 'test_helper'" => "require_relative '#{helper_path}'"
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

      mappings.each do |old_require, new_require|
        if content.gsub!(old_require, new_require)
          updates_made << "#{old_require} → #{new_require}"
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
    puts "=== REQUIRE PATH UPDATE SUMMARY ==="
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
    puts "1. Create category-specific test runners"
    puts "2. Configure SimpleCov for category coverage"
    puts "3. Verify all tests still pass"
    puts
    puts "Run tests to verify the migration: ruby test/run_category_tests.rb"
  end
end

# Execute update if script is run directly
if __FILE__ == $0
  updater = RequirePathUpdater.new
  updater.update!
end