# =============================================================================
# 🎯 Roadmap Feature - Planned for v0.7.0+ based on object model foundation
# =============================================================================
#
# ⚠️  IMPLEMENTATION STATUS: Control flow syntax not yet implemented
#     This example demonstrates the planned syntax for if/else and while loops
#     that will be built on top of our revolutionary v0.6.0 object model foundation.
#
# 🎯 To see working object model capabilities right now:
#     ruby examples/oo_event_system_demo_fixed.rb
#     ruby examples/network_transparent_demo_fixed.rb
#
# This file showcases the target architecture that will extend our
# 'everything is objects' foundation with natural control flow syntax.
#
# =============================================================================

# Control Flow Demo - showcasing if/else and while loops

# Simple conditional
x = 10
if x > 5 then
  result = 100
else
  result = 50
end

result

# While loop with accumulator
counter = 1
sum = 0
while counter <= 5 do
  sum = sum + counter
  counter = counter + 1
end

sum

# Nested control flow
i = 0
factorial = 1
while i < 4 do
  i = i + 1
  if i > 1 then
    factorial = factorial * i
  end
end

factorial