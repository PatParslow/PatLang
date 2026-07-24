//! Tests for MemoryManager core module

use patlang_runtime::memory_manager::MemoryManager;
use patlang_runtime::core_evaluator::CoreEvaluator;
use patlang_runtime::event_system::EventSystem;
use patlang_runtime::message_queue::MessageQueue;
use patlang_runtime::error_handler::DefaultErrorHandler;
use patlang_runtime::secure_distributed_code_support::SecureDistributedCodeSupport;



#[test]
fn test_allocate_success() {
    let core = CoreEvaluator::new(None, None, None, None, None);
    let event = EventSystem::new();
    let queue = MessageQueue::new(16).0;
    let err = DefaultErrorHandler;
    let secure = SecureDistributedCodeSupport::default();
    let mut mgr = MemoryManager::new(
        &core,
        &event,
        &queue,
        &err,
        &secure,
    );
    let handle = mgr.allocate(64).expect("Allocation should succeed");
    assert_eq!(handle.size(), 64);
}

#[test]
fn test_multiple_allocations() {
    let core = CoreEvaluator::new(None, None, None, None, None);
    let event = EventSystem::new();
    let queue = MessageQueue::new(16).0;
    let err = DefaultErrorHandler;
    let secure = SecureDistributedCodeSupport::default();
    let mut mgr = MemoryManager::new(
        &core,
        &event,
        &queue,
        &err,
        &secure,
    );
    let h1 = mgr.allocate(8).unwrap();
    let h2 = mgr.allocate(16).unwrap();
    assert_ne!(h1.ptr(), h2.ptr());
    assert_eq!(mgr.allocate(0).unwrap().size(), 0);
}

// Add more tests for error cases and edge conditions as implementation grows.