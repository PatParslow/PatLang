# Test suite for PersistenceLayer

require_relative '../src/PersistenceLayer'

def assert(cond, msg = "Assertion failed")
  raise msg unless cond
end

pl = PersistenceLayer.new

# Test save_state and list_snapshots
assert(pl.save_state("snap1"), "Should save state")
assert(pl.list_snapshots.include?("snap1"), "Snapshot should be listed")

# Test load_state
assert(pl.load_state("snap1") == :mock_state, "Should load saved state")

# Test persist_object and restore_object
obj = Struct.new(:id, :val).new("obj1", 123)
assert(pl.persist_object(obj), "Should persist object")
assert(pl.restore_object("obj1") == obj, "Should restore object")

# Test configure
assert(pl.configure({backend: "mock"}), "Should update config")

# Test event registration and emission
event_triggered = false
pl.on_event(:object_persisted) { event_triggered = true }
pl.persist_object(Struct.new(:id).new("obj2"))
assert(event_triggered, "Event handler should be triggered")