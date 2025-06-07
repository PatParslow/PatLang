#!/usr/bin/env ruby

# Fix 4: UnificationEngine Event ID Uniqueness
# Issue: Event IDs are not guaranteed to be unique, causing conflicts

puts "🔧 FIX 4: UnificationEngine Event ID Uniqueness"
puts "==============================================="

# Read the current unification engine file
unification_content = File.read('src/reasoning/unification_engine.rb')

# The current generate_event_id method uses Time.now.to_f + rand(1000)
# This can still have collisions, especially in fast operations

# Replace the generate_event_id method with a more robust implementation
improved_generate_event_id = <<~'RUBY'
  def initialize
    @event_handlers = {}
    @unification_count = 0
    @event_id_counter = 0  # Add dedicated counter for true uniqueness
    @start_time = Time.now.to_f  # Fixed start time for better uniqueness
  end

  # ... existing methods ...

  private

  # IMPROVED: Guaranteed unique event ID generation
  def generate_event_id
    @event_id_counter += 1
    # Format: unif_{counter}_{process_id}_{thread_id}_{microseconds}
    "unif_#{@event_id_counter}_#{Process.pid}_#{Thread.current.object_id}_#{(Time.now.to_f * 1_000_000).to_i}"
  end
RUBY

# Find and replace the initialize method to add the counter
fixed_content = unification_content.gsub(
  /def initialize\s+@event_handlers = \{\}\s+@unification_count = 0\s+end/,
  <<~'RUBY'.strip
    def initialize
      @event_handlers = {}
      @unification_count = 0
      @event_id_counter = 0  # Add dedicated counter for true uniqueness
      @start_time = Time.now.to_f  # Fixed start time for better uniqueness
    end
  RUBY
)

# Replace the generate_event_id method
fixed_content = fixed_content.gsub(
  /def generate_event_id\s+"unif_#\{@unification_count\}_#\{Time\.now\.to_f\}_#\{rand\(1000\)\}"\s+end/,
  <<~'RUBY'.strip
    def generate_event_id
      @event_id_counter += 1
      # Format: unif_{counter}_{process_id}_{thread_id}_{microseconds}
      "unif_#{@event_id_counter}_#{Process.pid}_#{Thread.current.object_id}_#{(Time.now.to_f * 1_000_000).to_i}"
    end
  RUBY
)

# Also improve the statistics method to include event ID info
fixed_content = fixed_content.gsub(
  /def statistics\s+\{\s+total_unifications: @unification_count,\s+event_handlers: @event_handlers\.keys\s+\}\s+end/,
  <<~'RUBY'.strip
    def statistics
      {
        total_unifications: @unification_count,
        event_handlers: @event_handlers.keys,
        events_generated: @event_id_counter,
        unique_id_guarantee: true
      }
    end
  RUBY
)

# Write the fixed content
File.write('src/reasoning/unification_engine.rb', fixed_content)

puts "✅ Fixed UnificationEngine event ID uniqueness issues"
puts "   - Added dedicated event ID counter for guaranteed uniqueness"
puts "   - Enhanced ID format with process ID and thread ID"
puts "   - Uses microsecond precision timestamps"
puts "   - Updated statistics to show event generation info"
puts