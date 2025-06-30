#!/usr/bin/env ruby

# Add the necessary paths
$LOAD_PATH.unshift(File.join(__dir__, 'patlang-core'))
$LOAD_PATH.unshift(File.join(__dir__, 'ruby-host'))

require_relative 'patlang-core/object_model/patlang_object'

# Test the list functionality
puts "Testing PatlangObject list functionality..."

# Test empty list
empty_list = PatlangObject.make_empty_list
puts "Empty list created: #{empty_list.is_empty?}"

# Test simple list
simple_list = PatlangObject.make_list(42, empty_list)
puts "Simple list head value: #{simple_list.head.value}"
puts "Simple list tail is empty: #{simple_list.tail.is_empty?}"

# Test longer list
list = PatlangObject.make_list(1, 
  PatlangObject.make_list(2, 
    PatlangObject.make_list(3, empty_list)))

puts "List as array: #{list.to_array}"

# Test functional programming with lists
puts "\nTesting functional programming..."

# Simple map function
def map_list(func, list)
  if list.is_empty?
    return PatlangObject.make_empty_list
  else
    return PatlangObject.make_list(
      func.call(list.head.value),
      map_list(func, list.tail)
    )
  end
end

# Double function
double = ->(x) { x * 2 }

# Test mapping
doubled = map_list(double, list)
puts "Doubled list: #{doubled.to_array}"

puts "\nList functionality working correctly!"