use std::fs;
use std::path::Path;
use std::process;
use patlang_runtime::core_evaluator;

fn main() {
    let test_dir = "../native_parser/tests";
    let entries = match fs::read_dir(test_dir) {
        Ok(e) => e,
        Err(e) => {
            eprintln!("Error reading test directory '{}': {}", test_dir, e);
            process::exit(1);
        }
    };

    let mut total = 0;
    let mut passed = 0;
    let mut failed = 0;

    for entry in entries {
        let entry = entry.unwrap();
        let path = entry.path();
        if path.extension().map(|ext| ext == "patlang").unwrap_or(false) {
            total += 1;
            let filename = path.display().to_string();
            let source = match fs::read_to_string(&path) {
                Ok(s) => s,
                Err(e) => {
                    eprintln!("Error reading file '{}': {}", filename, e);
                    failed += 1;
                    continue;
                }
            };
            match core_evaluator::evaluate_patlang_source(&source) {
                Ok(result) => {
                    println!("[PASS] {}: {}", filename, result.message);
                    passed += 1;
                }
                Err(err) => {
                    println!("[FAIL] {}: {}", filename, err.message);
                    failed += 1;
                }
            }
        }
    }

    println!("Test summary: {} total, {} passed, {} failed", total, passed, failed);

    if failed > 0 {
        process::exit(1);
    }
}