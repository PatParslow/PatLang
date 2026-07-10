# Test suite for FFIBridge

require_relative '../src/FFIBridge'

def assert(cond, msg = "Assertion failed")
  raise msg unless cond
end

ffi = FFIBridge.new

# Test load_library
assert(ffi.load_library("libtest.so"), "Should load library")
# Test bind_function
assert(ffi.bind_function("add", "int(int, int)"), "Should bind function")
# Test call_function
assert(ffi.call_function("add", 1, 2) == :mock_result, "Should call function and return mock result")
# Test marshal_data
marshalled = ffi.marshal_data(42, "int")
assert(marshalled[:marshalled] == 42 && marshalled[:type] == "int", "Should marshal data")
# Test event registration and emission
event_triggered = false
ffi.on_event(:function_bound) { event_triggered = true }
ffi.bind_function("sub", "int(int, int)")
assert(event_triggered, "Event handler should be triggered")