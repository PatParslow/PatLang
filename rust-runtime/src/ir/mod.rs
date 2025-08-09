//! Intermediate Representation (IR) module for Patlang.
//! This is a minimal, typed IR plus a tiny interpreter for bootstrapping.

pub mod types;
pub mod ops;
pub mod interpreter;
pub mod lowering;
pub mod codegen;

pub use types::*;
pub use ops::*;
pub use interpreter::*;
pub use lowering::*;
pub use codegen::*;
