#!/usr/bin/env ruby
# This script sets up a clean patlang-selfhost project by copying only the essential files
# It also includes basic dependency detection to ensure all required files are copied

require 'fileutils'
require 'pathname'
require 'set'

# Configuration
SOURCE_DIR = File.expand_path('e:/patlang')
TARGET_DIR = 'C:/patlang-selfhost'
ESSENTIAL_DIRS = [
  'patlang-selfhost',
  'bin',
]
ESSENTIAL_FILES = [
  'bin/patlang',
  'bin/patlang.patlang',
  'patlang-core/exceptions.rb',
  'native_evaluator/ruby_bridge.rb',
]

# List of directories to copy partially (we'll scan for dependencies)
SCAN_DIRS = [
  'patlang-core',
  'ruby-host',
  'native_evaluator',
]

# List of required files that we know we need (in addition to automatically detected ones)
ALWAYS_INCLUDE = [
  'patlang-core/lexer/lexer.rb',
  'patlang-core/parser/parser.rb',
  'patlang-core/evaluator/evaluator.rb',
]

# Create target directory
FileUtils.mkdir_p(TARGET_DIR)

# Copy essential directories
puts "Copying essential directories..."
ESSENTIAL_DIRS.each do |dir|
  source = File.join(SOURCE_DIR, dir)
  target = File.join(TARGET_DIR, dir)
  if File.directory?(source)
    puts " - #{dir}"
    FileUtils.mkdir_p(target)
    FileUtils.cp_r(Dir.glob(File.join(source, '*')), target)
  end
end

# Copy essential individual files
puts "Copying essential files..."
ESSENTIAL_FILES.each do |file|
  source = File.join(SOURCE_DIR, file)
  target = File.join(TARGET_DIR, file)
  if File.file?(source)
    puts " - #{file}"
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(source, target)
  else
    puts " - WARNING: #{file} not found"
  end
end

# Create list of files to scan for dependencies
files_to_check = ALWAYS_INCLUDE.map { |f| File.join(SOURCE_DIR, f) }
puts "\nAdded #{files_to_check.length} known required files to dependency list"

# Create a set to track which files we've already processed
processed_files = Set.new
copied_files = Set.new

# Function to recursively scan for dependencies
def scan_for_dependencies(file, source_dir, processed_files)
  return [] if processed_files.include?(file)
  
  dependencies = []
  processed_files.add(file)
  
  begin
    content = File.read(file)
    
    # Look for require statements
    content.scan(/require ['"](.+?)['"]/) do |match|
      dependency = match[0]
      # Convert to absolute path if it's a relative require
      if dependency.start_with?('./')
        dependency_path = File.expand_path(dependency, File.dirname(file))
        dependencies << dependency_path if File.exist?(dependency_path)
      end
    end
    
    # Look for require_relative statements
    content.scan(/require_relative ['"](.+?)['"]/) do |match|
      dependency = match[0]
      
      # Handle both with and without .rb extension
      possible_paths = [
        File.expand_path("#{dependency}.rb", File.dirname(file)),
        File.expand_path(dependency, File.dirname(file))
      ]
      
      possible_paths.each do |path|
        if File.exist?(path)
          dependencies << path
          break
        end
      end
    end
  rescue => e
    puts " - Error scanning #{file}: #{e.message}"
  end
  
  dependencies
end

# Process dependencies until we've checked all files
while !files_to_check.empty?
  current_file = files_to_check.pop
  next if processed_files.include?(current_file)
  
  # Find all dependencies
  dependencies = scan_for_dependencies(current_file, SOURCE_DIR, processed_files)
  
  # Add any new dependencies to our list
  files_to_check.concat(dependencies)
  
  # Mark this file for copying
  rel_path = Pathname.new(current_file).relative_path_from(Pathname.new(SOURCE_DIR)).to_s
  copied_files.add(rel_path)
end

# Copy all detected dependencies
puts "\nCopying detected dependencies..."
copied_files.each do |rel_path|
  source = File.join(SOURCE_DIR, rel_path)
  target = File.join(TARGET_DIR, rel_path)
  
  if File.file?(source)
    puts " - #{rel_path}"
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(source, target)
  end
end

# Create README
puts "\nCreating README file..."
readme_content = <<MARKDOWN
# Clean PaTLang Self-Hosting Project

This is a minimal clean project containing only the essential components
needed for the PaTLang self-hosting implementation.

## Running the project

```bash
cd #{TARGET_DIR}
ruby bin/patlang patlang-selfhost/tests/integration_suite.patlang
```

## Project Structure

- `bin/` - Main runner scripts
- `patlang-selfhost/` - Self-hosting implementation
  - `contracts/` - Contract definitions
  - `src/` - Source code for self-hosted implementation
  - `tests/` - Test suite
- `patlang-core/` - Minimal Ruby core components
- `ruby-host/` - Ruby host integration
- `native_evaluator/` - Native support bridge

MARKDOWN

File.write(File.join(TARGET_DIR, 'README.md'), readme_content)

# Create test script
puts "Creating test script..."
test_script = <<BATCH
@echo off
ruby bin/patlang patlang-selfhost/tests/integration_suite.patlang
BATCH

File.write(File.join(TARGET_DIR, 'run_tests.bat'), test_script)

puts "\nSetup complete! The clean project is now available at #{TARGET_DIR}"
puts "To run tests, navigate to #{TARGET_DIR} and execute run_tests.bat"
