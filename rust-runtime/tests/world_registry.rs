// Guards for `world_run` (the clean nested interpreter).
//
// world_run swaps every global store a program can touch. The classic way
// that goes wrong is a new `thread_local!`/`static` store being added later
// and forgotten in the swap list, so a "clean" run silently leaks it. These
// tests read the sources as text and fail when a declared store is neither
// swapped nor on the explicit not-swapped list.

use std::collections::BTreeSet;
use std::fs;
use std::path::PathBuf;

fn repo_file(rel: &str) -> String {
    let mut p = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    p.push(rel);
    fs::read_to_string(&p).unwrap_or_else(|e| panic!("read {}: {}", p.display(), e))
}

/// Names of every `static NAME:` declaration on a non-comment line.
fn declared_stores(src: &str) -> BTreeSet<String> {
    let mut out = BTreeSet::new();
    for line in src.lines() {
        let t = line.trim_start();
        if t.starts_with("//") { continue; }
        let t = t.strip_prefix("pub(crate) ").or_else(|| t.strip_prefix("pub ")).unwrap_or(t);
        if let Some(rest) = t.strip_prefix("static ") {
            let name: String = rest.chars().take_while(|c| c.is_ascii_uppercase() || c.is_ascii_digit() || *c == '_').collect();
            if !name.is_empty() && rest[name.len()..].trim_start().starts_with(':') {
                out.insert(name);
            }
        }
    }
    out
}

/// Stores named in a swap macro invocation, e.g. `swap_local!(r, VECS, ...)`.
fn swapped_stores(src: &str, macros: &[&str]) -> BTreeSet<String> {
    let mut out = BTreeSet::new();
    for line in src.lines() {
        let t = line.trim_start();
        if t.starts_with("//") { continue; }
        for m in macros {
            if let Some(rest) = t.strip_prefix(&format!("{}!(", m)) {
                // (restores, NAME, ...)
                let mut parts = rest.splitn(3, ',');
                let _ = parts.next();
                if let Some(name) = parts.next() {
                    let name = name.trim().trim_end_matches(|c: char| !(c.is_ascii_alphanumeric() || c == '_')).to_string();
                    if !name.is_empty() { out.insert(name); }
                }
            }
        }
    }
    out
}

fn undeclared(src: &str, macros: &[&str], not_swapped: &[&str]) -> Vec<String> {
    let swapped = swapped_stores(src, macros);
    declared_stores(src)
        .into_iter()
        .filter(|n| !swapped.contains(n) && !not_swapped.contains(&n.as_str()))
        .collect()
}

// Stores world_run manages itself or deliberately leaves alone:
//  CAPTURE/STEP_BUDGET      set and restored by world_run directly
//  WORLD_LOCK/WORLD_DEPTH   the run-exclusion machinery itself
//  RULE_RENAME_COUNTER/SEQ  monotonic uniqueness counters, no observable state
const HOSTS_NOT_SWAPPED: &[&str] = &["CAPTURE", "STEP_BUDGET", "WORLD_LOCK", "WORLD_DEPTH", "RULE_RENAME_COUNTER", "SEQ"];

// Prelude extras: fiber registry is left alone (world_run refuses to run while
// a fiber is alive); DISPATCH_FALLBACK is the host-dispatch hook the program's
// own main() installs, which a nested run must keep using.
const PRELUDE_NOT_SWAPPED: &[&str] = &[
    "CAPTURE", "STEP_BUDGET", "WORLD_LOCK", "WORLD_DEPTH", "RULE_RENAME_COUNTER",
    "REGISTRY", "NEXT", "CURRENT_FIBER", "DISPATCH_FALLBACK",
];

#[test]
fn every_native_store_is_swapped_by_world_run() {
    let src = repo_file("src/ir/hosts.rs");
    let missing = undeclared(&src, &["swap_local", "swap_global"], HOSTS_NOT_SWAPPED);
    assert!(missing.is_empty(),
        "stores declared in ir/hosts.rs but not swapped in world_enter (add a swap_local!/swap_global! line, or list it as deliberately not swapped in tests/world_registry.rs): {:?}", missing);
}

#[test]
fn every_prelude_store_is_swapped_by_world_run() {
    let src = repo_file("src/ir/codegen.rs");
    let missing = undeclared(&src, &["rt_swap_local", "rt_swap_shared"], PRELUDE_NOT_SWAPPED);
    assert!(missing.is_empty(),
        "stores declared in the codegen.rs prelude but not swapped in rt_world_run (add an rt_swap_local!/rt_swap_shared! line, or list it as deliberately not swapped in tests/world_registry.rs): {:?}", missing);
}

#[test]
fn the_lint_catches_a_forgotten_store() {
    let src = "thread_local! {\n    static VECS: RefCell<Vec<i32>> = RefCell::new(Vec::new());\n    static NEW_STORE: RefCell<Vec<i32>> = RefCell::new(Vec::new());\n}\nfn world_enter() {\n    swap_local!(r, VECS, Vec::new());\n}\n";
    assert_eq!(undeclared(src, &["swap_local"], &[]), vec!["NEW_STORE".to_string()]);
    assert!(undeclared(src, &["swap_local"], &["NEW_STORE"]).is_empty());
}

/// Every host in HOST_CHUNK_TABLE must have its dispatch text in the
/// self-hosted mirror (runtime_rs.patlang) and a chunk mapping in
/// codegen.patlang, or a program compiled by the self-hosted toolchain cannot
/// call it. (runtime_rs.patlang is regenerated from codegen.rs; this catches a
/// forgotten regen or a missed host_chunk_of entry.)
#[test]
fn host_chunk_table_names_exist_in_the_self_hosted_mirror() {
    let rs = repo_file("src/ir/codegen.rs");
    let mirror = repo_file("../self_hosting/lib/runtime_rs.patlang");
    let cg = repo_file("../self_hosting/lib/codegen.patlang");
    let start = rs.find("HOST_CHUNK_TABLE: &[(&str, ChunkId)] = &[").expect("HOST_CHUNK_TABLE not found");
    let body = &rs[start..];
    let end = body.find("];").expect("HOST_CHUNK_TABLE end not found");
    let mut names = Vec::new();
    for line in body[..end].lines() {
        let t = line.trim();
        if let Some(rest) = t.strip_prefix("(\"") {
            if let Some(q) = rest.find('"') { names.push(rest[..q].to_string()); }
        }
    }
    assert!(names.len() > 50, "parsed only {} HOST_CHUNK_TABLE entries", names.len());
    let mut missing_mirror = Vec::new();
    let mut missing_cg = Vec::new();
    for n in &names {
        if !mirror.contains(&format!("\\\"{}\\\"", n)) { missing_mirror.push(n.clone()); }
        if !cg.contains(&format!("name == \"{}\" then return", n)) { missing_cg.push(n.clone()); }
    }
    assert!(missing_mirror.is_empty(), "HOST_CHUNK_TABLE names absent from runtime_rs.patlang (run tools/regen_runtime_rs.py): {:?}", missing_mirror);
    assert!(missing_cg.is_empty(), "HOST_CHUNK_TABLE names absent from codegen.patlang host_chunk_of: {:?}", missing_cg);
}
