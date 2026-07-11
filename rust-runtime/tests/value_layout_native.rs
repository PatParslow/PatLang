//! Direct, in-process companion to tests/features/value_layout.feature.
//! The interpreter's own `Value` size is a property of this crate's
//! compiled types, not something a black-box CLI scenario can observe, so
//! it's asserted here instead of via a Gherkin step. See that feature file
//! for the compiled-path (PRELUDE_VALUE_FAST / PRELUDE_NUMERIC_TOWER)
//! counterparts, which mirror this same regression class.

#[test]
fn interpreter_value_is_64_bytes() {
    let size = std::mem::size_of::<patlang_runtime::ir::types::Value>();
    assert_eq!(
        size, 64,
        "interpreter Value size changed (was 64 bytes) -- if a variant grew \
         intentionally, update this bound; if not, a newly-added variant is \
         probably storing something inline that should be boxed instead"
    );
}
