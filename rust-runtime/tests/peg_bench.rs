// Perf evaluation for the PEG grammar validator (Slice 2) vs. the real
// hand-written recursive-descent parser, over the actual codebase corpus.
// Not a pass/fail test -- prints a wall-clock ratio so the numbers land
// in `cargo test -- --nocapture` output for a human decision on whether
// the PEG approach is fast enough to ever consider replacing a real
// parser with. Ignored by default (slow, and its point is the printed
// report, not an assertion) -- run explicitly with:
//   cargo test --release --manifest-path rust-runtime/Cargo.toml \
//     --test peg_bench -- --ignored --nocapture
use patlang_runtime::ir::peg::{accepts, load_grammar};
use patlang_runtime::parser::Parser;
use patlang_runtime::preprocess::expand_includes;
use std::fs;
use std::path::Path;
use std::time::Instant;

// `include "..."` is resolved by the real pipeline's preprocessor before
// either parser ever sees the source (see preprocess.rs) -- applying it
// here too keeps the benchmark corpus representative of what each parser
// actually has to handle in practice, rather than penalizing whichever
// engine recovers worse from a directive neither is meant to parse.
fn collect_patlang_files(dir: &Path, out: &mut Vec<String>) {
    let Ok(entries) = fs::read_dir(dir) else { return };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
            if name == "build" || name.starts_with('.') {
                continue;
            }
            collect_patlang_files(&path, out);
        } else if path.extension().and_then(|e| e.to_str()) == Some("patlang") {
            if let Ok(text) = fs::read_to_string(&path) {
                let base = path.parent().unwrap_or(Path::new("."));
                if let Ok(expanded) = expand_includes(&text, base) {
                    out.push(expanded);
                }
            }
        }
    }
}

#[test]
#[ignore]
fn peg_vs_native_parser_wall_clock_on_the_real_corpus() {
    let repo_root = Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/.."));
    let mut sources = Vec::new();
    collect_patlang_files(&repo_root.join("self_hosting"), &mut sources);
    collect_patlang_files(&repo_root.join("rust-runtime"), &mut sources);
    assert!(sources.len() > 50, "expected a real corpus, got {} files", sources.len());

    let grammar_path = repo_root.join("docs/grammar/patlang-full.peg");
    let grammar_source = fs::read_to_string(&grammar_path).expect("read grammar file");
    let rules = load_grammar(&grammar_source);

    const REPEATS: usize = 5;

    let native_start = Instant::now();
    let mut native_ok = 0usize;
    for _ in 0..REPEATS {
        for src in &sources {
            if let Ok(mut p) = Parser::new(src) {
                if p.parse().is_ok() {
                    native_ok += 1;
                }
            }
        }
    }
    let native_elapsed = native_start.elapsed();

    let peg_start = Instant::now();
    let mut peg_ok = 0usize;
    for _ in 0..REPEATS {
        for src in &sources {
            if accepts(&rules, "Program", src) {
                peg_ok += 1;
            }
        }
    }
    let peg_elapsed = peg_start.elapsed();

    let ratio = peg_elapsed.as_secs_f64() / native_elapsed.as_secs_f64();
    println!(
        "corpus: {} files x {} repeats\n\
         native parser.rs: {:?} total ({} OK)\n\
         PEG engine:        {:?} total ({} OK)\n\
         PEG is {:.1}x the native parser's wall-clock time",
        sources.len(),
        REPEATS,
        native_elapsed,
        native_ok,
        peg_elapsed,
        peg_ok,
        ratio
    );
}
