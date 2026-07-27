// OO primitives (new/send/get, ChunkId::Oo) -- exercised directly against
// the host functions.
use patlang_runtime::ir::hosts::{host_get, host_new, host_send, host_set_var};
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
fn set_var_with_3_args_sets_the_named_object_field() {
    // Every worked example on the Parslow site's Paradigms Guide, Standard
    // Library reference, and all three language-comparison pages shows
    // set_var(obj, key, val) as an object-field setter -- e.g. `set_var(acct,
    // "balance", 100)`. Confirm that 3-arg form actually mutates the named
    // object's field, not the global __vars store the 2-arg form writes to.
    let _guard = OO_TEST_LOCK.lock().unwrap();
    let name = host_new(&[s("Account"), s("oo_test_set_var_3arg")]).unwrap();
    host_set_var(&[name.clone(), s("balance"), Value::Int(100)]).unwrap();
    assert_eq!(host_get(&[name, s("balance")]).unwrap(), Value::Int(100));
}

#[test]
fn set_var_with_2_args_still_writes_the_global_vars_store() {
    // The pre-existing 2-arg set_var(key, val) global form (used throughout
    // self_hosting/examples/*.patlang, e.g. build_daemon_demo.patlang) must
    // keep working unchanged alongside the object-scoped 3-arg form above.
    let _guard = OO_TEST_LOCK.lock().unwrap();
    host_set_var(&[s("oo_test_global_flag"), s("1")]).unwrap();
    assert_eq!(
        host_get(&[s("__vars"), s("oo_test_global_flag")]).unwrap(),
        s("1")
    );
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
