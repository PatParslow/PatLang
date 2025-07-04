//! Tests for EventSystem core module

use patlang_runtime::event_system::{EventSystem, Event};
use std::sync::{Arc, Mutex};

#[test]
fn test_event_handler_registration_and_emission() {
    use patlang_runtime::event_system::EventListener;

    struct TestHandler {
        called: Arc<Mutex<bool>>,
    }

    impl EventListener for TestHandler {
        fn on_event(&self, _event: &Event) {
            *self.called.lock().unwrap() = true;
        }
    }

    let mut system = EventSystem::new();
    let called = Arc::new(Mutex::new(false));
    let handler = Box::new(TestHandler {
        called: called.clone(),
    });
    system.register_handler(handler);
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