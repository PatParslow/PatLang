// Logging and debug utilities for patlang native runtime

use std::fs::OpenOptions;
use std::io::Write;

pub fn log_to_file(filename: &str, msg: &str) {
	if let Ok(mut f) = OpenOptions::new().create(true).append(true).open(filename) {
		let _ = writeln!(f, "{}", msg);
	}
}

pub fn debug(msg: &str) {
	println!("[DEBUG] {}", msg);
}
// Logging and debug utilities for patlang native runtime

// ...to be filled in from codegen.rs...
