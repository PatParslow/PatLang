// Hand-rolled equivalent of what PatLang's own object/event system actually
// does under the hood (see OBJECTS: RefCell<HashMap<String, HashMap<String,
// Value>>> in rust-runtime/src/ir/hosts.rs) -- a stringly-typed HashMap of
// HashMaps for objects, plus a Vec of registered handler closures for
// events. This is deliberately NOT the fastest idiomatic Rust for this
// problem (that would use enums/structs and beat both PatLang variants by
// an uninteresting margin) -- it is the fair "closest equivalent to how
// PatLang's runtime solves this problem" comparison.
use std::collections::HashMap;

fn main() {
    let n: i64 = 50000;
    let mut objects: HashMap<String, HashMap<String, i64>> = HashMap::new();

    for i in 0..n {
        let mut props = HashMap::new();
        props.insert("v".to_string(), i);
        objects.insert(format!("obj{}", i), props);
    }

    // "bump" handler: increment the named object's "v" property by 1.
    let handlers: Vec<Box<dyn Fn(&mut HashMap<String, HashMap<String, i64>>, i64)>> = vec![Box::new(
        |objects: &mut HashMap<String, HashMap<String, i64>>, payload: i64| {
            let name = format!("obj{}", payload);
            if let Some(props) = objects.get_mut(&name) {
                let cur = *props.get("v").unwrap_or(&0);
                props.insert("v".to_string(), cur + 1);
            }
        },
    )];

    for i in 0..n {
        for h in &handlers {
            h(&mut objects, i);
        }
    }

    let mut total: i64 = 0;
    for i in 0..n {
        let name = format!("obj{}", i);
        if let Some(props) = objects.get(&name) {
            total += *props.get("v").unwrap_or(&0);
        }
    }
    println!("{}", total);
}
