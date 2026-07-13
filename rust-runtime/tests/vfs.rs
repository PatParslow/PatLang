// Virtual filesystem (vfs_read/vfs_write/vfs_exists/vfs_list/vfs_delete/
// vfs_flush_to_disk) -- exercised directly against the host functions.
use patlang_runtime::ir::hosts::{
    host_vfs_delete, host_vfs_exists, host_vfs_flush_to_disk, host_vfs_list, host_vfs_read,
    host_vfs_write,
};
use patlang_runtime::ir::types::Value;
use std::sync::Mutex;

// vfs_* is a single global store (not per-test), so serialize tests that
// touch it to avoid cross-test interference.
static VFS_TEST_LOCK: Mutex<()> = Mutex::new(());

fn s(x: &str) -> Value { Value::String(x.to_string()) }

#[test]
fn read_write_exists_delete_roundtrip() {
    let _guard = VFS_TEST_LOCK.lock().unwrap();
    let path = "vfs_test/roundtrip.txt";
    assert_eq!(host_vfs_exists(&[s(path)]).unwrap(), Value::String("0".into()));
    host_vfs_write(&[s(path), s("hello")]).unwrap();
    assert_eq!(host_vfs_exists(&[s(path)]).unwrap(), Value::String("1".into()));
    assert_eq!(host_vfs_read(&[s(path)]).unwrap(), Value::String("hello".into()));
    assert_eq!(host_vfs_delete(&[s(path)]).unwrap(), Value::Bool(true));
    assert_eq!(host_vfs_exists(&[s(path)]).unwrap(), Value::String("0".into()));
    // Deleting again returns false, not an error.
    assert_eq!(host_vfs_delete(&[s(path)]).unwrap(), Value::Bool(false));
}

#[test]
fn read_of_missing_path_errors() {
    let _guard = VFS_TEST_LOCK.lock().unwrap();
    assert!(host_vfs_read(&[s("vfs_test/does_not_exist.txt")]).is_err());
}

#[test]
fn list_prefix_matches_only_matching_paths() {
    let _guard = VFS_TEST_LOCK.lock().unwrap();
    host_vfs_write(&[s("vfs_test/list/a.txt"), s("a")]).unwrap();
    host_vfs_write(&[s("vfs_test/list/b.txt"), s("b")]).unwrap();
    host_vfs_write(&[s("vfs_test/other/c.txt"), s("c")]).unwrap();
    let listed = host_vfs_list(&[s("vfs_test/list/")]).unwrap();
    match listed {
        Value::List(xs) => assert_eq!(xs.len(), 2, "should only match the vfs_test/list/ prefix, not vfs_test/other/"),
        _ => panic!("expected List"),
    }
    host_vfs_delete(&[s("vfs_test/list/a.txt")]).unwrap();
    host_vfs_delete(&[s("vfs_test/list/b.txt")]).unwrap();
    host_vfs_delete(&[s("vfs_test/other/c.txt")]).unwrap();
}

#[test]
fn writes_from_other_os_threads_are_visible_to_the_main_thread() {
    // The whole reason vfs_* is a plain Mutex-backed static rather than
    // thread_local! (matching EVENT_HANDLERS's own established pattern):
    // parallel_map spawns real OS threads, and a thread_local VFS would
    // silently give each one an isolated, mutually-invisible filesystem
    // view. Prove cross-thread visibility directly.
    let _guard = VFS_TEST_LOCK.lock().unwrap();
    let path = "vfs_test/cross_thread.txt";
    host_vfs_delete(&[s(path)]).unwrap();
    std::thread::spawn(move || {
        host_vfs_write(&[Value::String(path.to_string()), Value::String("written from another thread".to_string())]).unwrap();
    }).join().unwrap();
    assert_eq!(host_vfs_read(&[s(path)]).unwrap(), Value::String("written from another thread".into()), "a write from a spawned OS thread must be visible from the main thread");
    host_vfs_delete(&[s(path)]).unwrap();
}

#[test]
fn flush_to_disk_writes_real_files_within_the_allowed_root() {
    let _guard = VFS_TEST_LOCK.lock().unwrap();
    let tmp = std::env::temp_dir().join("patlang_vfs_flush_test");
    let _ = std::fs::remove_dir_all(&tmp);
    unsafe { std::env::set_var("PATLANG_VFS_ALLOWED_ROOT", std::env::temp_dir()); }

    host_vfs_write(&[s("flush_test/hello.txt"), s("flushed content")]).unwrap();
    host_vfs_write(&[s("flush_test/nested/deep.txt"), s("deep content")]).unwrap();
    let result = host_vfs_flush_to_disk(&[s("flush_test/"), s(tmp.to_str().unwrap())]).unwrap();
    assert_eq!(result, Value::Int(2));

    let written = std::fs::read_to_string(tmp.join("hello.txt")).expect("real file should exist");
    assert_eq!(written, "flushed content");
    let written_nested = std::fs::read_to_string(tmp.join("nested/deep.txt")).expect("real nested file should exist");
    assert_eq!(written_nested, "deep content");

    let _ = std::fs::remove_dir_all(&tmp);
    host_vfs_delete(&[s("flush_test/hello.txt")]).unwrap();
    host_vfs_delete(&[s("flush_test/nested/deep.txt")]).unwrap();
    unsafe { std::env::remove_var("PATLANG_VFS_ALLOWED_ROOT"); }
}

#[test]
fn flush_to_disk_rejects_a_target_outside_the_allowed_root() {
    let _guard = VFS_TEST_LOCK.lock().unwrap();
    // Constrain the allowed root to a fresh, narrow subdirectory so a
    // sibling directory is guaranteed to be outside it.
    let allowed = std::env::temp_dir().join("patlang_vfs_allowed_root_test");
    let outside = std::env::temp_dir().join("patlang_vfs_outside_root_test");
    let _ = std::fs::create_dir_all(&allowed);
    let _ = std::fs::remove_dir_all(&outside);
    unsafe { std::env::set_var("PATLANG_VFS_ALLOWED_ROOT", &allowed); }

    host_vfs_write(&[s("reject_test/x.txt"), s("should not be written")]).unwrap();
    let result = host_vfs_flush_to_disk(&[s("reject_test/"), s(outside.to_str().unwrap())]);
    assert!(result.is_err(), "a target outside the allowed root must be rejected");
    assert!(!outside.join("x.txt").exists(), "no file should have been written");

    let _ = std::fs::remove_dir_all(&allowed);
    let _ = std::fs::remove_dir_all(&outside);
    host_vfs_delete(&[s("reject_test/x.txt")]).unwrap();
    unsafe { std::env::remove_var("PATLANG_VFS_ALLOWED_ROOT"); }
}
