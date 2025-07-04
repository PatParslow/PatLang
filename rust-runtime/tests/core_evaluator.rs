//! Tests for CoreEvaluator core module

use patlang_runtime::core_evaluator::{CoreEvaluator, ExecutionContext, AstNode};

struct DummyEventListener;
impl patlang_runtime::event_system::EventListener for DummyEventListener {
    fn on_event(&self, _event: &patlang_runtime::event_system::Event) {
        // stub
    }
}

struct DummyMessageConsumer;
impl patlang_runtime::message_queue::MessageConsumer for DummyMessageConsumer {
    fn on_message(&self, _message: &patlang_runtime::message_queue::Message) {
        // stub
    }
}

struct DummyErrorHandler;
impl patlang_runtime::error_handler::ErrorHandler for DummyErrorHandler {
    fn handle(&self, _error: &patlang_runtime::error_handler::RuntimeError) {
        // stub
    }
}

struct DummySecurityPolicy;
impl patlang_runtime::secure_distributed_code_support::SecurityPolicy for DummySecurityPolicy {
    fn authenticate(&self, _node_id: &str, _credentials: &[u8]) -> Result<bool, patlang_runtime::error_handler::RuntimeError> {
        Ok(true)
    }
    fn authorize(&self, _subject: &str, _action: &str, _resource: &str) -> Result<bool, patlang_runtime::error_handler::RuntimeError> {
        Ok(true)
    }
}

struct DummyDistributedProtocol;
impl patlang_runtime::secure_distributed_code_support::DistributedProtocol for DummyDistributedProtocol {
    fn deploy(&self, _code_package: &[u8], _target_nodes: &[String]) -> Result<(), patlang_runtime::error_handler::RuntimeError> {
        Ok(())
    }
    fn execute(&self, _node_id: &str, _payload: &[u8]) -> Result<Vec<u8>, patlang_runtime::error_handler::RuntimeError> {
        Ok(vec![])
    }
}

#[test]
fn test_core_evaluator_new() {
    let evaluator = CoreEvaluator::new(
        Some(&DummyEventListener),
        Some(&DummyMessageConsumer),
        Some(&DummyErrorHandler),
        Some(&DummySecurityPolicy),
        Some(&DummyDistributedProtocol),
    );
    assert!(evaluator.event_listener.is_some());
    assert!(evaluator.message_consumer.is_some());
    assert!(evaluator.error_handler.is_some());
    assert!(evaluator.security_policy.is_some());
    assert!(evaluator.distributed_protocol.is_some());
}

#[test]
fn test_execution_context_new() {
    let ctx = ExecutionContext::new();
    // No fields to check, but should construct
    let _ = ctx;
}

#[test]
fn test_ast_node_construction() {
    let node = AstNode {
        kind: "root".to_string(),
        children: vec![],
    };
    assert_eq!(node.kind, "root");
    assert!(node.children.is_empty());
}