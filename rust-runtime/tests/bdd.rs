//! BDD-style (Cucumber/Gherkin) regression suite.
//!
//! Added after several real bugs (a missing oo->logic cross-chunk edge, a
//! compiled-program Value size regression, IDE-breaking parser bugs) slipped
//! past the existing `cargo test` suite because nothing swept the
//! combinatorial space where they actually lived: chunk combinations,
//! interpreted-vs-compiled parity, and Value memory layout. Each `.feature`
//! file under `tests/features/` targets one of those blind spots; see the
//! audit notes at the top of each feature file for the specific bug class it
//! guards against.
//!
//! Black-box by design: every scenario drives the real `pat` binary
//! (`CARGO_BIN_EXE_pat`, built fresh by cargo before this test runs) as a
//! subprocess, the same way a user would invoke it, rather than reaching
//! into internal APIs.

use cucumber::gherkin::Step;
use cucumber::{given, then, when, World};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicUsize, Ordering};

#[derive(Debug, Clone, Default)]
struct RunResult {
    stdout: String,
    stderr: String,
    success: bool,
}

fn run(cmd: &Path, args: &[&str], cwd: &Path) -> RunResult {
    let out = Command::new(cmd)
        .args(args)
        .current_dir(cwd)
        .output()
        .unwrap_or_else(|e| panic!("failed to spawn {:?} {:?}: {}", cmd, args, e));
    RunResult {
        stdout: String::from_utf8_lossy(&out.stdout).to_string(),
        stderr: String::from_utf8_lossy(&out.stderr).to_string(),
        success: out.status.success(),
    }
}

fn repo_root() -> PathBuf {
    // tests run with CWD = rust-runtime/ (the crate root); repo root is its parent.
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("rust-runtime has a parent dir")
        .to_path_buf()
}

fn pat_exe() -> PathBuf {
    PathBuf::from(env!("CARGO_BIN_EXE_pat"))
}

static SCENARIO_COUNTER: AtomicUsize = AtomicUsize::new(0);

