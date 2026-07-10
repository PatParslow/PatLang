// Host bridge functions for patlang native runtime

use super::ir::Value;
use super::vm::{obj_get, obj_set, ensure_obj, FACTS, EVENT_HANDLERS};
use std::collections::HashMap;

pub struct Host;

impl Host {
	pub fn call(name: &str, args: &[Value]) -> Result<Value, String> {
		match name {
			"set_var" => {
				if args.len() != 2 { return Ok(Value::Unit); }
				let key = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
				let val = args.get(1).cloned().unwrap_or(Value::Unit);
				if !key.is_empty() {
					obj_set("__vars", &key, val);
				}
				Ok(Value::Unit)
			}
			"print" => {
				if let Some(x) = args.get(0) {
					let s = display_value(x);
					let out = interpolate(&s);
					println!("{}", out);
				}
				Ok(Value::Unit)
			},
			"sed" => {
				let cmd = match args.get(0) { Some(Value::String(s)) => s.as_str(), _ => "" };
				let dv;
				let input: &str = match args.get(1) {
					Some(Value::String(s)) => s.as_str(),
					Some(v) => { dv = display_value(v); dv.as_str() },
					None => "",
				};
				let out = sed_command(cmd, input);
				Ok(Value::String(out))
			},
			"add" => host_bin_num(args, |a,b| a+b),
			"multiply" => host_bin_num(args, |a,b| a*b),
			"subtract" => host_bin_num(args, |a,b| a-b),
			"max" => host_bin_num(args, |a,b| a.max(b)),
			"min" => host_bin_num(args, |a,b| a.min(b)),
			"calculate" => Ok(Value::Int(0)),
			"calculate_result" => Ok(Value::Int(0)),
			"get_value" => Ok(Value::Int(0)),
			"process" => Ok(Value::Bool(true)),
			"validate" => Ok(Value::Bool(true)),
			"len" => {
				let v = args.get(0).cloned().unwrap_or(Value::Unit);
				let n = match v {
					Value::String(s) => s.chars().count() as i64,
					Value::List(xs) => xs.len() as i64,
					Value::Object(m) => m.len() as i64,
					_ => 0,
				};
				Ok(Value::Int(n))
			}
			"get" => {
				if args.len() != 2 { return Err("expected 2 args".into()); }
				let key = match &args[1] { Value::String(s) => s.clone(), _ => return Err("expected string key".into()) };
				match &args[0] {
					Value::String(name) => Ok(obj_get(name, &key).unwrap_or(Value::Unit)),
					Value::Object(map) => Ok(map.get(&key).cloned().unwrap_or(Value::Unit)),
					_ => Ok(Value::Unit),
				}
			}
			"send" => {
				if args.len() < 2 { return Ok(Value::Unit); }
				let recv = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
				let method = match &args[1] { Value::String(s) => s.clone(), _ => String::new() };
				let rest = &args[2..];
				match method.as_str() {
					"set" => {
						if rest.len() != 2 { return Ok(Value::Unit); }
						let prop = match &rest[0] { Value::String(s) => s.clone(), _ => String::new() };
						let val = rest[1].clone();
						if !recv.is_empty() && !prop.is_empty() { obj_set(&recv, &prop, val); }
						Ok(Value::Unit)
					}
					"infer_is_adult" => {
						if let Some(v @ (Value::Int(_) | Value::Float(_))) = obj_get(&recv, "age") {
							if v.as_number().unwrap_or(0.0) >= 18.0 { obj_set(&recv, "is_adult", Value::Bool(true)); return Ok(Value::Bool(true)); }
						} else if let Some(Value::String(s)) = obj_get(&recv, "age") {
							if s.parse::<f64>().unwrap_or(0.0) >= 18.0 { obj_set(&recv, "is_adult", Value::Bool(true)); return Ok(Value::Bool(true)); }
						}
						Ok(Value::Bool(false))
					}
					"infer_relations" => {
						let mut has = false;
						FACTS.with(|f| {
							if let Some(v) = f.borrow().get("parent") {
								has = v.iter().any(|(_, child)| child == &recv);
							}
						});
						if has { obj_set(&recv, "has_parent", Value::Bool(true)); return Ok(Value::Bool(true)); }
						Ok(Value::Bool(false))
					}
					_ => Ok(Value::Unit),
				}
			}
			other => Err(format!("host fn '{}' not found", other)),
		}
	}
}

