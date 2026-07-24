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
    /// Timestamp of the previous `budget_check` call on this fiber (`None`
    /// on the very first call of a timeslice, since there's no prior point
    /// to measure an interval from). Used to turn consecutive calls into
    /// "how long did that iteration take" samples for `recent_durations`.
    budget_last_check_ms: Option<i64>,
    /// Fixed-size ring buffer (oldest evicted first) of recent per-iteration
    /// durations in ms, used to predict whether the *next* iteration is
    /// likely to blow the deadline and yield pre-emptively rather than only
    /// reactively -- see `predict_next_duration_ms`.
    recent_durations: Vec<i64>,
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
        state: Mutex::new(FiberBox {
            to_fiber: None, from_fiber: None, alive: true,
            budget_deadline_ms: None, budget_last_check_ms: None, recent_durations: Vec::new(),
        }),
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
    // Value::Unit is the natural "no handle yet" sentinel when `existing` is
    // omitted from source entirely (budgeted(ms) with no second arg), but
    // PatLang has no Unit literal, so a caller-side driver loop that
    // initializes its own "handle" local before the first call (there being
    // no way to conditionally omit an argument in this grammar) needs a
    // sentinel it CAN write -- `false` is treated the same way for exactly
    // that reason, matching the language's existing truthy/falsy
    // conventions rather than inventing new literal syntax for this alone.
    let (id_value, first_call) = match existing_fiber_id {
        Value::Unit | Value::Bool(false) => (fiber_new(program, func_name.to_string())?, true),
        v => (v.clone(), false),
    };
    let id = id_from_value(&id_value)?;
    let deadline = now_ms_i64() + ms;
    {
        let handle = handle_for(id)?;
        let mut st = handle.state.lock().unwrap();
        st.budget_deadline_ms = Some(deadline);
        // The gap between the last budget_check before this fiber paused and
        // the first one after it resumes is however long the CALLER took to
        // ask for another timeslice, not real loop-body work -- reset so
        // that gap is never recorded as an iteration duration sample.
        st.budget_last_check_ms = None;
    }
    let resume_arg = if first_call { captured } else { Value::Unit };
    let result = fiber_resume(&id_value, resume_arg)?;
    let still_alive = {
        let handle = handle_for(id)?;
        let st = handle.state.lock().unwrap();
        st.alive
    };
    if still_alive {
        Ok(Value::List(Arc::new(vec![Value::String("paused".to_string().into()), id_value])))
    } else {
        Ok(Value::List(Arc::new(vec![Value::String("done".to_string().into()), result])))
    }
}

/// Ring-buffer capacity for `recent_durations` -- enough samples for the
/// regression to see a real trend without weighting ancient iterations
/// (from possibly a very different phase of the loop) too heavily.
const DURATION_WINDOW: usize = 16;

/// Predicts how long the *next* iteration is likely to take, from a window
/// of recent per-iteration durations, favoring conservatism (never predict
/// less than the most recent sample) so a loop that's trending slower gets
/// caught before it overruns rather than after:
///
/// - Fewer than 2 samples: nothing to fit a trend to, predict the most
///   recent sample verbatim (or 0 if there are none yet).
/// - Otherwise: an ordinary-least-squares fit of duration against sample
///   index, extrapolated one step past the last sample (`slope * n +
///   intercept`), clamped to be at least the largest recent sample -- a
///   flat or noisy-but-not-trending series still predicts its own recent
///   worst case, not an average that could understate a spike.
fn predict_next_duration_ms(samples: &[i64]) -> i64 {
    let n = samples.len();
    if n == 0 { return 0; }
    if n < 2 { return samples[n - 1]; }
    let n_f = n as f64;
    let sum_x: f64 = (0..n).map(|i| i as f64).sum();
    let sum_y: f64 = samples.iter().map(|&v| v as f64).sum();
    let sum_xy: f64 = samples.iter().enumerate().map(|(i, &v)| i as f64 * v as f64).sum();
    let sum_xx: f64 = (0..n).map(|i| (i as f64) * (i as f64)).sum();
    let denom = n_f * sum_xx - sum_x * sum_x;
    let (slope, intercept) = if denom.abs() < f64::EPSILON {
        (0.0, sum_y / n_f) // all samples at the same x (shouldn't happen) or n too small
    } else {
        let slope = (n_f * sum_xy - sum_x * sum_y) / denom;
        let intercept = (sum_y - slope * sum_x) / n_f;
        (slope, intercept)
    };
    let regression_estimate = slope * n_f + intercept;
    let recent_max = *samples.iter().max().unwrap_or(&0);
    (regression_estimate.max(0.0) as i64).max(recent_max)
}

