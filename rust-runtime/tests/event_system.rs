//! Tests for EventSystem core module

use patlang_runtime::event_system::{EventSystem, Event};
use std::sync::{Arc, Mutex};

#[test]
fn test_event_handler_registration_and_emission() {
    let system = EventSystem::new();
    let called = Arc::new(Mutex::new(false));
    let called_clone = called.clone();
    let handler = Arc::new(move |_event| {
        *called_clone.lock().unwrap() = true;
    });
    system.register_handler("test_event", handler);
    let event = Event {
        event_type: "test_event".to_string(),
        payload: "".to_string(),
    };
    system.emit(&event);
    assert_eq!(*called.lock().unwrap(), true);
}

#[test]
fn test_emit_with_no_handlers() {
    let system = EventSystem::new();
    let event = Event {
        event_type: "no_handler".to_string(),
        payload: "".to_string(),
    };
    // Should not panic or fail
    system.emit(&event);
}