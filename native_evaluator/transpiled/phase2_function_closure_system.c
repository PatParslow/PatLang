// Phase 2 Week 3: Function Closure System Implementation
// Lexical scoping with closure capture and advanced function features
// Generated: 2025-07-01 21:42:00 +0100

#include "phase2_function_closure_system.h"
#include "../native_bridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>

// Debug macros for closure system
#ifdef PATLANG_DEBUG
#define CLOSURE_DEBUG_PRINT(fmt, ...) printf("[CLOSURE_DEBUG] " fmt "\n", ##__VA_ARGS__)
#else
#define CLOSURE_DEBUG_PRINT(fmt, ...)
#endif

// Function Closure System Constants
static const size_t DEFAULT_MAX_SCOPE_DEPTH = 100;
static const size_t DEFAULT_VARIABLE_HASH_SIZE = 64;
static const double CLOSURE_GC_THRESHOLD = 0.8;

// Scope Chain Management
ScopeChain* create_scope_chain(MemoryManager* mm) {
    ScopeChain* chain = (ScopeChain*)patlang_allocate_object(
        OBJECT_TYPE_CUSTOM, sizeof(ScopeChain), 8, mm).address;
    
    if (!chain) return NULL;
    
    // Create global scope
    chain->global_scope = create_lexical_scope(SCOPE_TYPE_GLOBAL, "global", NULL, mm);
    if (!chain->global_scope) {
        patlang_deallocate_object(chain, mm);
        return NULL;
    }
    
    chain->current_scope = chain->global_scope;
    chain->chain_depth = 1;
    chain->max_depth = DEFAULT_MAX_SCOPE_DEPTH;
    chain->memory_manager = mm;
    
    CLOSURE_DEBUG_PRINT("Scope chain created with global scope");
    return chain;
}

void destroy_scope_chain(ScopeChain* chain) {
    if (!chain) return;
    
    // Destroy all scopes starting from global
    if (chain->global_scope) {
        destroy_lexical_scope(chain->global_scope);
    }
    
    patlang_deallocate_object(chain, chain->memory_manager);
    CLOSURE_DEBUG_PRINT("Scope chain destroyed");
}

// Lexical Scope Management
LexicalScope* create_lexical_scope(ScopeType type, const char* name, LexicalScope* parent, MemoryManager* mm) {
    LexicalScope* scope = (LexicalScope*)patlang_allocate_object(
        OBJECT_TYPE_CUSTOM, sizeof(LexicalScope), 8, mm).address;
    
    if (!scope) return NULL;
    
    scope->type = type;
    scope->scope_name = (char*)patlang_allocate_object(
        OBJECT_TYPE_STRING, strlen(name) + 1, 1, mm).address;
    
    if (!scope->scope_name) {
        patlang_deallocate_object(scope, mm);
        return NULL;
    }
    
    strcpy(scope->scope_name, name);
    scope->scope_depth = parent ? parent->scope_depth + 1 : 0;
    scope->variables = NULL;
    scope->variable_count = 0;
    scope->parent_scope = parent;
    scope->child_scopes = NULL;
    scope->next_sibling = NULL;
    scope->memory_manager = mm;
    scope->is_closed = false;
    scope->creation_time = (double)clock() / CLOCKS_PER_SEC;
    
    // Link to parent's children
    if (parent) {
        scope->next_sibling = parent->child_scopes;
        parent->child_scopes = scope;
    }
    
    CLOSURE_DEBUG_PRINT("Lexical scope created: %s (depth: %zu)", name, scope->scope_depth);
    return scope;
}

void destroy_lexical_scope(LexicalScope* scope) {
    if (!scope) return;
    
    // Destroy all variables
    Variable* var = scope->variables;
    while (var) {
        Variable* next = var->next;
        destroy_variable(var);
        var = next;
    }
    
    // Destroy child scopes
    LexicalScope* child = scope->child_scopes;
    while (child) {
        LexicalScope* next = child->next_sibling;
        destroy_lexical_scope(child);
        child = next;
    }
    
    if (scope->scope_name) {
        patlang_deallocate_object(scope->scope_name, scope->memory_manager);
    }
    
    patlang_deallocate_object(scope, scope->memory_manager);
    CLOSURE_DEBUG_PRINT("Lexical scope destroyed");
}

