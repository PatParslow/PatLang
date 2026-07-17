# Test suite for ConcurrencyManager

require_relative '../src/ConcurrencyManager'

def assert(cond, msg = "Assertion failed")
  raise msg unless cond
end

cm = ConcurrencyManager.new

# Test spawn and join
result = []
t1 = cm.spawn { result << 1 }
t2 = cm.spawn { result << 2 }
cm.join(t1)
cm.join(t2)
assert(result.sort == [1,2], "Threads should execute and join")

# Test lock
locked = false
cm.lock("res") { locked = true }
assert(locked, "Lock should execute block")

# Test semaphore
sem = cm.semaphore("sem1", 2)
assert(sem.is_a?(ConcurrencyManager::Semaphore), "Should create semaphore")

# Test barrier
bar = cm.barrier(2)
assert(bar.is_a?(ConcurrencyManager::Barrier), "Should create barrier")

# Test atomic
atomic_result = nil
cm.atomic { atomic_result = 42 }
assert(atomic_result == 42, "Atomic should execute block")

# Test event registration and emission
event_triggered = false
cm.on_event(:thread_spawned) { event_triggered = true }
cm.spawn {}
assert(event_triggered, "Event handler should be triggered")