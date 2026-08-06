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

/// Ensures `patc1.exe` exists at the repo root and is up to date, building
/// it via `build_patc1.patlang` if needed -- cheap when nothing changed
/// (fingerprint-cached, see build_patc1.patlang's own header comment), so
/// safe to call from every scenario that needs the self-hosted compiler's
/// own compiled binary (as opposed to the native `pat` binary under test
/// everywhere else in this file).
fn ensure_patc1_exe(root: &Path) -> PathBuf {
    let exe = if cfg!(windows) { root.join("patc1.exe") } else { root.join("patc1") };
    let build = run(&pat_exe(), &["--ir-run", "self_hosting/build_patc1.patlang"], root);
    assert!(
        build.success && exe.exists(),
        "failed to build patc1.exe via build_patc1.patlang:\nstdout:\n{}\nstderr:\n{}",
        build.stdout, build.stderr
    );
    exe
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
    selfhost_interp: Option<RunResult>,
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
            selfhost_interp: None,
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
    // `main()` used to live statically inside PRELUDE_CORE's text (and this
    // test replaced its literal body with a probe); it now lives only in
    // the per-program text `emit_rust` generates (see the patlang-patc-
    // prelude-chunk-linking-investigation memory -- `main()` calls
    // `build_program()`/`call_dispatch`, both genuinely per-program, so it
    // can no longer be part of the shared prelude text once that's meant to
    // be precompiled once and reused). `prelude_for`'s output now has NO
    // `main()` at all, so the probe is simply appended, not swapped in.
    let probe_main = "fn main() { println!(\"{}\", std::mem::size_of::<Value>()); }\n";
    assert!(
        !prelude.contains("fn main("),
        "prelude_for's output unexpectedly contains a main() again -- update given_value_module, which now appends its own probe main() assuming there isn't one already"
    );
    world.source = prelude + probe_main;
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
        // utf8_selftest.patlang and lean_selftest.patlang are self-contained
        // scripts that `include` their own library dependencies.
        "utf8" => read("self_hosting/utf8_selftest.patlang"),
        "lean" => read("self_hosting/lean_selftest.patlang"),
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

/// Runs the scenario's source through patc1.exe's `lower` + `interpret`
/// subcommands -- the self-hosted meta-circular interpreter
/// (`self_hosting/lib/interp.patlang`), NOT the native `--ir-run` path.
/// `interpret` prints only the program's final RETURN value (it has no
/// notion of "run to completion and let CallHost print() calls happen
/// mid-program the way --ir-run's own main() does" beyond the print calls
/// the program itself makes) -- scenarios written for this step should end
/// with an explicit `return <expr>` and compare against that, mirroring
/// the pattern already used by patc1_main.patlang's own `interpret`
/// subcommand and its manual smoke tests.
#[when("I run it through the self-hosted meta-circular interpreter")]
fn when_run_selfhost_interp(world: &mut PatWorld) {
    let path = world.write_source();
    let root = world.repo_root.clone();
    let patc1 = ensure_patc1_exe(&root);
    let ir_path = world.scratch_dir.join(format!("scenario_{}.ir", world.scenario_id));
    let lower = run(&patc1, &["lower", path.to_str().unwrap(), ir_path.to_str().unwrap()], &root);
    assert!(
        ir_path.exists(),
        "patc1.exe lower did not produce an .ir file:\nstdout:\n{}\nstderr:\n{}",
        lower.stdout, lower.stderr
    );
    world.selfhost_interp = Some(run(&patc1, &["interpret", ir_path.to_str().unwrap()], &root));
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

#[then("the self-hosted interpreter's output matches the expected value")]
fn then_selfhost_interp_matches_expected(world: &mut PatWorld, step: &Step) {
    let expected = step
        .docstring
        .clone()
        .expect("expected a docstring attached to this step")
        .trim()
        .to_string();
    let got = world
        .selfhost_interp
        .as_ref()
        .expect("self-hosted interpreter run not performed");
    assert!(
        got.success,
        "patc1.exe interpret failed:\nstdout:\n{}\nstderr:\n{}",
        got.stdout, got.stderr
    );
    assert_eq!(
        got.stdout.trim(),
        expected,
        "self-hosted interpreter's output didn't match -- full stdout:\n{}\nstderr:\n{}",
        got.stdout, got.stderr
    );
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