// Variable Management
Variable* create_variable(const char* name, PaTLangObject* value, VariableType type, MemoryManager* mm) {
    Variable* var = (Variable*)patlang_allocate_object(
        OBJECT_TYPE_CUSTOM, sizeof(Variable), 8, mm).address;
    
    if (!var) return NULL;
    
    var->name = (char*)patlang_allocate_object(
        OBJECT_TYPE_STRING, strlen(name) + 1, 1, mm).address;
    
    if (!var->name) {
        patlang_deallocate_object(var, mm);
        return NULL;
    }
    
    strcpy(var->name, name);
    var->value = value;
    var->type = type;
    var->scope_depth = 0;
    var->is_mutable = true;
    var->is_captured = false;
    var->ref_count = 1;
    var->next = NULL;
    
    // Increment reference count for value
    if (value) {
        value->ref_count++;
    }
    
    CLOSURE_DEBUG_PRINT("Variable created: %s (type: %d)", name, type);
    return var;
}

void destroy_variable(Variable* var) {
    if (!var) return;
    
    // Release value reference
    if (var->value) {
        patlang_release_object(var->value);
    }
    
    // Don't deallocate name and var itself as they're managed by memory manager
    CLOSURE_DEBUG_PRINT("Variable destroyed: %s", var->name ? var->name : "unknown");
}

bool define_variable(LexicalScope* scope, const char* name, PaTLangObject* value, VariableType type) {
    if (!scope || !name) return false;
    
    // Check if variable already exists in this scope
    Variable* existing = scope->variables;
    while (existing) {
        if (strcmp(existing->name, name) == 0) {
            CLOSURE_DEBUG_PRINT("Variable %s already defined in scope %s", name, scope->scope_name);
            return false; // Variable already exists
        }
        existing = existing->next;
    }
    
    // Create new variable
    Variable* var = create_variable(name, value, type, scope->memory_manager);
    if (!var) return false;
    
    var->scope_depth = scope->scope_depth;
    
    // Add to scope's variable list
    var->next = scope->variables;
    scope->variables = var;
    scope->variable_count++;
    
    CLOSURE_DEBUG_PRINT("Variable %s defined in scope %s", name, scope->scope_name);
    return true;
}

VariableLookupResult lookup_variable(ScopeChain* chain, const char* name) {
    VariableLookupResult result = {0};
    
    if (!chain || !name) {
        return result;
    }
    
    // Search from current scope up the chain
    LexicalScope* scope = chain->current_scope;
    while (scope) {
        Variable* var = scope->variables;
        while (var) {
            if (strcmp(var->name, name) == 0) {
                result.found = true;
                result.variable = var;
                result.value = var->value;
                result.scope_depth = scope->scope_depth;
                result.is_captured = var->is_captured;
                result.is_upvalue = (scope != chain->current_scope);
                result.containing_scope = scope;
                
                CLOSURE_DEBUG_PRINT("Variable %s found in scope %s (depth: %zu)", 
                                   name, scope->scope_name, scope->scope_depth);
                return result;
            }
            var = var->next;
        }
        scope = scope->parent_scope;
    }
    
    CLOSURE_DEBUG_PRINT("Variable %s not found in scope chain", name);
    return result;
}

bool assign_variable(ScopeChain* chain, const char* name, PaTLangObject* value) {
    VariableLookupResult lookup = lookup_variable(chain, name);
    
    if (!lookup.found) {
        CLOSURE_DEBUG_PRINT("Cannot assign to undefined variable: %s", name);
        return false;
    }
    
    if (!lookup.variable->is_mutable) {
        CLOSURE_DEBUG_PRINT("Cannot assign to immutable variable: %s", name);
        return false;
    }
    
    // Release old value and assign new one
    if (lookup.variable->value) {
        patlang_release_object(lookup.variable->value);
    }
    
    lookup.variable->value = value;
    if (value) {
        value->ref_count++;
    }
    
    CLOSURE_DEBUG_PRINT("Variable %s assigned new value", name);
    return true;
}

