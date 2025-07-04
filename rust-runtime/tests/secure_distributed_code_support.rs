//! Tests for SecureDistributedCodeSupport core module

use patlang_runtime::secure_distributed_code_support::{
    SecurityPolicy, DistributedProtocol, deploy_code,
};
use patlang_runtime::error_handler::{RuntimeError, RuntimeErrorKind, ErrorHandler};

struct AllowAllPolicy;
impl SecurityPolicy for AllowAllPolicy {
    fn authenticate(&self, _node_id: &str, _credentials: &[u8]) -> Result<bool, RuntimeError> {
        Ok(true)
    }
    fn authorize(&self, _subject: &str, _action: &str, _resource: &str) -> Result<bool, RuntimeError> {
        Ok(true)
    }
}

struct FailingPolicy;
impl SecurityPolicy for FailingPolicy {
    fn authenticate(&self, _node_id: &str, _credentials: &[u8]) -> Result<bool, RuntimeError> {
        Err(RuntimeError::new(RuntimeErrorKind::SecureDistributedCode, "Auth failed"))
    }
    fn authorize(&self, _subject: &str, _action: &str, _resource: &str) -> Result<bool, RuntimeError> {
        Ok(true)
    }
}

struct DummyProtocol;
impl DistributedProtocol for DummyProtocol {
    fn deploy(&self, _code_package: &[u8], _target_nodes: &[String]) -> Result<(), RuntimeError> {
        Ok(())
    }
    fn execute(&self, _node_id: &str, _payload: &[u8]) -> Result<Vec<u8>, RuntimeError> {
        Ok(vec![])
    }
}

struct DummyErrorHandler;
impl ErrorHandler for DummyErrorHandler {
    fn handle(&self, _error: &RuntimeError) {
        // stub
    }
}

#[test]
fn test_deploy_code_success() {
    let code = vec![1, 2, 3];
    let nodes = vec!["node1".to_string()];
    let protocol = DummyProtocol;
    let policy = AllowAllPolicy;
    let result = deploy_code(&code, &nodes, &protocol, Some(&policy), None);
    assert!(result.is_ok());
}

#[test]
fn test_deploy_code_auth_failure() {
    let code = vec![1, 2, 3];
    let nodes = vec!["node1".to_string()];
    let protocol = DummyProtocol;
    let policy = FailingPolicy;
    let result = deploy_code(&code, &nodes, &protocol, Some(&policy), None);
    assert!(result.is_err());
}