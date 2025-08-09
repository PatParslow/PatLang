use patlang_runtime::secure_distributed_code_support::{
    InMemorySecurityPolicy, LocalDistributedProtocol, deploy_code, execute_remote,
};
use patlang_runtime::error_handler::RuntimeError;

#[test]
fn test_in_memory_policy_and_local_protocol() -> Result<(), RuntimeError> {
    // Prepare policy with one node and a permission
    let policy = InMemorySecurityPolicy::new()
        .register_node("node1", b"secret".to_vec())
        .grant("node1", "execute", "payload");

    // Prepare protocol
    let protocol = LocalDistributedProtocol::new();

    // Deploy code
    let code = b"wasm:demo".to_vec();
    deploy_code(&code, &["node1".into()], &protocol, Some(&policy), None)?;

    // Verify deployment recorded
    let dep = protocol.deployments_for("node1");
    assert_eq!(dep.len(), 1);
    assert_eq!(dep[0], code);

    // Execute remotely
    let resp = execute_remote("node1", b"hello", &protocol, Some(&policy), None)?;
    assert_eq!(resp, b"hello".to_vec());
    assert_eq!(protocol.execution_count(), 1);

    Ok(())
}