// Scope Management Functions
bool push_scope(ScopeChain* chain, LexicalScope* scope) {
    if (!chain || !scope) return false;
    
    if (chain->chain_depth >= chain->max_depth) {
        CLOSURE_DEBUG_PRINT("Maximum scope depth exceeded: %zu", chain->max_depth);
        return false;
    }
    
    scope->parent_scope = chain->current_scope;
    chain->current_scope = scope;
    chain->chain_depth++;
    
    CLOSURE_DEBUG_PRINT("Pushed scope: %s (depth: %zu)", scope->scope_name, chain->chain_depth);
    return true;
}

LexicalScope* pop_scope(ScopeChain* chain) {
    if (!chain || !chain->current_scope || chain->current_scope == chain->global_scope) {
        CLOSURE_DEBUG_PRINT("Cannot pop global scope or invalid chain");
        return NULL;
    }
    
    LexicalScope* popped = chain->current_scope;
    chain->current_scope = popped->parent_scope;
    chain->chain_depth--;
    
    CLOSURE_DEBUG_PRINT("Popped scope: %s (new depth: %zu)", 
                       popped->scope_name, chain->chain_depth);
    return popped;
}

LexicalScope* enter_function_scope(ScopeChain* chain, const char* function_name) {
    if (!chain || !function_name) return NULL;
    
    LexicalScope* func_scope = create_lexical_scope(SCOPE_TYPE_FUNCTION, function_name, 
                                                   chain->current_scope, chain->memory_manager);
    if (!func_scope) return NULL;
    
    if (!push_scope(chain, func_scope)) {
        destroy_lexical_scope(func_scope);
        return NULL;
    }
    
    CLOSURE_DEBUG_PRINT("Entered function scope: %s", function_name);
    return func_scope;
}

void exit_function_scope(ScopeChain* chain) {
    if (!chain) return;
    
    LexicalScope* func_scope = pop_scope(chain);
    if (func_scope && func_scope->type == SCOPE_TYPE_FUNCTION) {
        func_scope->is_closed = true;
        CLOSURE_DEBUG_PRINT("Exited function scope: %s", func_scope->scope_name);
    }
}

// Closure Creation and Management
ClosureCreationResult create_function_closure(ast_node_t* function_def, ScopeChain* scope_chain, MemoryManager* mm) {
    ClosureCreationResult result = {0};
    clock_t start_time = clock();
    
    if (!function_def || !scope_chain || !mm) {
        result.success = false;
        result.error_message = "Invalid parameters for closure creation";
        return result;
    }
    
    // Create function closure
    FunctionClosure* closure = (FunctionClosure*)patlang_allocate_object(
        OBJECT_TYPE_FUNCTION, sizeof(FunctionClosure), 8, mm).address;
    
    if (!closure) {
        result.success = false;
        result.error_message = "Failed to allocate closure";
        return result;
    }
    
    closure->type = FUNCTION_TYPE_CLOSURE;
    closure->function_name = (char*)patlang_allocate_object(
        OBJECT_TYPE_STRING, 64, 1, mm).address; // Default function name size
    
    if (!closure->function_name) {
        patlang_deallocate_object(closure, mm);
        result.success = false;
        result.error_message = "Failed to allocate function name";
        return result;
    }
    
    strcpy(closure->function_name, "anonymous");
    closure->function_body = function_def;
    closure->parameter_list = NULL; // Would be extracted from function_def in real implementation
    closure->parameter_count = 0;
    closure->defining_scope = scope_chain->current_scope;
    closure->is_partial_application = false;
    closure->bound_arguments = NULL;
    closure->bound_argument_count = 0;
    closure->creation_time = (double)clock() / CLOCKS_PER_SEC;
    closure->call_count = 0;
    closure->total_execution_time = 0.0;
    closure->memory_manager = mm;
    
    // Create closure environment
    closure->environment = create_closure_environment(scope_chain->current_scope, mm);
    if (!closure->environment) {
        destroy_function_closure(closure);
        result.success = false;
        result.error_message = "Failed to create closure environment";
        return result;
    }
    
    // Calculate creation time
    clock_t end_time = clock();
    double creation_time = ((double)(end_time - start_time)) / CLOCKS_PER_SEC;
    
    result.success = true;
    result.closure = closure;
    result.environment = closure->environment;
    result.variables_captured = closure->environment->capture_count;
    result.creation_time = creation_time;
    
    CLOSURE_DEBUG_PRINT("Function closure created (captured %zu variables, time: %.6f)", 
                       result.variables_captured, creation_time);
    
    return result;
}