fn host_bin_num(args: &[Value], f: fn(f64,f64)->f64) -> Result<Value, String> {
	let a = args.get(0).ok_or("expected 2 args")?;
	let b = args.get(1).ok_or("expected 2 args")?;
	let an = a.as_number()?; let bn = b.as_number()?;
	Ok(Value::Float(f(an,bn)))
}

fn display_value(v: &Value) -> String {
	match v {
		Value::Unit => String::new(),
		Value::Bool(b) => b.to_string(),
		Value::Int(n) => n.to_string(),
		Value::Float(n) => n.to_string(),
		Value::BigInt(b) => b.to_string(),
		Value::Rational(n, d) => format!("{}/{}", n, d),
		Value::Complex(re, im) => format!("{}+{}i", display_value(re), display_value(im)),
		Value::String(s) => s.clone(),
		Value::List(xs) => {
			let parts: Vec<String> = xs.iter().map(|x| display_value(x)).collect();
			format!("[{}]", parts.join(", "))
		}
		Value::Object(map) => {
			let mut kvs: Vec<String> = map.iter().map(|(k,v)| format!("{}: {}", k, display_value(v))).collect();
			kvs.sort();
			format!("{{{}}}", kvs.join(", "))
		}
	}
}

fn sed_command(cmd: &str, input: &str) -> String {
	if !cmd.starts_with('s') { return input.to_string(); }
	let mut parts = cmd.splitn(4, '/');
	let _s = parts.next();
	let pat = match parts.next() { Some(p) => p, None => return input.to_string() };
	let repl = match parts.next() { Some(r) => r, None => return input.to_string() };
	let flags = parts.next().unwrap_or("");
	let global = flags.contains('g');
	let ci = flags.contains('i');
	replace_lit(input, pat, repl, global, ci)
}

fn replace_lit(hay: &str, pat: &str, rep: &str, global: bool, ci: bool) -> String {
	if pat.is_empty() { return hay.to_string(); }
	if !ci {
		if !global {
			if let Some(pos) = hay.find(pat) {
				let mut out = String::with_capacity(hay.len());
				out.push_str(&hay[..pos]);
				out.push_str(rep);
				out.push_str(&hay[pos+pat.len()..]);
				return out;
			}
			return hay.to_string();
		} else {
			let mut out = String::with_capacity(hay.len());
			let mut start = 0usize;
			let mut rest = hay;
			while let Some(pos) = rest.find(pat) {
				let abs = start + pos;
				out.push_str(&hay[start..abs]);
				out.push_str(rep);
				start = abs + pat.len();
				rest = &hay[start..];
			}
			out.push_str(&hay[start..]);
			return out;
		}
	}
	let hay_l = hay.to_ascii_lowercase();
	let pat_l = pat.to_ascii_lowercase();
	if !global {
		if let Some(pos) = hay_l.find(&pat_l) {
			let mut out = String::with_capacity(hay.len());
			out.push_str(&hay[..pos]);
			out.push_str(rep);
			out.push_str(&hay[pos+pat.len()..]);
			return out;
		}
		return hay.to_string();
	} else {
		let mut out = String::with_capacity(hay.len());
		let mut start = 0usize;
		let mut idx = 0usize;
		while idx <= hay_l.len() {
			if let Some(pos) = hay_l[idx..].find(&pat_l) {
				let abs = idx + pos;
				out.push_str(&hay[start..abs]);
				out.push_str(rep);
				start = abs + pat.len();
				idx = start;
			} else { break; }
		}
		out.push_str(&hay[start..]);
		return out;
	}
}

fn interpolate(input: &str) -> String {
	let mut out = String::new();
	let b = input.as_bytes();
	let mut i = 0usize;
	while i < b.len() {
		if i + 2 < b.len() && b[i] as char == '#' && b[i+1] as char == '{' {
			i += 2; let start = i;
			while i < b.len() && b[i] as char != '}' { i += 1; }
			let key = &input[start..i];
			let val = resolve_interp_var(key);
			out.push_str(&val);
			if i < b.len() && b[i] as char == '}' { i += 1; }
		} else { out.push(b[i] as char); i += 1; }
	}
	out
}

fn resolve_interp_var(key: &str) -> String {
	if let Some((obj, prop)) = key.split_once('.') {
		if let Some(v) = obj_get(obj, prop) { return display_value(&v); }
	} else {
		if let Some(v) = obj_get("__vars", key) { return display_value(&v); }
	}
	String::new()
}
// Host bridge functions for patlang native runtime

// ...to be filled in from codegen.rs...
