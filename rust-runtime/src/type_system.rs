//! Type System Module
//!
//! Responsibilities:
//! - Provides type checking and inference for the runtime.
//! - Manages type constraints and supports extensibility for new types and rules.
//! - Integrates with Core Evaluator, Memory Manager, Goal System, Event System, Message Queue, Error Handler, and Secure Distributed Code Support.
//!
//! Extensibility Points:
//! - Custom type rules via trait implementations.
//! - Pluggable constraint solvers and inference strategies.

use std::collections::HashMap;

/// Represents a type in the system.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum Type {
    Int,
    Float,
    Bool,
    String,
    Custom(String),
    Unknown,
}

/// Represents a value with an associated type.
#[derive(Debug)]
pub struct TypedValue {
    pub value: Box<dyn std::any::Any + Send + Sync>,
    pub ty: Type,
}

/// Trait for type system integration with other modules.
pub trait TypeSystemIntegration {
    fn notify_type_event(&self, event: TypeSystemEvent);
}

/// Events emitted by the type system for integration.
#[derive(Debug)]
pub enum TypeSystemEvent {
    TypeChecked { value: TypedValue },
    TypeError { message: String },
    InferencePerformed { value: TypedValue },
}

/// Public API for the Type System.
pub struct TypeSystem {
    /// Registered custom types and rules.
    custom_types: HashMap<String, Type>,
    /// Integration hooks.
    integrations: Vec<Box<dyn TypeSystemIntegration + Send + Sync>>,
}

impl TypeSystem {
    /// Create a new TypeSystem instance.
    pub fn new() -> Self {
        Self {
            custom_types: HashMap::new(),
            integrations: Vec::new(),
        }
    }

    pub fn custom_types(&self) -> &HashMap<String, Type> {
        &self.custom_types
    }

    /// Register an integration hook (for Core Evaluator, Memory Manager, etc.).
    pub fn register_integration<T: TypeSystemIntegration + Send + Sync + 'static>(&mut self, integration: T) {
        self.integrations.push(Box::new(integration));
    }

    /// Register a custom type.
    pub fn register_custom_type(&mut self, name: &str) {
        self.custom_types.insert(name.to_string(), Type::Custom(name.to_string()));
    }

    /// Basic type checking: checks if the value matches the expected type.
    pub fn check_type(&self, value: TypedValue, expected: &Type) -> Result<(), String> {
        if &value.ty == expected {
            // Emit event with owned value, only notify first integration
            self.emit_event(TypeSystemEvent::TypeChecked {
                value,
            });
            Ok(())
        } else {
            let msg = format!("Type error: expected {:?}, got {:?}", expected, value.ty);
            self.emit_event(TypeSystemEvent::TypeError { message: msg.clone() });
            Err(msg)
        }
    }

    /// Basic type inference: infers the type from a value (stub logic).
    pub fn infer_type(&self, value: &dyn std::any::Any) -> Type {
        // Stub: In a real implementation, this would inspect the value.
        // Here, we just return Unknown.
        Type::Unknown
    }

    /// Emit an event to all integrations.
    fn emit_event(&self, event: TypeSystemEvent) {
        // Only notify the first integration for events containing TypedValue,
        // since they cannot be cloned. For other events, notify all.
        match &event {
            TypeSystemEvent::TypeChecked { .. } | TypeSystemEvent::InferencePerformed { .. } => {
                if let Some(integration) = self.integrations.first() {
                    integration.notify_type_event(event);
                }
            }
            _ => {
                for integration in &self.integrations {
                    integration.notify_type_event(TypeSystemEvent::TypeError {
                        message: match &event {
                            TypeSystemEvent::TypeError { message } => message.clone(),
                            _ => String::from("Unknown event"),
                        }
                    });
                }
            }
        }
    }

    /// Placeholder for constraint management API.
    pub fn add_constraint(&self, _constraint: &str) {
        // Stub for constraint management.
    }
}

// --- Integration Stubs for Other Modules ---

/// Stub trait for Core Evaluator integration.
pub trait CoreEvaluatorIntegration: TypeSystemIntegration {}
/// Stub trait for Memory Manager integration.
pub trait MemoryManagerIntegration: TypeSystemIntegration {}
/// Stub trait for Goal System integration.
pub trait GoalSystemIntegration: TypeSystemIntegration {}
/// Stub trait for Event System integration.
pub trait EventSystemIntegration: TypeSystemIntegration {}
/// Stub trait for Message Queue integration.
pub trait MessageQueueIntegration: TypeSystemIntegration {}
/// Stub trait for Error Handler integration.
pub trait ErrorHandlerIntegration: TypeSystemIntegration {}
/// Stub trait for Secure Distributed Code Support integration.
pub trait SecureDistributedCodeSupportIntegration: TypeSystemIntegration {}

// --- End of type_system.rs ---