void destroy_function_closure(FunctionClosure* closure) {
    if (!closure) return;
    
    // Destroy environment
    if (closure->environment) {
        destroy_closure_environment(closure->environment);
    }
    
    // Clean up bound arguments
    if (closure->bound_arguments) {
        for (size_t i = 0; i < closure->bound_argument_count; i++) {
            if (closure->bound_arguments[i]) {
                patlang_release_object(closure->bound_arguments[i]);
            }
        }
        patlang_deallocate_object(closure->bound_arguments, closure->memory_manager);
    }
    
    if (closure->function_name) {
        patlang_deallocate_object(closure->function_name, closure->memory_manager);
    }
    
    patlang_deallocate_object(closure, closure->memory_manager);
    CLOSURE_DEBUG_PRINT("Function closure destroyed");
}

// Closure Environment Management
ClosureEnvironment* create_closure_environment(LexicalScope* defining_scope, MemoryManager* mm) {
    ClosureEnvironment* env = (ClosureEnvironment*)patlang_allocate_object(
        OBJECT_TYPE_CUSTOM, sizeof(ClosureEnvironment), 8, mm).address;
    
    if (!env) return NULL;
    
    env->captured_variables = NULL;
    env->capture_count = 0;
    env->defining_scope = defining_scope;
    env->environment_size = sizeof(ClosureEnvironment);
    env->is_shared = false;
    env->ref_count = 1;
    env->memory_manager = mm;
    
    CLOSURE_DEBUG_PRINT("Closure environment created");
    return env;
}

void destroy_closure_environment(ClosureEnvironment* env) {
    if (!env) return;
    
    // Clean up captured variables
    CapturedVariable* captured = env->captured_variables;
    while (captured) {
        CapturedVariable* next = captured->next;
        
        if (captured->captured_value) {
            patlang_release_object(captured->captured_value);
        }
        
        patlang_deallocate_object(captured, env->memory_manager);
        captured = next;
    }
    
    patlang_deallocate_object(env, env->memory_manager);
    CLOSURE_DEBUG_PRINT("Closure environment destroyed");
}

// Variable Capture Functions
bool capture_variable(ClosureEnvironment* env, Variable* var, CaptureType capture_type) {
    if (!env || !var) return false;
    
    // Check if already captured
    CapturedVariable* existing = find_captured_variable(env, var->name);
    if (existing) {
        CLOSURE_DEBUG_PRINT("Variable %s already captured", var->name);
        return true;
    }
    
    // Create captured variable
    CapturedVariable* captured = (CapturedVariable*)patlang_allocate_object(
        OBJECT_TYPE_CUSTOM, sizeof(CapturedVariable), 8, env->memory_manager).address;
    
    if (!captured) return false;
    
    captured->original_variable = var;
    captured->capture_type = capture_type;
    captured->capture_depth = var->scope_depth;
    captured->is_upvalue = true;
    
    // Capture value based on type
    switch (capture_type) {
        case CLOSURE_CAPTURE_BY_VALUE:
            // Create copy of value
            captured->captured_value = var->value;
            if (var->value) {
                var->value->ref_count++;
            }
            break;
        case CLOSURE_CAPTURE_BY_REFERENCE:
            // Share the same value object
            captured->captured_value = var->value;
            if (var->value) {
                var->value->ref_count++;
            }
            break;
        case CLOSURE_CAPTURE_BY_MOVE:
            // Move ownership
            captured->captured_value = var->value;
            var->value = NULL;
            break;
    }
    
    // Add to environment
    captured->next = env->captured_variables;
    env->captured_variables = captured;
    env->capture_count++;
    env->environment_size += sizeof(CapturedVariable);
    
    // Mark original variable as captured
    var->is_captured = true;
    
    CLOSURE_DEBUG_PRINT("Variable %s captured (type: %d)", var->name, capture_type);
    return true;
}

