//! Event system traits and types.

/// Represents a listener for events within the runtime.
///
/// Implementors of this trait can receive notifications when events occur.
pub trait EventListener {
/// Called when an event is dispatched.
///
/// # Arguments
///
/// * event - Reference to the event that was triggered.
fn on_event(&self, event: &Event);
}

/// Event struct with required fields for integration.
#[derive(Debug, Clone)]
pub struct Event {
pub event_type: String,
pub payload: String,
}

/// Minimal public EventSystem struct for integration.
#[derive(Default)]
pub struct EventSystem {
    handlers: Vec<Box<dyn EventListener>>,
}

impl EventSystem {
    /// Creates a new EventSystem instance.
    pub fn new() -> Self {
        EventSystem {
            handlers: Vec::new(),
        }
    }

    /// Registers an event handler.
    pub fn register_handler(&mut self, handler: Box<dyn EventListener>) {
        self.handlers.push(handler);
    }

    /// Emits an event to all registered handlers.
    pub fn emit(&self, event: &Event) {
        for handler in &self.handlers {
            handler.on_event(event);
        }
    }
}
