# ConcurrencyManager: Concurrency primitives and coordination for Patlang

class ConcurrencyManager
  def initialize(config = {})
    @config = config
    @threads = []
    @locks = Hash.new { |h, k| h[k] = Mutex.new }
    @semaphores = {}
    @barriers = {}
    @event_handlers = Hash.new { |h, k| h[k] = [] }
  end

  # Spawns a new thread or task to execute a block.
  def spawn(&block)
    raise ArgumentError, "Block required" unless block_given?
    t = Thread.new(&block)
    @threads << t
    emit_event(:thread_spawned, t)
    t
  end

  # Waits for a thread or task to complete.
  def join(thread_or_task)
    raise ArgumentError, "Argument must be a Thread" unless thread_or_task.is_a?(Thread)
    thread_or_task.join
    emit_event(:thread_joined, thread_or_task)
    true
  end

  # Acquires a lock on a resource for the duration of a block.
  def lock(resource, &block)
    raise ArgumentError, "Block required" unless block_given?
    @locks[resource].synchronize { block.call }
    emit_event(:lock_acquired, resource)
    true
  end

  # Creates or retrieves a semaphore.
  def semaphore(name, permits)
    @semaphores[name] ||= Semaphore.new(permits)
  end

  # Creates a barrier for synchronizing threads or tasks.
  def barrier(count)
    @barriers[count] ||= Barrier.new(count)
  end

  # Executes a block atomically.
  def atomic(&block)
    raise ArgumentError, "Block required" unless block_given?
    Mutex.new.synchronize { block.call }
    emit_event(:atomic_executed, nil)
    true
  end

  # Registers for concurrency-related events.
  def on_event(event_type, &block)
    @event_handlers[event_type] << block if block_given?
  end

  private

  def emit_event(event_type, payload)
    @event_handlers[event_type].each { |handler| handler.call(payload) }
  end

  # Simple semaphore implementation for demonstration.
  class Semaphore
    def initialize(permits)
      @permits = permits
      @mutex = Mutex.new
      @cv = ConditionVariable.new
      @count = permits
    end

    def acquire
      @mutex.synchronize do
        @cv.wait(@mutex) while @count <= 0
        @count -= 1
      end
    end

    def release
      @mutex.synchronize do
        @count += 1
        @cv.signal
      end
    end
  end

  # Simple barrier implementation for demonstration.
  class Barrier
    def initialize(count)
      @count = count
      @waiting = 0
      @mutex = Mutex.new
      @cv = ConditionVariable.new
    end

    def wait
      @mutex.synchronize do
        @waiting += 1
        if @waiting < @count
          @cv.wait(@mutex)
        else
          @waiting = 0
          @cv.broadcast
        end
      end
    end
  end
end