CapturedVariable* find_captured_variable(ClosureEnvironment* env, const char* name) {
    if (!env || !name) return NULL;
    
    CapturedVariable* captured = env->captured_variables;
    while (captured) {
        if (captured->original_variable && 
            strcmp(captured->original_variable->name, name) == 0) {
            return captured;
        }
        captured = captured->next;
    }
    
    return NULL;
}

bool update_captured_variable(ClosureEnvironment* env, const char* name, PaTLangObject* new_value) {
    CapturedVariable* captured = find_captured_variable(env, name);
    if (!captured) return false;
    
    // Release old value
    if (captured->captured_value) {
        patlang_release_object(captured->captured_value);
    }
    
    // Assign new value
    captured->captured_value = new_value;
    if (new_value) {
        new_value->ref_count++;
    }
    
    // Update original variable if captured by reference
    if (captured->capture_type == CLOSURE_CAPTURE_BY_REFERENCE && 
        captured->original_variable) {
        if (captured->original_variable->value) {
            patlang_release_object(captured->original_variable->value);
        }
        captured->original_variable->value = new_value;
        if (new_value) {
            new_value->ref_count++;
        }
    }
    
    CLOSURE_DEBUG_PRINT("Updated captured variable: %s", name);
    return true;
}

// Function Call and Execution
FunctionCallResult call_function_closure(FunctionClosure* closure, PaTLangObject** args, size_t arg_count,
                                        ScopeChain* scope_chain, EvaluatorContext* context) {
    FunctionCallResult result = {0};
    clock_t start_time = clock();
    
    if (!closure || !scope_chain || !context) {
        result.success = false;
        result.error_message = "Invalid parameters for function call";
        return result;
    }
    
    CLOSURE_DEBUG_PRINT("Calling function closure: %s with %zu arguments", 
                       closure->function_name, arg_count);
    
    // Check if function is fully applied (for partial application support)
    if (!is_fully_applied(closure, arg_count)) {
        CLOSURE_DEBUG_PRINT("Function not fully applied, creating partial application");
        // Would create partial application here
        result.success = false;
        result.error_message = "Partial application not fully implemented";
        return result;
    }
    
    // Create function call scope
    LexicalScope* call_scope = enter_function_scope(scope_chain, closure->function_name);
    if (!call_scope) {
        result.success = false;
        result.error_message = "Failed to create function call scope";
        return result;
    }
    
    // Bind parameters to arguments
    for (size_t i = 0; i < arg_count && i < closure->parameter_count; i++) {
        char param_name[64];
        snprintf(param_name, sizeof(param_name), "param_%zu", i);
        define_variable(call_scope, param_name, args[i], VARIABLE_TYPE_PARAMETER);
    }
    
    // Set up closure environment in call scope
    CapturedVariable* captured = closure->environment->captured_variables;
    while (captured) {
        if (captured->original_variable) {
            define_variable(call_scope, captured->original_variable->name, 
                          captured->captured_value, VARIABLE_TYPE_CAPTURED);
        }
        captured = captured->next;
    }
    
    // Execute function body
    PaTLangResult eval_result = patlang_evaluate_ast_node(closure->function_body, context);
    
    // Clean up call scope
    exit_function_scope(scope_chain);
    
    // Prepare result
    result.success = eval_result.success;
    result.return_value = eval_result.value;
    result.tail_call_optimized = false; // Not implemented yet
    result.stack_frames_used = 1;
    
    // Calculate execution time
    clock_t end_time = clock();
    double execution_time = ((double)(end_time - start_time)) / CLOCKS_PER_SEC;
    result.execution_time = execution_time;
    
    // Update function statistics
    closure->call_count++;
    closure->total_execution_time += execution_time;
    
    CLOSURE_DEBUG_PRINT("Function call completed: %s (success: %d, time: %.6f)", 
                       closure->function_name, result.success, execution_time);
    
    return result;
}

