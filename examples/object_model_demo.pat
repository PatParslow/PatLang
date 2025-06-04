# =============================================================================
# 🚧 Foundation Ready - Object model supports this, integration in progress
# =============================================================================
#
# ✅ IMPLEMENTATION STATUS: Revolutionary object model foundation EXISTS
#     This example demonstrates capabilities supported by our v0.6.0 object model.
#     The underlying architecture is complete and ready for evaluator integration.
#
# 🎯 To see working object model capabilities right now:
#     ruby examples/oo_event_system_demo_fixed.rb
#     ruby examples/network_transparent_demo_fixed.rb
#
# This file showcases the target syntax that will be enabled when Phase 2
# evaluator integration connects native Patlang parsing to our revolutionary
# 'everything is objects' foundation with built-in events and message passing.
#
# =============================================================================

# Patlang Object Model Demonstration
# This file demonstrates the core object model capabilities
# when object mode is enabled in the evaluator

# Basic arithmetic that will create objects
x = 5 + 3
y = x * 2

# String operations that will create objects  
greeting = "Hello"
name = "World"
message = greeting + " " + name

# Boolean operations that will create objects
is_positive = x > 0
is_even = y % 2 == 0

# Control flow with objects
if is_positive then
  result = "positive number"
else
  result = "not positive"
end

# Function definition and call with objects
make function double(n) {
  return n * 2
}

doubled = call double(x)