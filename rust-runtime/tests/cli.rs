use std::fs;
use std::process::Command;

// Exercise CLI usage error path (no args)
#[test]
fn test_cli_usage_no_args() {
    let exe = env!("CARGO_BIN_EXE_pat");
    let out = Command::new(exe)
        .output()
        .expect("failed to run pat binary");
    assert!(!out.status.success());
    let stderr = String::from_utf8_lossy(&out.stderr);
    assert!(stderr.contains("Usage:"));
}

// Exercise CLI success path: run a tiny program file and capture stdout
#[test]
fn test_cli_runs_file_and_prints() {
    let exe = env!("CARGO_BIN_EXE_pat");
    let dir = std::env::temp_dir();
    let path = dir.join("patlang_cli_test.pat");
    fs::write(&path, "print(\"ok\")\n").expect("write temp pat file");

    let out = Command::new(exe)
        .arg(&path)
        .output()
        .expect("failed to run pat binary");
    assert!(out.status.success());
    let stdout = String::from_utf8_lossy(&out.stdout);
    assert!(stdout.contains("ok"));
}

// Exercise CLI file error path
#[test]
fn test_cli_error_missing_file() {
    let exe = env!("CARGO_BIN_EXE_pat");
    let out = Command::new(exe)
        .arg("this_file_should_not_exist_12345.pat")
        .output()
        .expect("failed to run pat binary");
    assert!(!out.status.success());
    let stderr = String::from_utf8_lossy(&out.stderr);
    assert!(stderr.contains("Error reading file"));
}