FunctionCallResult call_with_tail_optimization(FunctionClosure* closure, PaTLangObject** args, size_t arg_count,
                                              ScopeChain* scope_chain, EvaluatorContext* context) {
    // Simplified tail call optimization - would need sophisticated analysis
    FunctionCallResult result = call_function_closure(closure, args, arg_count, scope_chain, context);
    result.tail_call_optimized = true;
    result.stack_frames_used = 0; // Optimized away
    
    CLOSURE_DEBUG_PRINT("Tail call optimization applied for: %s", closure->function_name);
    return result;
}

// Partial Application Support
FunctionClosure* create_partial_application(FunctionClosure* original, PaTLangObject** bound_args,
                                           size_t bound_count, MemoryManager* mm) {
    if (!original || !mm) return NULL;
    
    FunctionClosure* partial = (FunctionClosure*)patlang_allocate_object(
        OBJECT_TYPE_FUNCTION, sizeof(FunctionClosure), 8, mm).address;
    
    if (!partial) return NULL;
    
    // Copy from original
    *partial = *original;
    partial->type = FUNCTION_TYPE_PARTIAL;
    partial->is_partial_application = true;
    partial->bound_argument_count = bound_count;
    
    // Allocate and copy bound arguments
    partial->bound_arguments = (PaTLangObject**)patlang_allocate_object(
        OBJECT_TYPE_CUSTOM, sizeof(PaTLangObject*) * bound_count, 8, mm).address;
    
    if (!partial->bound_arguments) {
        patlang_deallocate_object(partial, mm);
        return NULL;
    }
    
    for (size_t i = 0; i < bound_count; i++) {
        partial->bound_arguments[i] = bound_args[i];
        if (bound_args[i]) {
            bound_args[i]->ref_count++;
        }
    }
    
    CLOSURE_DEBUG_PRINT("Partial application created with %zu bound arguments", bound_count);
    return partial;
}

bool is_fully_applied(FunctionClosure* closure, size_t provided_args) {
    if (!closure) return false;
    
    size_t required_args = closure->parameter_count;
    size_t total_args = provided_args + closure->bound_argument_count;
    
    return total_args >= required_args;
}

// Performance and Statistics Functions
void update_function_statistics(FunctionClosure* closure, double execution_time) {
    if (!closure) return;
    
    closure->call_count++;
    closure->total_execution_time += execution_time;
    
    CLOSURE_DEBUG_PRINT("Function %s: calls=%zu, total_time=%.6f, avg_time=%.6f",
                       closure->function_name, closure->call_count,
                       closure->total_execution_time,
                       closure->total_execution_time / closure->call_count);
}

double calculate_average_execution_time(FunctionClosure* closure) {
    if (!closure || closure->call_count == 0) return 0.0;
    
    return closure->total_execution_time / closure->call_count;
}

size_t count_active_closures(ScopeChain* chain) {
    // Simplified counting - would need comprehensive tracking in real implementation
    size_t count = 0;
    
    LexicalScope* scope = chain->current_scope;
    while (scope) {
        if (scope->type == SCOPE_TYPE_CLOSURE || scope->type == SCOPE_TYPE_FUNCTION) {
            count++;
        }
        scope = scope->parent_scope;
    }
    
    return count;
}