fn fresh_scratch_dir(n: usize) -> PathBuf {
    let base = std::env::var("CARGO_TARGET_TMPDIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| std::env::temp_dir());
    let dir = base.join("bdd_scratch").join(format!("s{n}"));
    std::fs::create_dir_all(&dir).expect("create scratch dir");
    dir
}

#[derive(Debug, World)]
#[world(init = Self::new)]
struct PatWorld {
    repo_root: PathBuf,
    scratch_dir: PathBuf,
    scenario_id: usize,
    source: String,
    interp: Option<RunResult>,
    compile_ok: Option<bool>,
    compile_stderr: String,
    compiled: Option<RunResult>,
}

impl PatWorld {
    fn new() -> Self {
        let id = SCENARIO_COUNTER.fetch_add(1, Ordering::SeqCst);
        PatWorld {
            repo_root: repo_root(),
            scratch_dir: fresh_scratch_dir(id),
            scenario_id: id,
            source: String::new(),
            interp: None,
            compile_ok: None,
            compile_stderr: String::new(),
            compiled: None,
        }
    }

    /// Writes the current scenario's source as a `.patlang` file. Placed
    /// directly under `self_hosting/` (flat, uniquely named, cleaned up by
    /// `Drop`) rather than in an OS scratch dir: `include "lib/..."`
    /// resolves relative to the including file's own directory, so any
    /// scenario that exercises `include` (the self-hosted test suites, and
    /// the multi-line-continuation regression case) needs its source to
    /// actually live alongside `self_hosting/lib/`, not in an unrelated temp
    /// directory.
    fn write_source(&self) -> PathBuf {
        let name = format!("_bdd_scenario_{}.patlang", self.scenario_id);
        let path = self.repo_root.join("self_hosting").join(name);
        std::fs::write(&path, &self.source).expect("write scenario source");
        path
    }
}

impl Drop for PatWorld {
    fn drop(&mut self) {
        let name = format!("_bdd_scenario_{}.patlang", self.scenario_id);
        let _ = std::fs::remove_file(self.repo_root.join("self_hosting").join(name));
    }
}

// ===== Given =====

#[given(regex = r#"^a PatLang program that prints "(.*)"$"#)]
fn given_prints(world: &mut PatWorld, expr: String) {
    world.source = format!("print({expr})\n");
}

#[given(regex = r"^a PatLang program:$")]
fn given_program_docstring(world: &mut PatWorld, step: &Step) {
    world.source = step
        .docstring
        .clone()
        .expect("expected a docstring attached to this step");
}

#[given(regex = r#"^the "(fast|numeric_tower)" compiled Value module$"#)]
fn given_value_module(world: &mut PatWorld, which: String) {
    use patlang_runtime::ir::codegen::{ChunkId, RustCodegen};
    use std::collections::BTreeSet;
    // Uses the real emitted chunk text (the exact `&'static str` embedded in
    // every compiled program), not a structurally-equivalent stand-in --
    // this is what caught the earlier Complex-boxing bloat only when
    // verified this way; a hand-copied stand-in type could silently drift
    // from the real definition and stop catching regressions.
    let mut set = BTreeSet::new();
    set.insert(ChunkId::Core);
    if which == "numeric_tower" {
        set.insert(ChunkId::NumericTower);
    }
    let prelude = RustCodegen::prelude_for(&set);
    // `prelude_for` always includes PRELUDE_CORE's own `fn main` (which
    // calls `build_program()`, only defined by the real codegen pipeline for
    // an actual compiled program) -- replace that literal, known main body
    // with a probe that just reports `size_of::<Value>()` instead of
    // appending a second `main` (which wouldn't compile) or trying to
    // provide a fake `build_program()`.
    let real_main = "#[cfg(not(target_arch = \"wasm32\"))]\nfn main(){\n    let child = std::thread::Builder::new()\n        .stack_size(256 * 1024 * 1024)\n        .spawn(|| {\n            let program = build_program();\n            match run(&program) {\n                Ok(v) => { println!(\"{}\", display_value(&v)); 0 }\n                Err(e) => { eprintln!(\"IR runtime error: {}\", e); 1 }\n            }\n        })\n        .expect(\"failed to spawn worker thread\");\n    let code = child.join().unwrap_or(1);\n    std::process::exit(code);\n}\n";
    let probe_main = "fn main() { println!(\"{}\", std::mem::size_of::<Value>()); }\n";
    assert!(
        prelude.contains(real_main),
        "PRELUDE_CORE's main() text changed shape -- update the literal match in given_value_module"
    );
    world.source = prelude.replacen(real_main, probe_main, 1);
}

#[given(regex = r#"^the self-hosted test suite "([a-z_]+)"$"#)]
fn given_selftest_suite(world: &mut PatWorld, name: String) {
    let root = world.repo_root.clone();
    let read = |rel: &str| -> String {
        std::fs::read_to_string(root.join(rel))
            .unwrap_or_else(|e| panic!("failed to read {rel}: {e}"))
    };
    world.source = match name.as_str() {
        // pos_tests.patlang's own header comment documents this exact
        // concatenation order: lib/test.patlang (the assertion/Gherkin-style
        // feature-runner framework) + lib/pos.patlang (the library under
        // test) + examples/pos_tests.patlang (the suite itself).
        "pos" => {
            read("self_hosting/lib/test.patlang")
                + &read("self_hosting/lib/pos.patlang")
                + &read("self_hosting/examples/pos_tests.patlang")
        }
        // regex_dsl_selftest.patlang and syntax_dsl_selftest.patlang are
        // already complete, self-contained, runnable scripts (they `include`
        // their own dependencies), so no concatenation is needed here.
        "regex_dsl" => read("self_hosting/regex_dsl_selftest.patlang"),
        "syntax_dsl" => read("self_hosting/syntax_dsl_selftest.patlang"),
        "reflect_transpile" => read("self_hosting/reflect_transpile_selftest.patlang"),
        // The inductive-synthesis engine's selftest suite
        // (self_hosting/synthesis_*_selftest.patlang) is deliberately NOT
        // wired in here -- run via `pat --ir-run self_hosting/tools/
        // run_synthesis_selftests.patlang` instead, a PatLang-native
        // runner that needs no cargo/cucumber. See that tool's header
        // comment and patlang-inductive-synthesis.html on parslow.net.
        other => panic!("unknown self-hosted test suite: {other}"),
    };
}

// ===== When =====

#[when("I run it interpreted")]
fn when_run_interpreted(world: &mut PatWorld) {
    let path = world.write_source();
    let root = world.repo_root.clone();
    world.interp = Some(run(&pat_exe(), &["--ir-run", path.to_str().unwrap()], &root));
}

#[when("I compile and run it natively")]
fn when_compile_and_run(world: &mut PatWorld) {
    let path = world.write_source();
    let exe = world.scratch_dir.join("scenario.exe");
    let root = world.repo_root.clone();
    let build = run(
        &pat_exe(),
        &["--patc", path.to_str().unwrap(), "--out", exe.to_str().unwrap()],
        &root,
    );
    world.compile_ok = Some(build.success);
    world.compile_stderr = build.stderr;
    if build.success {
        world.compiled = Some(run(&exe, &[], &root));
    }
}

#[when("I compile it directly with rustc and run it")]
fn when_rustc_direct(world: &mut PatWorld) {
    let path = world.scratch_dir.join("size_check.rs");
    std::fs::write(&path, &world.source).expect("write generated rust source");
    let exe = world.scratch_dir.join("size_check.exe");
    let root = world.repo_root.clone();
    let build = run(
        Path::new("rustc"),
        &["-O", path.to_str().unwrap(), "-o", exe.to_str().unwrap()],
        &root,
    );
    assert!(
        build.success,
        "rustc failed to compile the generated Value-size probe:\n{}",
        build.stderr
    );
    world.interp = Some(run(&exe, &[], &root));
}

#[when("I run it both interpreted and compiled")]
fn when_run_both(world: &mut PatWorld) {
    when_run_interpreted(world);
    when_compile_and_run(world);
}

// ===== Then =====

#[then("it exits successfully")]
fn then_exits_successfully(world: &mut PatWorld) {
    // Prefer whichever run actually happened; a scenario only ever drives one
    // of these unless it explicitly ran both.
    if let Some(c) = &world.compiled {
        assert!(
            c.success,
            "compiled run failed.\nstdout:\n{}\nstderr:\n{}",
            c.stdout, c.stderr
        );
    } else if let Some(i) = &world.interp {
        assert!(
            i.success,
            "interpreted run failed.\nstdout:\n{}\nstderr:\n{}",
            i.stdout, i.stderr
        );
    } else {
        panic!("no run was performed before this assertion");
    }
}

#[then("it compiles successfully")]
fn then_compiles_successfully(world: &mut PatWorld) {
    assert_eq!(
        world.compile_ok,
        Some(true),
        "expected `pat --patc` to succeed, but it failed:\n{}",
        world.compile_stderr
    );
}

#[then(regex = r#"^it prints exactly "(.*)"$"#)]
fn then_prints_exactly(world: &mut PatWorld, expected: String) {
    let got = world
        .compiled
        .as_ref()
        .or(world.interp.as_ref())
        .expect("no run was performed before this assertion");
    assert_eq!(
        got.stdout.trim(),
        expected,
        "unexpected stdout (full stdout: {:?}, stderr: {:?})",
        got.stdout, got.stderr
    );
}

#[then(regex = r#"^stdout contains "(.*)"$"#)]
fn then_stdout_contains(world: &mut PatWorld, needle: String) {
    let got = world
        .compiled
        .as_ref()
        .or(world.interp.as_ref())
        .expect("no run was performed before this assertion");
    assert!(
        got.stdout.contains(&needle),
        "expected stdout to contain {:?}, got:\n{}",
        needle, got.stdout
    );
}

#[then("the interpreted and compiled outputs match exactly")]
fn then_outputs_match(world: &mut PatWorld) {
    let interp = world.interp.as_ref().expect("interpreted run not performed");
    let compiled = world.compiled.as_ref().expect("compiled run not performed");
    assert_eq!(
        interp.stdout, compiled.stdout,
        "interpreted and compiled stdout diverged"
    );
}

#[then("both runs exit successfully")]
fn then_both_succeed(world: &mut PatWorld) {
    let interp = world.interp.as_ref().expect("interpreted run not performed");
    let compiled = world.compiled.as_ref().expect("compiled run not performed");
    assert!(interp.success, "interpreted run failed:\n{}", interp.stderr);
    assert!(compiled.success, "compiled run failed:\n{}", compiled.stderr);
}

#[then(regex = r"^the reported Value size is at most (\d+) bytes$")]
fn then_size_at_most(world: &mut PatWorld, max_bytes: usize) {
    let got = world.interp.as_ref().expect("no run was performed before this assertion");
    let n: usize = got
        .stdout
        .trim()
        .parse()
        .unwrap_or_else(|_| panic!("expected stdout to be a byte count, got {:?}", got.stdout));
    assert!(
        n <= max_bytes,
        "Value size regressed: reported {n} bytes, expected at most {max_bytes}"
    );
}

#[then(regex = r"^the self-hosted suite reports all tests passed$")]
fn then_selftest_all_passed(world: &mut PatWorld) {
    let got = world.interp.as_ref().expect("interpreted run not performed");
    assert!(got.success, "self-hosted suite run failed:\n{}", got.stderr);
    assert!(
        got.stdout.contains("ALL TESTS PASSED"),
        "expected 'ALL TESTS PASSED' in stdout, got:\n{}",
        got.stdout
    );
    assert!(
        got.stdout.contains("0 failed"),
        "expected '0 failed' in stdout, got:\n{}",
        got.stdout
    );
}

#[then(regex = r"^the self-hosted suite reports zero parse errors and every expect/actual pair matches$")]
fn then_selftest_regex_dsl(world: &mut PatWorld) {
    let got = world.interp.as_ref().expect("interpreted run not performed");
    assert!(got.success, "self-hosted suite run failed:\n{}", got.stderr);
    assert!(
        got.stdout.contains("parse errors: 0"),
        "expected 'parse errors: 0' in stdout, got:\n{}",
        got.stdout
    );
    // Every diagnostic line in this suite is shaped "label (expect N): M" --
    // assert N == M for every such line rather than hand-copying each
    // expected value into the feature file (the suite already carries its
    // own expectations; duplicating them here would just be a second place
    // to keep in sync).
    let re = regex_lite_expect_actual(&got.stdout);
    assert!(!re.is_empty(), "no '(expect N): M' lines found in stdout:\n{}", got.stdout);
    for (label, expect, actual) in re {
        assert_eq!(expect, actual, "mismatch for {label:?}: expected {expect}, got {actual}");
    }
}

/// Tiny hand-rolled scanner for `label (expect N): M` lines -- avoids
/// pulling in a regex dependency just for this one assertion.
fn regex_lite_expect_actual(text: &str) -> Vec<(String, i64, i64)> {
    let mut out = Vec::new();
    for line in text.lines() {
        let Some(open) = line.find("(expect ") else { continue };
        let Some(close) = line[open..].find("):") else { continue };
        let label = line[..open].trim().to_string();
        let expect_str = line[open + "(expect ".len()..open + close].trim();
        let actual_str = line[open + close + "):".len()..].trim();
        let (Ok(expect), Ok(actual)) = (expect_str.parse::<i64>(), actual_str.parse::<i64>()) else {
            continue;
        };
        out.push((label, expect, actual));
    }
    out
}

fn main() {
    futures::executor::block_on(PatWorld::run("tests/features"));
}
