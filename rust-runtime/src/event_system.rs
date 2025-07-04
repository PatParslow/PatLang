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
#[derive(Debug, Default)]
pub struct EventSystem;
impl EventSystem {
    /// Creates a new EventSystem instance.
    pub fn new() -> Self {
        EventSystem
    }
    /// Registers an event handler.
    pub fn register_handler(&mut self, _handler: Box<dyn EventListener>) {
        // Stub implementation
    }

    /// Emits an event to all registered handlers.
    pub fn emit(&self, _event: &Event) {
        // Stub implementation
    }
}
