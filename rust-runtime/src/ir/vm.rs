// IR VM and evaluation logic for patlang native runtime

use super::ir::{Value, BinOpKind, UnOpKind, Instr};
use std::collections::HashMap;

thread_local! {
	pub static OBJECTS: std::cell::RefCell<HashMap<String, HashMap<String, Value>>> = std::cell::RefCell::new(HashMap::new());
	pub static FACTS: std::cell::RefCell<HashMap<String, Vec<(String, String)>>> = std::cell::RefCell::new(HashMap::new());
	pub static GOALS: std::cell::RefCell<Vec<(String, Vec<String>)>> = std::cell::RefCell::new(Vec::new());
	pub static TYPE_RULES: std::cell::RefCell<HashMap<(String, usize), String>> = std::cell::RefCell::new(HashMap::new());
	pub static EVENT_HANDLERS: std::cell::RefCell<HashMap<String, Vec<String>>> = std::cell::RefCell::new(HashMap::new());
}

pub fn obj_get(name: &str, prop: &str) -> Option<Value> {
	OBJECTS.with(|o| {
		let b = o.borrow();
		b.get(name).and_then(|m| m.get(prop)).cloned()
	})
}

pub fn obj_set(name: &str, prop: &str, val: Value) {
	OBJECTS.with(|o| {
		let mut b = o.borrow_mut();
		let m = b.entry(name.to_string()).or_insert_with(HashMap::new);
		m.insert(prop.to_string(), val);
	});
}

pub fn ensure_obj(name: &str, class: &str) {
	obj_set(name, "type", Value::String(class.to_string()));
	obj_set(name, "name", Value::String(name.to_string()));
}

pub struct Host;

impl Host {
	pub fn call(name: &str, args: &[Value]) -> Result<Value, String> {
		// ...existing code...
		unimplemented!("Move Host::call body here from codegen.rs");
	}
}
// IR VM and evaluation logic for patlang native runtime

// ...to be filled in from codegen.rs...
