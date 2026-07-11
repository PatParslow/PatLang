//! Fibers: Ruby-style cooperative green threads, implemented on top of real
//! OS threads rather than stack-switching -- a `Fiber` gets its own
//! `std::thread`, but a mutex+condvar pair ensures only one side (the
//! fiber's thread, or whoever last called `fiber_resume`) is ever actually
//! *running* PatLang code at a time. `fiber_yield`/`fiber_resume` hand
//! control back and forth by parking/waking these threads, never by
//! touching the interpreter's call stack directly -- the OS thread's own
//! native stack IS the "saved coroutine state" while it's parked, which is
//! what makes this approach so much simpler than a real stack-switching
//! coroutine implementation.
//!
//! Distinct from `parallel_map` (interpreter.rs): fibers give cooperative,
//! single-active-at-a-time concurrency (explicit control transfer, like
//! Ruby's `Fiber`), not real parallelism -- only one fiber's thread is ever
//! unparked at once. `parallel_map` is the genuine-parallelism primitive.

use super::types::{Program, Value};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Condvar, Mutex, OnceLock};

enum FiberMsg {
    /// The fiber called fiber_yield(v); still alive, can be resumed again.
    Yielded(Value),
    /// The fiber's function returned (or errored); no further resumes.
    Done(Result<Value, String>),
}

struct FiberBox {
    /// Set by fiber_resume, consumed by the parked fiber thread on wake.
    to_fiber: Option<Value>,
    /// Set by the fiber thread (via fiber_yield or on completion), consumed
    /// by whichever fiber_resume call is currently waiting.
    from_fiber: Option<FiberMsg>,
    alive: bool,
}

struct FiberHandle {
    state: Mutex<FiberBox>,
    cv: Condvar,
}

fn registry() -> &'static Mutex<HashMap<u64, Arc<FiberHandle>>> {
    static REGISTRY: OnceLock<Mutex<HashMap<u64, Arc<FiberHandle>>>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

fn next_id() -> u64 {
    static NEXT: AtomicU64 = AtomicU64::new(1);
    NEXT.fetch_add(1, Ordering::Relaxed)
}

thread_local! {
    // Which fiber (if any) is "self" from the point of view of code running
    // on the current OS thread -- set once, at the top of a fiber's thread
    // closure, read by fiber_yield to find its own handle without needing
    // to thread an id through every CallHost signature.
    static CURRENT_FIBER: std::cell::Cell<Option<u64>> = std::cell::Cell::new(None);
}

/// fiber_new(func_name) -> fiber id (as a Value::Int). Spawns the fiber's
/// OS thread immediately; it parks waiting for the first `fiber_resume`
/// before actually calling `func_name`, so `fiber_new` itself is cheap and
/// synchronous. `program` is cloned once here (an owned, 'static copy) so
/// the spawned thread can outlive this call -- Program is plain data
/// (Send + Sync automatically), so this is a real, if not free, one-time
/// cost, not a correctness workaround.
pub fn fiber_new(program: &Program, func_name: String) -> Result<Value, String> {
    if !program.functions.contains_key(&func_name) {
        return Err(format!("fiber_new: function '{}' not found", func_name));
    }
    let id = next_id();
    let handle = Arc::new(FiberHandle {
        state: Mutex::new(FiberBox { to_fiber: None, from_fiber: None, alive: true }),
        cv: Condvar::new(),
    });
    registry().lock().unwrap().insert(id, Arc::clone(&handle));

    let program_owned = program.clone();
    std::thread::spawn(move || {
        CURRENT_FIBER.with(|c| c.set(Some(id)));

        // Wait for the first fiber_resume to deliver the initial argument.
        let first_arg = {
            let mut st = handle.state.lock().unwrap();
            while st.to_fiber.is_none() {
                st = handle.cv.wait(st).unwrap();
            }
            st.to_fiber.take().unwrap()
        };

        let mut interp = crate::ir::interpreter::Interpreter::new();
        crate::ir::hosts::register_stage0_shims(&mut interp);
        let result = interp.call_function(&program_owned, &func_name, &[first_arg]);

        let mut st = handle.state.lock().unwrap();
        st.alive = false;
        st.from_fiber = Some(FiberMsg::Done(result));
        handle.cv.notify_all();
    });

    Ok(Value::Int(id as i64))
}

fn handle_for(id: u64) -> Result<Arc<FiberHandle>, String> {
    registry()
        .lock()
        .unwrap()
        .get(&id)
        .cloned()
        .ok_or_else(|| format!("fiber: unknown fiber id {}", id))
}

fn id_from_value(v: &Value) -> Result<u64, String> {
    match v {
        Value::Int(n) if *n >= 0 => Ok(*n as u64),
        other => Err(format!("fiber: expected a fiber id, got {:?}", other)),
    }
}

/// fiber_resume(id, arg) -> the value the fiber yielded, or its final
/// return value if this resume caused it to finish. Blocks the CALLING
/// thread (which may itself be another fiber, or the "main" interpreter
/// thread) until the target fiber yields or returns.
pub fn fiber_resume(id_val: &Value, arg: Value) -> Result<Value, String> {
    let id = id_from_value(id_val)?;
    let handle = handle_for(id)?;
    let mut st = handle.state.lock().unwrap();
    if !st.alive {
        return Err(format!("fiber_resume: fiber {} has already finished", id));
    }
    st.to_fiber = Some(arg);
    handle.cv.notify_all();
    while st.from_fiber.is_none() {
        st = handle.cv.wait(st).unwrap();
    }
    match st.from_fiber.take().unwrap() {
        FiberMsg::Yielded(v) => Ok(v),
        FiberMsg::Done(r) => r,
    }
}

/// fiber_yield(value) -> whatever the next fiber_resume(id, arg) passes in.
/// Must be called from inside a fiber's own thread (i.e. from PatLang code
/// running as part of a fiber_new'd function, possibly nested through
/// ordinary Call/CallValue -- CURRENT_FIBER is thread-local, so it's
/// visible to any nested call on the same OS thread).
pub fn fiber_yield(value: Value) -> Result<Value, String> {
    let id = CURRENT_FIBER.with(|c| c.get())
        .ok_or_else(|| "fiber_yield: not running inside a fiber".to_string())?;
    let handle = handle_for(id)?;
    let mut st = handle.state.lock().unwrap();
    st.from_fiber = Some(FiberMsg::Yielded(value));
    handle.cv.notify_all();
    while st.to_fiber.is_none() {
        st = handle.cv.wait(st).unwrap();
    }
    Ok(st.to_fiber.take().unwrap())
}

/// fiber_alive(id) -> Bool. True until the fiber's function has returned
/// (or errored) and its final Done message has been consumed by a resume.
pub fn fiber_alive(id_val: &Value) -> Result<Value, String> {
    let id = id_from_value(id_val)?;
    let handle = handle_for(id)?;
    let st = handle.state.lock().unwrap();
    Ok(Value::Bool(st.alive))
}
