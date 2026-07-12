//! Stage 37A: host-function prelude chunking should actually shrink the
//! emitted Rust source text when a program doesn't use a given feature area
//! (networking, OO, logic, the rustc-shelling-out bootstrap hosts).
use patlang_runtime::ir::*;

fn program_calling(host_name: &str, argc: usize) -> Program {
    let mut f = Function { name: "main".into(), ..Default::default() };
    // Push dummy args then call the host function, matching argc.
    for i in 0..argc {
        f.body.push(Instr::Const(Value::Int(i as i64)));
    }
    f.body.push(Instr::CallHost(host_name.into(), argc));
    f.body.push(Instr::Return);
    let mut p = Program::default();
    p.entry = "main".into();
    p.functions.insert("main".into(), f);
    p
}

fn bare_program() -> Program {
    let mut f = Function { name: "main".into(), ..Default::default() };
    f.body.push(Instr::Const(Value::Int(1)));
    f.body.push(Instr::Return);
    let mut p = Program::default();
    p.entry = "main".into();
    p.functions.insert("main".into(), f);
    p
}

#[test]
fn networking_chunk_excluded_unless_used() {
    let cg = RustCodegen::new();

    let bare_src = cg.emit_rust(&bare_program());
    assert!(!bare_src.contains("fn tcp_listen") && !bare_src.contains("\"tcp_listen\""),
        "bare program should not pull in the networking chunk: {}", bare_src);
    assert!(!bare_src.contains("host_call_networking"));

    let tcp_src = cg.emit_rust(&program_calling("tcp_listen", 1));
    assert!(tcp_src.contains("\"tcp_listen\""), "tcp-using program should include tcp_listen's arm");
    assert!(tcp_src.contains("host_call_networking"), "tcp-using program should include the networking chunk");
}

#[test]
fn oo_chunk_excluded_unless_used() {
    let cg = RustCodegen::new();
    let bare_src = cg.emit_rust(&bare_program());
    assert!(!bare_src.contains("host_call_oo"), "bare program should not pull in the oo chunk");

    let oo_src = cg.emit_rust(&program_calling("new", 2));
    assert!(oo_src.contains("host_call_oo"), "new()-using program should include the oo chunk");
}

#[test]
fn logic_chunk_excluded_unless_used() {
    let cg = RustCodegen::new();
    let bare_src = cg.emit_rust(&bare_program());
    assert!(!bare_src.contains("host_call_logic"), "bare program should not pull in the logic chunk");

    let logic_src = cg.emit_rust(&program_calling("fact", 3));
    assert!(logic_src.contains("host_call_logic"), "fact()-using program should include the logic chunk");
    assert!(logic_src.contains("static FACTS"), "logic chunk brings its own FACTS thread_local");
}

#[test]
fn codegen_bootstrap_chunk_excluded_unless_used() {
    let cg = RustCodegen::new();
    let bare_src = cg.emit_rust(&bare_program());
    assert!(!bare_src.contains("host_call_codegen_bootstrap"),
        "bare program should not pull in the codegen_bootstrap chunk");
    assert!(!bare_src.contains("\"rustc_build\""),
        "bare program should not include the rustc_build arm text");

    let bootstrap_src = cg.emit_rust(&program_calling("run_ir", 1));
    assert!(bootstrap_src.contains("host_call_codegen_bootstrap"),
        "run_ir()-using program should include the codegen_bootstrap chunk");
    assert!(bootstrap_src.contains("\"rustc_build\""),
        "codegen_bootstrap chunk brings the rest of the bootstrap arms (rustc_build etc.)");
}

#[test]
fn core_is_always_present_and_all_chunk_selection_is_a_superset() {
    let cg = RustCodegen::new();
    let bare_src = cg.emit_rust(&bare_program());
    // Core essentials always present regardless of what the program calls.
    assert!(bare_src.contains("enum Value"));
    assert!(bare_src.contains("enum Instr"));
    assert!(bare_src.contains("fn display_value"));
    assert!(bare_src.contains("fn main()"));

    let all_src = RustCodegen::prelude_for(&RustCodegen::all_chunks());
    for needle in [
        "host_call_strings_ext", "host_call_collections_handles", "host_call_files",
        "host_call_io_misc", "host_call_oo", "host_call_logic", "host_call_contracts",
        "host_call_networking", "host_call_codegen_bootstrap",
    ] {
        assert!(all_src.contains(needle), "all-chunks prelude missing {}", needle);
    }
}

