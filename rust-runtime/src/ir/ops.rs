use super::types::*;

pub fn add(a: &Value, b: &Value) -> Result<Value, String> {
    match (a, b) {
        // String concatenation (including mixed types)
        (Value::String(x), Value::String(y)) => Ok(Value::String(format!("{}{}", x, y))),
        (Value::String(x), other) => Ok(Value::String(format!("{}{}", x, v_to_string(other)))),
        (other, Value::String(y)) => Ok(Value::String(format!("{}{}", v_to_string(other), y))),
        // Numeric addition with permissive coercion via as_number (Unit -> 0.0)
        _ => {
            let an = a.as_number().map_err(|_| "type error in add".to_string())?;
            let bn = b.as_number().map_err(|_| "type error in add".to_string())?;
            Ok(Value::Number(an + bn))
        }
    }
}

pub fn sub(a: &Value, b: &Value) -> Result<Value, String> {
    let an = a.as_number().map_err(|_| "type error in sub".to_string())?;
    let bn = b.as_number().map_err(|_| "type error in sub".to_string())?;
    Ok(Value::Number(an - bn))
}

pub fn mul(a: &Value, b: &Value) -> Result<Value, String> {
    let an = a.as_number().map_err(|_| "type error in mul".to_string())?;
    let bn = b.as_number().map_err(|_| "type error in mul".to_string())?;
    Ok(Value::Number(an * bn))
}

pub fn div(a: &Value, b: &Value) -> Result<Value, String> {
    let an = a.as_number().map_err(|_| "type error in div".to_string())?;
    let bn = b.as_number().map_err(|_| "type error in div".to_string())?;
    Ok(Value::Number(an / bn))
}

pub fn modu(a: &Value, b: &Value) -> Result<Value, String> {
    let an = a.as_number().map_err(|_| "type error in mod".to_string())?;
    let bn = b.as_number().map_err(|_| "type error in mod".to_string())?;
    Ok(Value::Number(an % bn))
}

pub fn cmp(kind: BinOpKind, a: &Value, b: &Value) -> Result<Value, String> {
    use BinOpKind::*;
    match kind {
        Eq => Ok(Value::Bool(a == b)),
        Ne => Ok(Value::Bool(a != b)),
        Lt => Ok(Value::Bool(a.as_number()? < b.as_number()?)),
        Le => Ok(Value::Bool(a.as_number()? <= b.as_number()?)),
        Gt => Ok(Value::Bool(a.as_number()? > b.as_number()?)),
        Ge => Ok(Value::Bool(a.as_number()? >= b.as_number()?)),
        _ => Err("invalid cmp op".into()),
    }
}

fn v_to_string(v: &Value) -> String {
    match v {
        Value::Unit => String::new(),
        Value::Bool(b) => b.to_string(),
        Value::Number(n) => {
            if n.fract() == 0.0 { format!("{}", *n as i64) } else { n.to_string() }
        }
        Value::String(s) => s.clone(),
        Value::List(xs) => {
            let parts: Vec<String> = xs.iter().map(v_to_string).collect();
            format!("[{}]", parts.join(", "))
        }
        Value::HostFunction(_) => "<hostfn>".into(),
        Value::Object(map) => {
            let mut kvs: Vec<String> = map.iter().map(|(k, v)| format!("{}: {}", k, v_to_string(v))).collect();
            kvs.sort();
            format!("{{{}}}", kvs.join(", "))
        }
    }
}
