// Stage 39 — math library primitives, interpreter-driven (no rustc). Mirrors
// the idiom in tests/numeric_tower.rs: build a tiny Program calling a single
// host function via Instr::CallHost, run it through Interpreter::run with the
// standard hosts registered.
use patlang_runtime::ir::*;
use patlang_runtime::ir::hosts::register_stage0_shims;

fn call_host(name: &str, args: Vec<Value>) -> Value {
    let argc = args.len();
    let mut f = Function { name: "main".into(), ..Default::default() };
    for a in args {
        f.body.push(Instr::Const(a));
    }
    f.body.push(Instr::CallHost(name.into(), argc));
    f.body.push(Instr::Return);
    let mut program = Program::default();
    program.entry = "main".into();
    program.functions.insert("main".into(), f);
    let mut interp = Interpreter::new();
    register_stage0_shims(&mut interp);
    interp.run(&program).expect("run ok")
}

#[test]
fn sqrt_perfect_square_is_exact_int() {
    let v = call_host("sqrt", vec![Value::Int(4)]);
    assert_eq!(v, Value::Int(2), "sqrt(4) should be an exact Int, got {:?}", v);
}

#[test]
fn sqrt_non_perfect_square_is_inexact_float_in_range() {
    let v = call_host("sqrt", vec![Value::Int(2)]);
    match v {
        Value::Float(f) => assert!((f - std::f64::consts::SQRT_2).abs() < 1e-9, "sqrt(2) = {}", f),
        other => panic!("expected Float for sqrt(2), got {:?}", other),
    }
}

#[test]
fn sqrt_negative_produces_complex() {
    // The doc's named acceptance case: sqrt(-4) must construct Complex(0, 2).
    let v = call_host("sqrt", vec![Value::Int(-4)]);
    match &v {
        Value::Complex(re, im) => {
            assert_eq!(**re, Value::Int(0));
            assert_eq!(**im, Value::Int(2));
        }
        other => panic!("expected Complex for sqrt(-4), got {:?}", other),
    }
    assert_eq!(patlang_runtime::ir::ops::v_to_string(&v), "0+2i");
}

#[test]
fn sqrt_negative_non_perfect_square_produces_complex_with_float_imaginary() {
    let v = call_host("sqrt", vec![Value::Int(-2)]);
    match v {
        Value::Complex(re, im) => {
            assert_eq!(*re, Value::Int(0));
            match *im {
                Value::Float(f) => assert!((f - std::f64::consts::SQRT_2).abs() < 1e-9),
                other => panic!("expected Float imaginary part, got {:?}", other),
            }
        }
        other => panic!("expected Complex for sqrt(-2), got {:?}", other),
    }
}

#[test]
fn pow_exact_integer_exponent() {
    let v = call_host("pow", vec![Value::Int(2), Value::Int(10)]);
    assert_eq!(v, Value::Int(1024));
}

#[test]
fn pow_triggers_bigint_promotion_on_overflow() {
    // 2^100 vastly exceeds i64 range; must promote to BigInt exactly, not
    // wrap around or fall back to a lossy float.
    let v = call_host("pow", vec![Value::Int(2), Value::Int(100)]);
    match v {
        Value::BigInt(n) => assert_eq!(n.to_string(), "1267650600228229401496703205376"),
        other => panic!("expected BigInt for 2^100, got {:?}", other),
    }
}

#[test]
fn pow_non_integer_exponent_falls_back_to_float() {
    let v = call_host("pow", vec![Value::Int(2), Value::Float(0.5)]);
    match v {
        Value::Float(f) => assert!((f - std::f64::consts::SQRT_2).abs() < 1e-9),
        other => panic!("expected Float for 2^0.5, got {:?}", other),
    }
}

#[test]
fn floor_ceil_round_trunc_are_exact_on_rational() {
    // 7/2 = 3.5
    let r = |n: i64, d: i64| Value::Rational(num_bigint::BigInt::from(n), num_bigint::BigInt::from(d));
    assert_eq!(call_host("floor", vec![r(7, 2)]), Value::Int(3));
    assert_eq!(call_host("ceil", vec![r(7, 2)]), Value::Int(4));
    assert_eq!(call_host("round", vec![r(7, 2)]), Value::Int(4));
    assert_eq!(call_host("trunc", vec![r(7, 2)]), Value::Int(3));

    // -7/2 = -3.5
    assert_eq!(call_host("floor", vec![r(-7, 2)]), Value::Int(-4));
    assert_eq!(call_host("ceil", vec![r(-7, 2)]), Value::Int(-3));
    assert_eq!(call_host("round", vec![r(-7, 2)]), Value::Int(-4));
    assert_eq!(call_host("trunc", vec![r(-7, 2)]), Value::Int(-3));
}

#[test]
fn abs_on_complex_is_modulus() {
    // |3+4i| = 5
    let c = Value::Complex(Box::new(Value::Int(3)), Box::new(Value::Int(4)));
    let v = call_host("abs", vec![c]);
    assert_eq!(v, Value::Int(5));
}

#[test]
fn abs_on_reals_is_exact() {
    assert_eq!(call_host("abs", vec![Value::Int(-7)]), Value::Int(7));
    assert_eq!(call_host("abs", vec![Value::Int(7)]), Value::Int(7));
}

#[test]
fn numeric_kind_reports_all_five_tags() {
    assert_eq!(call_host("numeric_kind", vec![Value::Int(1)]), Value::String("int".to_string().into()));
    assert_eq!(call_host("numeric_kind", vec![Value::Float(1.5)]), Value::String("float".to_string().into()));
    assert_eq!(
        call_host("numeric_kind", vec![Value::BigInt(num_bigint::BigInt::from(1))]),
        Value::String("bigint".to_string().into())
    );
    assert_eq!(
        call_host("numeric_kind", vec![Value::Rational(num_bigint::BigInt::from(1), num_bigint::BigInt::from(2))]),
        Value::String("rational".to_string().into())
    );
    let c = Value::Complex(Box::new(Value::Int(0)), Box::new(Value::Int(1)));
    assert_eq!(call_host("numeric_kind", vec![c]), Value::String("complex".to_string().into()));
}
