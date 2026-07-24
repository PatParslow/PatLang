// OO primitives (new/send/get, ChunkId::Oo) -- exercised directly against
// the host functions.
use patlang_runtime::ir::hosts::{host_get, host_new, host_send};
use patlang_runtime::ir::types::Value;
use std::sync::Mutex;

// OBJECTS is a single global store (not per-test), so serialize tests that
// touch it to avoid cross-test interference.
static OO_TEST_LOCK: Mutex<()> = Mutex::new(());

fn s(x: &str) -> Value { Value::String(x.to_string().into()) }

#[test]
fn new_send_set_get_roundtrip() {
    let _guard = OO_TEST_LOCK.lock().unwrap();
    let name = host_new(&[s("job"), s("oo_test_roundtrip")]).unwrap();
    assert_eq!(name, s("oo_test_roundtrip"));
    host_send(&[name.clone(), s("set"), s("status"), s("running")]).unwrap();
    assert_eq!(host_get(&[name, s("status")]).unwrap(), s("running"));
}

#[test]
fn writes_from_other_os_threads_are_visible_to_the_main_thread() {
    // The whole reason OBJECTS is a plain Mutex-backed static rather than
    // thread_local! (matching EVENT_HANDLERS/VFS's own established
    // pattern): parallel_map spawns real OS threads, and a thread_local
    // OBJECTS would silently give each one an isolated, mutually-invisible
    // object store -- an object created via `new(...)` on one worker thread
    // would never be visible to `get`/`send` calls on another. Prove
    // cross-thread visibility directly.
    let _guard = OO_TEST_LOCK.lock().unwrap();
    let name = "oo_test_cross_thread";
    std::thread::spawn(move || {
        host_new(&[s("job"), s(name)]).unwrap();
        host_send(&[s(name), s("set"), s("status"), s("done")]).unwrap();
    })
    .join()
    .unwrap();
    assert_eq!(
        host_get(&[s(name), s("status")]).unwrap(),
        s("done"),
        "an object created and mutated on a spawned OS thread must be visible from the main thread"
    );
}
