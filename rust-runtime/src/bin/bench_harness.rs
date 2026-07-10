// PatLang vs Rust benchmark harness.
//
// For each category, builds (where applicable) and runs three variants:
//   (a) hand-written Rust, compiled via bare `rustc -O` (matching how
//       compiled PatLang programs are built -- see `compile_source_to_exe`
//       in `rust-runtime/src/ir/hosts.rs`, so build settings aren't a
//       confound),
//   (b) PatLang interpreted via `pat --ir-run`,
//   (c) PatLang compiled to native via `pat --patc`.
//
// Each variant is run REPEAT times (first run discarded as warm-up), wall
// time recorded via `Instant`, and peak process memory sampled periodically
// via `sysinfo` while the child runs. Results are written to
// `rust-runtime/BENCHMARKS.md`.
//
// Run with: cargo run --release --bin bench_harness
// (requires `pat` already built in release mode first: cargo build --release --bin pat)

use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Child, Command};
use std::time::{Duration, Instant};
use sysinfo::{Pid, ProcessesToUpdate, System};

const REPEAT: u32 = 10;
const SAMPLE_INTERVAL: Duration = Duration::from_millis(2);

struct Category {
    name: &'static str,
    rust_src: &'static str,     // relative to rust-runtime/
    patlang_src: &'static str,  // relative to repo root
}

const CATEGORIES: &[Category] = &[
    Category { name: "fib(32) recursive", rust_src: "benches_src/fib_rust.rs", patlang_src: "self_hosting/benchmarks/bench_fib.patlang" },
    Category { name: "iterative sum loop (1..25,000,000)", rust_src: "benches_src/sumloop_rust.rs", patlang_src: "self_hosting/benchmarks/bench_sumloop.patlang" },
    Category { name: "list/vector build-and-sum (2,000,000 elements)", rust_src: "benches_src/listbuild_rust.rs", patlang_src: "self_hosting/benchmarks/bench_listbuild.patlang" },
    Category { name: "string concatenation (400,000 appends)", rust_src: "benches_src/strconcat_rust.rs", patlang_src: "self_hosting/benchmarks/bench_strconcat.patlang" },
    Category { name: "quicksort (50,000 elements)", rust_src: "benches_src/sort_rust.rs", patlang_src: "self_hosting/benchmarks/bench_sort.patlang" },
    Category { name: "object dispatch + events (50,000 objects/events)", rust_src: "benches_src/oo_events_rust.rs", patlang_src: "self_hosting/benchmarks/bench_oo_events.patlang" },
];

struct RunResult {
    median_ms: f64,
    min_ms: f64,
    peak_mem_bytes: u64,
}

fn rust_runtime_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

fn repo_root() -> PathBuf {
    rust_runtime_dir().parent().expect("rust-runtime has a parent dir").to_path_buf()
}

fn pat_exe() -> PathBuf {
    let p = rust_runtime_dir().join("target/release/pat.exe");
    if !p.exists() {
        panic!("pat.exe not found at {:?} -- build it first: cargo build --release --bin pat", p);
    }
    p
}

/// Run `cmd`/`args` as a child process, sampling its memory periodically
/// until it exits. Returns (wall_ms, peak_mem_bytes). `sys` is a
/// long-lived, already-"warm" System shared across every run in the
/// harness -- sysinfo's refresh_processes has a large (measured: 300ms+)
/// one-time cold-start cost on the first call to a fresh System, which
/// would otherwise dwarf most benchmark runtimes if paid per-run.
fn run_and_sample(sys: &mut System, cmd: &Path, args: &[&str], cwd: &Path) -> (f64, u64) {
    let t0 = Instant::now();
    let mut child: Child = Command::new(cmd)
        .args(args)
        .current_dir(cwd)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn()
        .unwrap_or_else(|e| panic!("failed to spawn {:?} {:?}: {}", cmd, args, e));

    let pid = Pid::from_u32(child.id());
    let mut peak: u64 = 0;

    loop {
        sys.refresh_processes(ProcessesToUpdate::Some(&[pid]));
        if let Some(proc) = sys.process(pid) {
            let mem = proc.memory(); // bytes, per sysinfo docs (as of 0.3x)
            if mem > peak {
                peak = mem;
            }
        }
        match child.try_wait() {
            Ok(Some(_status)) => break,
            Ok(None) => std::thread::sleep(SAMPLE_INTERVAL),
            Err(e) => panic!("error waiting for child: {}", e),
        }
    }
    let elapsed = t0.elapsed().as_secs_f64() * 1000.0;
    (elapsed, peak)
}

fn median(mut v: Vec<f64>) -> f64 {
    v.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let n = v.len();
    if n % 2 == 1 { v[n / 2] } else { (v[n / 2 - 1] + v[n / 2]) / 2.0 }
}

fn bench(sys: &mut System, cmd: &Path, args: &[&str], cwd: &Path) -> RunResult {
    // Discard the first run (cold-cache warm-up), then REPEAT more.
    let _ = run_and_sample(sys, cmd, args, cwd);
    let mut times = Vec::with_capacity(REPEAT as usize);
    let mut peak_mem: u64 = 0;
    for _ in 0..REPEAT {
        let (ms, mem) = run_and_sample(sys, cmd, args, cwd);
        times.push(ms);
        if mem > peak_mem { peak_mem = mem; }
    }
    let min_ms = times.iter().cloned().fold(f64::INFINITY, f64::min);
    RunResult { median_ms: median(times), min_ms, peak_mem_bytes: peak_mem }
}