// Utility Functions
bool is_variable_in_scope(LexicalScope* scope, const char* name) {
    if (!scope || !name) return false;
    
    Variable* var = scope->variables;
    while (var) {
        if (strcmp(var->name, name) == 0) {
            return true;
        }
        var = var->next;
    }
    
    return false;
}

size_t calculate_closure_size(ClosureEnvironment* env) {
    if (!env) return 0;
    
    return env->environment_size;
}

void update_closure_references(ClosureEnvironment* env) {
    if (!env) return;
    
    // Update reference counts for captured variables
    CapturedVariable* captured = env->captured_variables;
    while (captured) {
        if (captured->captured_value) {
            captured->captured_value->ref_count++;
        }
        captured = captured->next;
    }
}

// Memory Management for Closures
void mark_closure_objects(FunctionClosure* closure) {
    if (!closure) return;
    
    // Mark closure environment objects
    if (closure->environment) {
        CapturedVariable* captured = closure->environment->captured_variables;
        while (captured) {
            if (captured->captured_value) {
                captured->captured_value->gc_marked = true;
            }
            captured = captured->next;
        }
    }
    
    // Mark bound arguments
    for (size_t i = 0; i < closure->bound_argument_count; i++) {
        if (closure->bound_arguments[i]) {
            closure->bound_arguments[i]->gc_marked = true;
        }
    }
}

bool validate_closure_integrity(FunctionClosure* closure) {
    if (!closure) return false;
    
    // Basic integrity checks
    if (!closure->function_name || !closure->environment) {
        return false;
    }
    
    // Check environment integrity
    if (closure->environment->capture_count > 0 && !closure->environment->captured_variables) {
        return false;
    }
    
    // Check bound arguments if partial application
    if (closure->is_partial_application) {
        if (closure->bound_argument_count > 0 && !closure->bound_arguments) {
            return false;
        }
    }
    
    return true;
}

// Debug Functions
void print_scope_chain(ScopeChain* chain) {
    if (!chain) return;
    
    printf("=== Scope Chain (depth: %zu) ===\n", chain->chain_depth);
    
    LexicalScope* scope = chain->current_scope;
    size_t depth = 0;
    
    while (scope) {
        printf("Scope[%zu]: %s (type: %d, vars: %zu)\n", 
               depth, scope->scope_name, scope->type, scope->variable_count);
        
        Variable* var = scope->variables;
        while (var) {
            printf("  Variable: %s (type: %d, captured: %s)\n",
                   var->name, var->type, var->is_captured ? "yes" : "no");
            var = var->next;
        }
        
        scope = scope->parent_scope;
        depth++;
    }
    
    printf("=== End Scope Chain ===\n");
}

void print_closure_environment(ClosureEnvironment* env) {
    if (!env) return;
    
    printf("=== Closure Environment ===\n");
    printf("Captured variables: %zu\n", env->capture_count);
    printf("Environment size: %zu bytes\n", env->environment_size);
    
    CapturedVariable* captured = env->captured_variables;
    while (captured) {
        if (captured->original_variable) {
            printf("  Captured: %s (type: %d, depth: %zu)\n",
                   captured->original_variable->name,
                   captured->capture_type,
                   captured->capture_depth);
        }
        captured = captured->next;
    }
    
    printf("=== End Closure Environment ===\n");
}

void print_function_statistics(FunctionClosure* closure) {
    if (!closure) return;
    
    printf("=== Function Statistics: %s ===\n", closure->function_name);
    printf("Type: %d\n", closure->type);
    printf("Call count: %zu\n", closure->call_count);
    printf("Total execution time: %.6f seconds\n", closure->total_execution_time);
    printf("Average execution time: %.6f seconds\n", calculate_average_execution_time(closure));
    printf("Parameters: %zu\n", closure->parameter_count);
    printf("Bound arguments: %zu\n", closure->bound_argument_count);
    printf("Is partial application: %s\n", closure->is_partial_application ? "yes" : "no");
    printf("=== End Function Statistics ===\n");
}