fn arithmetic_program() -> Program {
    let mut f = Function { name: "main".into(), ..Default::default() };
    f.body.push(Instr::Const(Value::Int(2)));
    f.body.push(Instr::Const(Value::Int(3)));
    f.body.push(Instr::BinOp(BinOpKind::Add));
    f.body.push(Instr::Return);
    let mut p = Program::default();
    p.entry = "main".into();
    p.functions.insert("main".into(), f);
    p
}

#[test]
fn numeric_tower_chunk_included_only_when_arithmetic_present() {
    let cg = RustCodegen::new();

    // Pure Const + Return, no BinOp/UnOp at all: numeric_tower must be
    // excluded, and the emitted source must not contain any bignum text.
    let bare_chunks = RustCodegen::required_chunks(&bare_program());
    assert!(!bare_chunks.contains(&ChunkId::NumericTower),
        "bare program (no numeric BinOp) should not require numeric_tower");
    let bare_src = cg.emit_rust(&bare_program());
    assert!(!bare_src.contains("struct BigIntT"), "bare program should not embed the bignum text: {}", bare_src);
    assert!(!bare_src.contains("struct RationalT"));
    assert!(!bare_src.contains("struct ComplexT"));
    // Still must compile against Int/Float literals.
    assert!(bare_src.contains("Int(i64)"));

    // A program with a numeric BinOp: numeric_tower must be included, and its
    // hand-rolled bignum types must be textually present.
    let arith_chunks = RustCodegen::required_chunks(&arithmetic_program());
    assert!(arith_chunks.contains(&ChunkId::NumericTower),
        "program using a numeric BinOp should require numeric_tower");
    let arith_src = cg.emit_rust(&arithmetic_program());
    assert!(arith_src.contains("struct BigIntT"), "arithmetic program should embed the bignum text");
    assert!(arith_src.contains("struct RationalT"));
    assert!(arith_src.contains("struct ComplexT"));
}

#[test]
fn required_chunks_reports_expected_set() {
    use std::collections::BTreeSet;
    let bare = RustCodegen::required_chunks(&bare_program());
    assert_eq!(bare, BTreeSet::from([ChunkId::Core]));

    let tcp = RustCodegen::required_chunks(&program_calling("tcp_listen", 1));
    assert_eq!(tcp, BTreeSet::from([ChunkId::Core, ChunkId::Networking]));

    // contract_check's success path now records a `contract_holds` fact via
    // `RULES`/`LogicRule`, both declared only in PRELUDE_LOGIC's text -- so
    // any program calling contract_check needs Logic too (the (Contracts,
    // Logic) CROSS_CHUNK_EDGES entry), same rationale as (Oo, Logic) above.
    let contracts = RustCodegen::required_chunks(&program_calling("contract_check", 4));
    assert_eq!(contracts, BTreeSet::from([ChunkId::Core, ChunkId::Contracts, ChunkId::Logic]));
}

#[test]
fn math_chunk_pulls_in_numeric_tower_via_cross_chunk_edge() {
    // Stage 39: a program calling ONLY sqrt() (no ordinary arithmetic BinOp
    // anywhere) would, under Stage 38's rule alone, get the FAST plain-
    // Number(f64) Value definition -- but math's chunk text needs the full
    // tower's BigInt/Rational/Complex variants to exist. required_chunks must
    // select numeric_tower too, via the (Math, NumericTower) CROSS_CHUNK_EDGES
    // entry.
    use std::collections::BTreeSet;
    let cg = RustCodegen::new();

    let sqrt_only = program_calling("sqrt", 1);
    let chunks = RustCodegen::required_chunks(&sqrt_only);
    assert_eq!(chunks, BTreeSet::from([ChunkId::Core, ChunkId::Math, ChunkId::NumericTower]),
        "sqrt-only program should require both math and numeric_tower");

    let sqrt_src = cg.emit_rust(&sqrt_only);
    assert!(sqrt_src.contains("struct BigIntT"), "math chunk's cross-edge should pull in the tower's bignum text");
    assert!(sqrt_src.contains("fn host_call_math"));

    // Neither arithmetic nor any math call: neither chunk should be present.
    let bare_chunks = RustCodegen::required_chunks(&bare_program());
    assert!(!bare_chunks.contains(&ChunkId::Math));
    assert!(!bare_chunks.contains(&ChunkId::NumericTower));
    let bare_src = cg.emit_rust(&bare_program());
    assert!(!bare_src.contains("fn host_call_math"));
    assert!(!bare_src.contains("struct BigIntT"));
}