fn fmt_ms(ms: f64) -> String {
    if ms >= 1000.0 { format!("{:.2} s", ms / 1000.0) } else { format!("{:.1} ms", ms) }
}

fn fmt_mem(bytes: u64) -> String {
    format!("{:.2} MB", bytes as f64 / (1024.0 * 1024.0))
}

fn main() {
    let root = repo_root();
    let rt_dir = rust_runtime_dir();
    let pat = pat_exe();
    let bench_out_dir = rt_dir.join("target/bench_out");
    fs::create_dir_all(&bench_out_dir).expect("create bench_out dir");

    // One warm System reused for the whole run -- see run_and_sample's doc
    // comment for why (sysinfo's first refresh_processes call on a fresh
    // System has a large, one-time cold-start cost).
    let mut sys = System::new();
    sys.refresh_processes(ProcessesToUpdate::All);

    let mut report = String::new();
    report.push_str("# PatLang vs Rust: benchmark results\n\n");
    report.push_str(&format!(
        "Generated by `cargo run --release --bin bench_harness`. Each variant run {} times (first run discarded as warm-up); median and min wall-clock time reported, plus peak process memory (working set) sampled while each run executes.\n\n",
        REPEAT
    ));
    report.push_str("All three variants for a category run the *same algorithm*. Rust and PatLang-compiled are both built with `-O` (no `Cargo.toml`/no dependencies for either — bare `rustc`, matching exactly how the PatLang toolchain itself compiles programs, see `compile_source_to_exe` in `rust-runtime/src/ir/hosts.rs`). PatLang-interpreted runs via `pat --ir-run` with no compilation step.\n\n");
    report.push_str("**Methodology note on memory sampling**: memory is sampled by polling the child process's working set from an external harness process (`sysinfo`), not via any in-process instrumentation. On this machine, a single targeted-PID refresh has a measured floor of roughly 20-80ms of latency, so every benchmark's workload size was chosen to run for at least a few hundred milliseconds even in its fastest (Rust) variant, giving the sampler multiple genuine opportunities to observe the process rather than missing it entirely between spawn and exit. Reported memory figures should be read as \"peak observed via periodic external polling,\" not an exact high-water mark.\n\n");

    for (i, cat) in CATEGORIES.iter().enumerate() {
        eprintln!("=== [{}/{}] {} ===", i + 1, CATEGORIES.len(), cat.name);
        report.push_str(&format!("## {}\n\n", cat.name));

        let rust_src_path = rt_dir.join(cat.rust_src);
        let rust_exe = bench_out_dir.join(format!("{}_rust.exe", i));
        eprintln!("  building rust baseline...");
        let status = Command::new("rustc")
            .arg("-O")
            .arg(&rust_src_path)
            .arg("-o")
            .arg(&rust_exe)
            .status()
            .expect("failed to invoke rustc");
        if !status.success() {
            panic!("rustc failed to build {:?}", rust_src_path);
        }

        eprintln!("  compiling patlang -> native...");
        let patlang_exe = bench_out_dir.join(format!("{}_patlang.exe", i));
        let status = Command::new(&pat)
            .arg("--patc")
            .arg(&root.join(cat.patlang_src))
            .arg("--out")
            .arg(&patlang_exe)
            .current_dir(&root)
            .status()
            .expect("failed to invoke pat --patc");
        if !status.success() {
            panic!("pat --patc failed to compile {}", cat.patlang_src);
        }

        eprintln!("  running rust baseline x{}...", REPEAT + 1);
        let rust_result = bench(&mut sys, &rust_exe, &[], &root);

        eprintln!("  running patlang interpreted x{}...", REPEAT + 1);
        let interp_result = bench(&mut sys, &pat, &["--ir-run", cat.patlang_src], &root);

        eprintln!("  running patlang compiled x{}...", REPEAT + 1);
        let compiled_result = bench(&mut sys, &patlang_exe, &[], &root);

        report.push_str("| variant | median | min | peak memory |\n");
        report.push_str("|---|---|---|---|\n");
        report.push_str(&format!(
            "| Rust (native) | {} | {} | {} |\n",
            fmt_ms(rust_result.median_ms), fmt_ms(rust_result.min_ms), fmt_mem(rust_result.peak_mem_bytes)
        ));
        report.push_str(&format!(
            "| PatLang (compiled native) | {} | {} | {} |\n",
            fmt_ms(compiled_result.median_ms), fmt_ms(compiled_result.min_ms), fmt_mem(compiled_result.peak_mem_bytes)
        ));
        report.push_str(&format!(
            "| PatLang (interpreted, `--ir-run`) | {} | {} | {} |\n",
            fmt_ms(interp_result.median_ms), fmt_ms(interp_result.min_ms), fmt_mem(interp_result.peak_mem_bytes)
        ));
        report.push_str("\n");
    }

    let out_path = root.join("rust-runtime/BENCHMARKS.md");
    fs::write(&out_path, &report).expect("write BENCHMARKS.md");
    eprintln!("wrote {:?}", out_path);
}
