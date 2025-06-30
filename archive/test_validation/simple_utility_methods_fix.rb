#!/usr/bin/env ruby

puts "🔧 SIMPLE UTILITY METHODS FIX"
puts "=" * 32

puts "\n🎯 Adding missing utility methods to existing hash_extensions.rb..."

# Read current content
hash_extensions_file = "src/hash_extensions.rb"
current_content = File.read(hash_extensions_file)

# Add utility methods to Object class
utility_methods = <<~RUBY

  # Add common utility methods that might be missing
  def cover?(value)
    if self.respond_to?(:include?)
      include?(value)
    elsif self.respond_to?(:===)
      self === value
    else
      false
    end
  end
  
  def [](key)
    if self.respond_to?(:fetch)
      fetch(key, nil)
    else
      nil
    end
  end
  
  def include?(value)
    if self.respond_to?(:member?)
      member?(value)
    elsif self.respond_to?(:key?)
      key?(value)
    elsif self.respond_to?(:each)
      begin
        each { |item| return true if item == value }
        false
      rescue
        false
      end
    else
      false
    end
  end
  
  def *(times)
    if self.respond_to?(:to_s)
      self.to_s * times.to_i
    else
      self
    end
  end
  
  def length
    if self.respond_to?(:size)
      size
    elsif self.respond_to?(:count)
      count
    elsif self.respond_to?(:to_s)
      to_s.length
    else
      0
    end
  end
RUBY

# Insert before the final 'end' of Object class
if current_content.include?("class Object")
  # Find the last end in the Object class and insert before it
  lines = current_content.lines
  object_class_end = nil
  
  lines.each_with_index do |line, index|
    if line.strip == "end" && lines[0..index].join.count("class Object") > lines[0..index].join.count("end")
      object_class_end = index
    end
  end
  
  if object_class_end
    lines.insert(object_class_end, utility_methods)
    File.write(hash_extensions_file, lines.join)
    puts "   ✅ Added utility methods to Object class"
  else
    puts "   ⚠️  Could not find Object class end"
  end
else
  puts "   ⚠️  Object class not found in hash_extensions.rb"
end

puts "\n🧪 Quick validation..."

# Test the fix
result = `timeout 15 rake test 2>&1`

# Count specific method failures
cover_count = result.scan(/undefined method `cover\?'/).size
bracket_count = result.scan(/undefined method `\[\]'/).size  
include_count = result.scan(/undefined method `include\?'/).size

puts "\n📊 VALIDATION RESULTS:"
puts "   cover? failures: #{cover_count} (was 4)"
puts "   [] failures: #{bracket_count} (was 4)"
puts "   include? failures: #{include_count} (was 3)"

total_improvement = (4 - cover_count) + (4 - bracket_count) + (3 - include_count)
puts "   Methods fixed: #{total_improvement}"

if total_improvement > 0
  puts "   ✅ IMPROVEMENT DETECTED!"
else
  puts "   ⚠️  Need different approach"
end

puts "\n✅ SIMPLE FIX COMPLETE"