/// budget_check() -> Unit. Called at every while-loop back-edge lexically
/// inside a `budgeted(ms) { ... }` block (injected at lowering time, see
/// `Lowerer::in_budgeted_depth`). A no-op when not running inside any fiber
/// (e.g. a plain top-level `while` accidentally sharing this instrumentation
/// -- shouldn't happen given the lowering guard, but fails safe rather than
/// erroring). Records the interval since the previous call as a duration
/// sample, then yields (via the ordinary `fiber_yield`) either reactively
/// (the deadline has already passed) or pre-emptively (the next iteration
/// is predicted, from recent history, to blow it) -- from the loop's point
/// of view this call simply returns (once resumed) and iteration continues,
/// with the caller having observed a `["paused", id]` result in between.
pub fn budget_check() -> Result<(), String> {
    let id = match CURRENT_FIBER.with(|c| c.get()) {
        Some(id) => id,
        None => return Ok(()),
    };
    let handle = handle_for(id)?;
    let now = now_ms_i64();
    let (deadline, predicted) = {
        let mut st = handle.state.lock().unwrap();
        if let Some(prev) = st.budget_last_check_ms {
            let dur = (now - prev).max(0);
            st.recent_durations.push(dur);
            if st.recent_durations.len() > DURATION_WINDOW {
                st.recent_durations.remove(0);
            }
        }
        st.budget_last_check_ms = Some(now);
        let predicted = predict_next_duration_ms(&st.recent_durations);
        (st.budget_deadline_ms, predicted)
    };
    if let Some(dl) = deadline {
        if now + predicted >= dl {
            fiber_yield(Value::Unit)?;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::predict_next_duration_ms;

    #[test]
    fn empty_history_predicts_zero() {
        assert_eq!(predict_next_duration_ms(&[]), 0);
    }

    #[test]
    fn single_sample_predicts_itself() {
        assert_eq!(predict_next_duration_ms(&[42]), 42);
    }

    #[test]
    fn flat_history_predicts_the_flat_value() {
        assert_eq!(predict_next_duration_ms(&[10, 10, 10, 10]), 10);
    }

    #[test]
    fn upward_trend_extrapolates_forward_not_just_averages() {
        // durations climbing 1ms per iteration: 1,2,3,4,5 -- a naive average
        // (3) would understate the next iteration; the regression should
        // predict roughly the next step in the trend (~6).
        let predicted = predict_next_duration_ms(&[1, 2, 3, 4, 5]);
        assert!(predicted >= 5, "predicted {} should be at least the most recent sample", predicted);
        assert!(predicted <= 8, "predicted {} should extrapolate the trend, not overshoot wildly", predicted);
    }

    #[test]
    fn downward_trend_never_predicts_below_the_recent_max() {
        // durations easing off: 10,8,6,4,2 -- regression alone would predict
        // ~0, but a stray future spike shouldn't be masked by a confident
        // downward extrapolation, so the conservative floor is the recent
        // max, not the regression's raw output.
        let predicted = predict_next_duration_ms(&[10, 8, 6, 4, 2]);
        assert!(predicted >= 10, "predicted {} should not undercut the recent max of 10", predicted);
    }

    #[test]
    fn noisy_but_flat_history_stays_conservative() {
        let predicted = predict_next_duration_ms(&[5, 7, 4, 8, 5, 6]);
        assert!(predicted >= 8, "predicted {} should be at least the recent max (8) for noisy-but-flat data", predicted);
    }
}
