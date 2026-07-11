//! Intermediate Representation (IR) module for Patlang.
//! This is a minimal, typed IR plus a tiny interpreter for bootstrapping.

pub mod types;
pub mod ops;
pub mod interpreter;
pub mod lowering;
pub mod logging;
pub mod file_ops;
pub mod codegen;
pub mod hosts;
pub mod numeric;
pub mod bignum_template;
pub mod rational_complex_template;
pub mod fiber;

pub use types::*;
pub use ops::*;
pub use interpreter::*;
pub use lowering::*;
pub use codegen::*;
