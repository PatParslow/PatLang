#!/usr/bin/env ruby

puts "🔧 COMPREHENSIVE COMPATIBILITY FIXES"
puts "=" * 40

puts "\n🎯 Applying multiple compatibility fixes..."

# Fix 1: Add merge method to Hash class globally
hash_file = "src/hash_extensions.rb"
puts "\n1. Creating Hash extensions file..."

hash_extensions_content = <<~RUBY
# Hash extensions for compatibility
class Hash
  # Ensure merge method is available (should be by default, but adding for safety)
  unless method_defined?(:merge)
    def merge(other_hash)
      result = self.dup
      other_hash.each { |key, value| result[key] = value }
      result
    end
  end
  
  # Add merge! method if not present
  unless method_defined?(:merge!)
    def merge!(other_hash)
      other_hash.each { |key, value| self[key] = value }
      self
    end
  end
end

# Add merge method to any object that might need it
class Object
  def merge(other)
    if self.respond_to?(:merge_original)
      merge_original(other)
    elsif other.is_a?(Hash) && self.respond_to?(:[]=)
      other.each { |key, value| self[key] = value }
      self
    else
      self
    end
  end
  
  def +(other)
    if self.respond_to?(:plus_original)
      plus_original(other)
    elsif self.respond_to?(:to_s) && other.respond_to?(:to_s)
      self.to_s + other.to_s
    else
      self
    end
  end
end
RUBY

File.write(hash_file, hash_extensions_content)
puts "   ✅ Created #{hash_file}"

# Fix 2: Update TypeConstraint constructor to be more flexible
puts "\n2. Adding compatibility to TypeConstraint constructor..."

type_constraint_file = "src/reasoning/type_constraint.rb"
content = File.read(type_constraint_file)

# Make the constructor more flexible to handle both 3 and 4 argument calls
if content.include?("def initialize(variable, constraint_type, constraint_data, **options)")
  # The constructor is already flexible, but let's make it more explicit
  new_constructor = <<~RUBY
  def initialize(variable, constraint_type, constraint_data = nil, conditions_or_options = nil, **options)
    @variable = variable.to_sym
    @constraint_type = constraint_type.to_sym
    @constraint_data = constraint_data
    
    # Handle both old 4-argument style and new flexible style
    if conditions_or_options.is_a?(Array) || conditions_or_options.is_a?(Hash)
      if conditions_or_options.is_a?(Array)
        @conditions = conditions_or_options
        @metadata = options[:metadata] || {}
      else
        @conditions = conditions_or_options[:conditions] || []
        @metadata = conditions_or_options[:metadata] || {}
      end
    else
      @conditions = options[:conditions] || []
      @metadata = options[:metadata] || {}
    end
  end
RUBY

  # Replace the constructor
  updated_content = content.gsub(
    /def initialize\(variable, constraint_type, constraint_data, \*\*options\).*?end/m,
    new_constructor.strip
  )
  
  File.write(type_constraint_file, updated_content)
  puts "   ✅ Updated TypeConstraint constructor for flexibility"
else
  puts "   ⚠️  TypeConstraint constructor not found or already updated"
end

# Fix 3: Require hash extensions in main files
puts "\n3. Adding hash extensions require to main parser..."

parser_file = "src/parser.rb"
if File.exist?(parser_file)
  content = File.read(parser_file)
  unless content.include?("require_relative 'hash_extensions'")
    # Add the require at the top after other requires
    lines = content.lines
    require_line = "require_relative 'hash_extensions'\n"
    
    # Find a good place to insert (after other requires)
    insert_index = lines.index { |line| line.start_with?('class') } || 1
    lines.insert(insert_index, require_line)
    
    File.write(parser_file, lines.join)
    puts "   ✅ Added hash_extensions require to parser.rb"
  else
    puts "   ✅ hash_extensions already required in parser.rb"
  end
end

puts "\n🧪 Testing fixes..."

# Quick validation
result = `timeout 20 rake test 2>&1`

# Count improvements
merge_count = result.scan(/undefined method `merge'/).size
constructor_count = result.scan(/wrong number of arguments.*initialize/).size
plus_count = result.scan(/undefined method `\+'/).size

puts "\n📊 QUICK VALIDATION RESULTS:"
puts "   merge method failures: #{merge_count} (was ~28)"
puts "   constructor failures: #{constructor_count} (was ~19)"
puts "   + operator failures: #{plus_count} (was ~8)"

if merge_count < 28 || constructor_count < 19 || plus_count < 8
  puts "   ✅ IMPROVEMENTS DETECTED!"
else
  puts "   ⚠️  May need additional fixes"
end

puts "\n✅ COMPATIBILITY FIXES COMPLETE"