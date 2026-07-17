# PersistenceLayer: Durable storage and recovery for Patlang

class PersistenceLayer
  def initialize(config = {})
    @config = config
    @snapshots = {}
    @objects = {}
    @event_handlers = Hash.new { |h, k| h[k] = [] }
  end

  # Saves the current program state.
  def save_state(snapshot_name = nil)
    name = snapshot_name || "default"
    @snapshots[name] = :mock_state
    emit_event(:state_saved, name)
    true
  end

  # Loads a previously saved state.
  def load_state(snapshot_name = nil)
    name = snapshot_name || "default"
    raise ArgumentError, "Snapshot not found" unless @snapshots.key?(name)
    emit_event(:state_loaded, name)
    @snapshots[name]
  end

  # Persists an object to storage.
  def persist_object(obj, options = {})
    raise ArgumentError, "Object must respond to :id" unless obj.respond_to?(:id)
    @objects[obj.id] = obj
    emit_event(:object_persisted, obj.id)
    true
  end

  # Restores an object from storage.
  def restore_object(id, options = {})
    raise ArgumentError, "Object not found" unless @objects.key?(id)
    emit_event(:object_restored, id)
    @objects[id]
  end

  # Lists available state snapshots.
  def list_snapshots
    @snapshots.keys
  end

  # Updates persistence configuration.
  def configure(options)
    @config.merge!(options)
    emit_event(:config_updated, options)
    true
  end

  # Registers for persistence events.
  def on_event(event_type, &block)
    @event_handlers[event_type] << block if block_given?
  end

  private

  def emit_event(event_type, payload)
    @event_handlers[event_type].each { |handler| handler.call(payload) }
  end
end