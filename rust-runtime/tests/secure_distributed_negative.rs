use patlang_runtime::secure_distributed_code_support::{execute_remote, deploy_code, SecurityPolicy, DistributedProtocol};
use patlang_runtime::error_handler::{RuntimeError, RuntimeErrorKind, ErrorHandler};

struct DenyAllPolicy;
impl SecurityPolicy for DenyAllPolicy {
    fn authenticate(&self, _node_id: &str, _credentials: &[u8]) -> Result<bool, RuntimeError> {
        Ok(false)
    }
    fn authorize(&self, _subject: &str, _action: &str, _resource: &str) -> Result<bool, RuntimeError> {
        Err(RuntimeError::new(RuntimeErrorKind::SecureDistributedCode, "not authorized"))
    }
}

struct AllowAllPolicy;
impl SecurityPolicy for AllowAllPolicy {
    fn authenticate(&self, _node_id: &str, _credentials: &[u8]) -> Result<bool, RuntimeError> { Ok(true) }
    fn authorize(&self, _subject: &str, _action: &str, _resource: &str) -> Result<bool, RuntimeError> { Ok(true) }
}

struct ErrProtocol;
impl DistributedProtocol for ErrProtocol {
    fn deploy(&self, _code_package: &[u8], _target_nodes: &[String]) -> Result<(), RuntimeError> {
        Err(RuntimeError::new(RuntimeErrorKind::SecureDistributedCode, "deploy failed"))
    }
    fn execute(&self, _node_id: &str, _payload: &[u8]) -> Result<Vec<u8>, RuntimeError> {
        Err(RuntimeError::new(RuntimeErrorKind::SecureDistributedCode, "exec failed"))
    }
}

struct CapturingHandler(std::sync::Mutex<Vec<String>>);
impl ErrorHandler for CapturingHandler {
    fn handle(&self, error: &RuntimeError) {
        self.0.lock().unwrap().push(error.message.clone());
    }
}

#[test]
fn test_deploy_protocol_error_and_authz_error() {
    let handler = CapturingHandler(std::sync::Mutex::new(vec![]));
    let nodes = vec!["n1".to_string()];
    let policy = DenyAllPolicy;
    let err = deploy_code(b"pkg", &nodes, &ErrProtocol, Some(&policy), Some(&handler)).unwrap_err();
    assert!(format!("{}", err).contains("deploy failed"));
    // ensure handler captured
    assert!(!handler.0.lock().unwrap().is_empty());
}

#[test]
fn test_execute_authz_error_does_not_invoke_handler() {
    let handler = CapturingHandler(std::sync::Mutex::new(vec![]));
    let policy = DenyAllPolicy;
    let err = execute_remote("n1", b"p", &ErrProtocol, Some(&policy), Some(&handler)).unwrap_err();
    assert!(format!("{}", err).contains("not authorized"));
    // early return from authz error should not call handler
    assert!(handler.0.lock().unwrap().is_empty());
}

#[test]
fn test_execute_protocol_error_invokes_handler() {
    let handler = CapturingHandler(std::sync::Mutex::new(vec![]));
    let policy = AllowAllPolicy; // allow execution to reach protocol
    let err = execute_remote("n1", b"p", &ErrProtocol, Some(&policy), Some(&handler)).unwrap_err();
    assert!(format!("{}", err).contains("exec failed"));
    // protocol error path should call handler
    assert!(!handler.0.lock().unwrap().is_empty());
}
