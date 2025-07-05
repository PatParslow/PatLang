mod event_system;
mod message_queue;
mod error_handler;
mod secure_distributed_code_support;


use std::env;
use std::process;
use std::fs;
use patlang_runtime::core_evaluator;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: {} <file.pat>", args[0]);
        process::exit(1);
    }
    let filename = &args[1];
    let source = match fs::read_to_string(filename) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Error reading file '{}': {}", filename, e);
            process::exit(1);
        }
    };
    match core_evaluator::evaluate_patlang_source(&source) {
        Ok(result) => println!("{}", result.message),
        Err(err) => {
            eprintln!("{}", err.message);
            process::exit(1);
        }
    }
}
