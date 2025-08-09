//! Object Module
//! Basic object and object store for the runtime. Keeps things simple: values are strings.

use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct Object {
    pub class_name: String,
    pub properties: HashMap<String, String>,
}

impl Object {
    pub fn new(class_name: &str) -> Self {
        Object {
            class_name: class_name.to_string(),
            properties: HashMap::new(),
        }
    }

    pub fn set(&mut self, key: &str, value: impl Into<String>) {
        self.properties.insert(key.to_string(), value.into());
    }

    pub fn get(&self, key: &str) -> Option<&String> {
        self.properties.get(key)
    }
}

#[derive(Default, Debug, Clone)]
pub struct ObjectStore {
    map: HashMap<String, Object>,
}

impl ObjectStore {
    pub fn new() -> Self { Self { map: HashMap::new() } }

    pub fn ensure(&mut self, name: &str, class_name: &str) -> &mut Object {
        let existed = self.map.contains_key(name);
        let entry = self.map.entry(name.to_string()).or_insert_with(|| Object::new(class_name));
        if !existed {
            // Initialize class and default properties only on first creation
            entry.class_name = class_name.to_string();
            entry.set("type", class_name);
            entry.set("name", name);
        } else {
            // Ensure defaults exist but do not overwrite existing class
            if entry.get("name").is_none() { entry.set("name", name); }
            if entry.get("type").is_none() {
                let cls = entry.class_name.clone();
                entry.set("type", cls);
            }
        }
        entry
    }

    pub fn set(&mut self, name: &str, key: &str, value: impl Into<String>) {
        let obj = self.map.entry(name.to_string()).or_insert_with(|| Object::new("Object"));
        obj.set(key, value);
    }

    pub fn get(&self, name: &str, key: &str) -> Option<String> {
        self.map.get(name).and_then(|o| o.get(key)).cloned()
    }

    pub fn exists(&self, name: &str) -> bool {
        self.map.contains_key(name)
    }

    pub fn iter(&self) -> impl Iterator<Item = (&String, &Object)> {
        self.map.iter()
    }
}