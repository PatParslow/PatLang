// Bitwise operators (band/bor/bxor/bnot/shl/shr) and bitfield helpers
// (bit_get/bit_set/bit_slice/bit_set_slice), exercised directly against the
// host functions and ops:: primitives for precise assertions.
use patlang_runtime::ir::hosts::{host_bit_get, host_bit_set, host_bit_set_slice, host_bit_slice};
use patlang_runtime::ir::ops::{bitand, bitnot, bitor, bitxor, shl, shr};
use patlang_runtime::ir::types::Value;

fn i(n: i64) -> Value { Value::Int(n) }

#[test]
fn operator_truth_table_on_small_integers() {
    assert_eq!(bitand(&i(0b1100), &i(0b1010)).unwrap(), i(0b1000));
    assert_eq!(bitor(&i(0b1100), &i(0b1010)).unwrap(), i(0b1110));
    assert_eq!(bitxor(&i(0b1100), &i(0b1010)).unwrap(), i(0b0110));
    assert_eq!(bitnot(&i(0)).unwrap(), i(-1));
    assert_eq!(shl(&i(1), &i(4)).unwrap(), i(16));
    assert_eq!(shr(&i(256), &i(4)).unwrap(), i(16));
}

#[test]
fn shift_boundary_cases() {
    assert_eq!(shl(&i(1), &i(0)).unwrap(), i(1));
    assert_eq!(shl(&i(1), &i(63)).unwrap(), i(1i64 << 63));
    assert!(shl(&i(1), &i(64)).is_err(), "shift of 64 must error, not silently wrap");
    assert!(shl(&i(1), &i(-1)).is_err(), "negative shift must error");
    assert!(shr(&i(1), &i(100)).is_err());
}

#[test]
fn non_integer_operand_errors_instead_of_silently_coercing() {
    assert!(bitand(&Value::String("x".to_string().into()), &i(1)).is_err());
}

#[test]
fn bit_get_set_roundtrip() {
    let mut n = i(0);
    n = host_bit_set(&[n, i(0), i(1)]).unwrap();
    n = host_bit_set(&[n, i(2), i(1)]).unwrap();
    assert_eq!(n, i(0b101));
    assert_eq!(host_bit_get(&[n.clone(), i(0)]).unwrap(), i(1));
    assert_eq!(host_bit_get(&[n.clone(), i(1)]).unwrap(), i(0));
    assert_eq!(host_bit_get(&[n.clone(), i(2)]).unwrap(), i(1));
    let cleared = host_bit_set(&[n, i(0), i(0)]).unwrap();
    assert_eq!(cleared, i(0b100));
}

#[test]
fn bit_slice_and_set_slice_roundtrip_packed_fields() {
    // Pack 4 byte-sized fields into one int, then read every field back.
    let mut packed = i(0);
    packed = host_bit_set_slice(&[packed, i(0), i(8), i(10)]).unwrap();
    packed = host_bit_set_slice(&[packed, i(8), i(8), i(20)]).unwrap();
    packed = host_bit_set_slice(&[packed, i(16), i(8), i(30)]).unwrap();
    packed = host_bit_set_slice(&[packed, i(24), i(8), i(40)]).unwrap();

    assert_eq!(host_bit_slice(&[packed.clone(), i(0), i(8)]).unwrap(), i(10));
    assert_eq!(host_bit_slice(&[packed.clone(), i(8), i(8)]).unwrap(), i(20));
    assert_eq!(host_bit_slice(&[packed.clone(), i(16), i(8)]).unwrap(), i(30));
    assert_eq!(host_bit_slice(&[packed, i(24), i(8)]).unwrap(), i(40));
}

#[test]
fn bit_slice_out_of_range_errors() {
    assert!(host_bit_slice(&[i(0), i(60), i(8)]).is_err(), "start+width > 64 must error");
    assert!(host_bit_get(&[i(0), i(64)]).is_err());
}
