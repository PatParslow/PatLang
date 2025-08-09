//! Runtime Integration module
//! Centralizes cross-module behaviors so the evaluator stays generic.

use std::collections::HashMap;
use crate::object::ObjectStore;

#[derive(Default, Debug, Clone)]
pub struct TypeInferenceRegistry {
    // Map (predicate, arg_index) -> class_name
    rules: HashMap<(String, usize), String>,
}

impl TypeInferenceRegistry {
    pub fn new() -> Self { Self { rules: HashMap::new() } }

    pub fn register(&mut self, pred: &str, arg_index: usize, class_name: &str) {
        self.rules.insert((pred.to_string(), arg_index), class_name.to_string());
    }

    fn get(&self, pred: &str, arg_index: usize) -> Option<&str> {
        self.rules.get(&(pred.to_string(), arg_index)).map(|s| s.as_str())
    }
}

/// Apply registered type inference rules to a query result.
/// - subject corresponds to arg index 0
/// - each (var, value) in results corresponds to arg index 1 for a binary predicate
pub fn on_query_results(objects: &mut ObjectStore, registry: &TypeInferenceRegistry, pred: &str, subject: &str, results: &Vec<(String, String)>) {
    if let Some(class0) = registry.get(pred, 0) {
        let _ = objects.ensure(subject, class0);
    }
    if let Some(class1) = registry.get(pred, 1) {
        for (_var, val) in results.iter() {
            let _ = objects.ensure(val, class1);
        }
    }
}
