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
    /// Set by `budgeted_run` when this fiber backs a `budgeted(ms) { ... }`
    /// block; a wall-clock deadline (ms since epoch, matching `now_ms()`)
    /// checked by `budget_check` at each instrumented while-loop back-edge.
    /// `None` for ordinary (non-budgeted) fibers, which `budget_check` can
    /// never observe anyway since it only runs on the current fiber's thread.
    budget_deadline_ms: Option<i64>,
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
        state: Mutex::new(FiberBox { to_fiber: None, from_fiber: None, alive: true, budget_deadline_ms: None }),
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
        // register_stage0_shims deliberately doesn't register `print` --
        // callers that install their own print-capturing hook (test
        // harnesses, mainly) call it too, and a global `print` registration
        // there would silently clobber theirs. This fresh, fiber-private
        // interpreter has no such hook to protect, so it gets a plain
        // stdout-writing `print` directly.
        interp.host.insert("print", crate::ir::hosts::host_print);
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

fn now_ms_i64() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

/// budgeted_run(program, ms, func_name, captured, existing_fiber_id) ->
/// ["done", value] or ["paused", fiber_id]. The runtime half of
/// `budgeted(ms) { ... }`: first call (existing_fiber_id is Unit) spawns a
/// fiber running func_name, resumes it with `captured` (a List of the
/// enclosing scope's locals at the point the block was entered -- the
/// synthesized function's sole declared parameter, unpacked in its own
/// prologue) as the fiber's one-and-only initial argument, per fiber_new's
/// single-argument convention; a later call passing back the fiber id from
/// a ["paused", id] result resumes that same fiber from exactly where it
/// left off (its parked OS thread's own call stack is the saved state --
/// see the module doc comment), ignoring `captured` since the fiber's own
/// locals are already live. Each call refreshes the deadline to now+ms, so
/// a paused block gets a fresh timeslice each time its caller resumes it.
pub fn budgeted_run(program: &Program, ms: i64, func_name: &str, captured: Value, existing_fiber_id: &Value) -> Result<Value, String> {
    let (id_value, first_call) = match existing_fiber_id {
        Value::Unit => (fiber_new(program, func_name.to_string())?, true),
        v => (v.clone(), false),
    };
    let id = id_from_value(&id_value)?;
    let deadline = now_ms_i64() + ms;
    {
        let handle = handle_for(id)?;
        let mut st = handle.state.lock().unwrap();
        st.budget_deadline_ms = Some(deadline);
    }
    let resume_arg = if first_call { captured } else { Value::Unit };
    let result = fiber_resume(&id_value, resume_arg)?;
    let still_alive = {
        let handle = handle_for(id)?;
        let st = handle.state.lock().unwrap();
        st.alive
    };
    if still_alive {
        Ok(Value::List(vec![Value::String("paused".into()), id_value]))
    } else {
        Ok(Value::List(vec![Value::String("done".into()), result]))
    }
}

/// budget_check() -> Unit. Called at every while-loop back-edge lexically
/// inside a `budgeted(ms) { ... }` block (injected at lowering time, see
/// `Lowerer::in_budgeted_depth`). A no-op when not running inside any fiber
/// (e.g. a plain top-level `while` accidentally sharing this instrumentation
/// -- shouldn't happen given the lowering guard, but fails safe rather than
/// erroring). When running inside a budgeted fiber whose deadline has
/// passed, suspends via the ordinary `fiber_yield` -- from the loop's point
/// of view this call simply returns (once resumed) and iteration continues,
/// with the caller having observed a `["paused", id]` result in between.
pub fn budget_check() -> Result<(), String> {
    let id = match CURRENT_FIBER.with(|c| c.get()) {
        Some(id) => id,
        None => return Ok(()),
    };
    let handle = handle_for(id)?;
    let deadline = {
        let st = handle.state.lock().unwrap();
        st.budget_deadline_ms
    };
    if let Some(dl) = deadline {
        if now_ms_i64() >= dl {
            fiber_yield(Value::Unit)?;
        }
    }
    Ok(())
}
