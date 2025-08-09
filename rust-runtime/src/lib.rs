//! patlang_runtime library crate root.
//! Exports all core modules for use in integration tests and external crates.
#![cfg_attr(debug_assertions, allow(dead_code, unused_imports, unused_variables, unused_mut))]
pub mod ast;
pub mod lexer;

pub mod core_evaluator;
pub mod memory_manager;
pub mod goal_system;
pub mod type_system;
pub mod inferencing_engine;
pub mod scope_manager;
pub mod object_model;
pub mod error_handler;
pub mod event_system;
pub mod message_queue;
pub mod secure_distributed_code_support;
pub mod arithmetic;
pub mod string;
pub mod function;
pub mod object;
pub mod reasoning;
pub mod parser;
pub mod logic_engine;
pub mod runtime_integration;
pub mod builtins;
pub mod ir;