#ifndef PHASE2_FUNCTION_CLOSURE_SYSTEM_H
#define PHASE2_FUNCTION_CLOSURE_SYSTEM_H

#include "transpiled_core_evaluator.h"
#include "transpiled_memory_manager.h"
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Function Closure System Types
typedef enum {
    SCOPE_TYPE_GLOBAL,
    SCOPE_TYPE_FUNCTION,
    SCOPE_TYPE_BLOCK,
    SCOPE_TYPE_CLOSURE,
    SCOPE_TYPE_MODULE
} ScopeType;

typedef enum {
    VARIABLE_TYPE_LOCAL,
    VARIABLE_TYPE_CAPTURED,
    VARIABLE_TYPE_PARAMETER,
    VARIABLE_TYPE_UPVALUE,
    VARIABLE_TYPE_GLOBAL
} VariableType;

typedef enum {
    CLOSURE_CAPTURE_BY_VALUE,
    CLOSURE_CAPTURE_BY_REFERENCE,
    CLOSURE_CAPTURE_BY_MOVE
} CaptureType;

typedef enum {
    FUNCTION_TYPE_REGULAR,
    FUNCTION_TYPE_CLOSURE,
    FUNCTION_TYPE_PARTIAL,
    FUNCTION_TYPE_HIGHER_ORDER,
    FUNCTION_TYPE_NATIVE
} FunctionType;

// Lexical Scoping Structures
typedef struct Variable {
    char* name;
    PaTLangObject* value;
    VariableType type;
    size_t scope_depth;
    bool is_mutable;
    bool is_captured;
    size_t ref_count;
    struct Variable* next;
} Variable;

typedef struct LexicalScope {
    ScopeType type;
    char* scope_name;
    size_t scope_depth;
    Variable* variables;
    size_t variable_count;
    struct LexicalScope* parent_scope;
    struct LexicalScope* child_scopes;
    struct LexicalScope* next_sibling;
    MemoryManager* memory_manager;
    bool is_closed;
    double creation_time;
} LexicalScope;

typedef struct CapturedVariable {
    Variable* original_variable;
    PaTLangObject* captured_value;
    CaptureType capture_type;
    size_t capture_depth;
    bool is_upvalue;
    struct CapturedVariable* next;
} CapturedVariable;

typedef struct ClosureEnvironment {
    CapturedVariable* captured_variables;
    size_t capture_count;
    LexicalScope* defining_scope;
    size_t environment_size;
    bool is_shared;
    size_t ref_count;
    MemoryManager* memory_manager;
} ClosureEnvironment;

typedef struct FunctionClosure {
    FunctionType type;
    char* function_name;
    ast_node_t* function_body;
    ast_node_t* parameter_list;
    size_t parameter_count;
    ClosureEnvironment* environment;
    LexicalScope* defining_scope;
    bool is_partial_application;
    PaTLangObject** bound_arguments;
    size_t bound_argument_count;
    double creation_time;
    size_t call_count;
    double total_execution_time;
    MemoryManager* memory_manager;
} FunctionClosure;

typedef struct ScopeChain {
    LexicalScope* current_scope;
    LexicalScope* global_scope;
    size_t chain_depth;
    size_t max_depth;
    MemoryManager* memory_manager;
} ScopeChain;

// Function Call Context
typedef struct FunctionCallContext {
    FunctionClosure* function;
    PaTLangObject** arguments;
    size_t argument_count;
    LexicalScope* call_scope;
    ScopeChain* scope_chain;
    EvaluatorContext* base_context;
    bool tail_call_optimization;
    size_t recursion_depth;
    MemoryManager* memory_manager;
} FunctionCallContext;

// Function Evaluation Results
typedef struct ClosureCreationResult {
    bool success;
    FunctionClosure* closure;
    ClosureEnvironment* environment;
    size_t variables_captured;
    double creation_time;
    char* error_message;
} ClosureCreationResult;

typedef struct VariableLookupResult {
    bool found;
    Variable* variable;
    PaTLangObject* value;
    size_t scope_depth;
    bool is_captured;
    bool is_upvalue;
    LexicalScope* containing_scope;
} VariableLookupResult;

typedef struct FunctionCallResult {
    bool success;
    PaTLangObject* return_value;
    bool tail_call_optimized;
    size_t stack_frames_used;
    double execution_time;
    char* error_message;
    bool exception_thrown;
} FunctionCallResult;

// Main Closure System Functions
ScopeChain* create_scope_chain(MemoryManager* mm);
void destroy_scope_chain(ScopeChain* chain);

LexicalScope* create_lexical_scope(ScopeType type, const char* name, LexicalScope* parent, MemoryManager* mm);
void destroy_lexical_scope(LexicalScope* scope);

// Variable Management
Variable* create_variable(const char* name, PaTLangObject* value, VariableType type, MemoryManager* mm);
void destroy_variable(Variable* var);

bool define_variable(LexicalScope* scope, const char* name, PaTLangObject* value, VariableType type);
VariableLookupResult lookup_variable(ScopeChain* chain, const char* name);
bool assign_variable(ScopeChain* chain, const char* name, PaTLangObject* value);

// Scope Management
bool push_scope(ScopeChain* chain, LexicalScope* scope);
LexicalScope* pop_scope(ScopeChain* chain);
LexicalScope* enter_function_scope(ScopeChain* chain, const char* function_name);
void exit_function_scope(ScopeChain* chain);

// Closure Creation and Management
ClosureCreationResult create_function_closure(ast_node_t* function_def, ScopeChain* scope_chain, MemoryManager* mm);
void destroy_function_closure(FunctionClosure* closure);

ClosureEnvironment* create_closure_environment(LexicalScope* defining_scope, MemoryManager* mm);
void destroy_closure_environment(ClosureEnvironment* env);

// Variable Capture Functions
bool capture_variable(ClosureEnvironment* env, Variable* var, CaptureType capture_type);
CapturedVariable* find_captured_variable(ClosureEnvironment* env, const char* name);
bool update_captured_variable(ClosureEnvironment* env, const char* name, PaTLangObject* new_value);

// Function Call and Execution
FunctionCallResult call_function_closure(FunctionClosure* closure, PaTLangObject** args, size_t arg_count, 
                                        ScopeChain* scope_chain, EvaluatorContext* context);
FunctionCallResult call_with_tail_optimization(FunctionClosure* closure, PaTLangObject** args, size_t arg_count,
                                              ScopeChain* scope_chain, EvaluatorContext* context);

// Partial Application Support
FunctionClosure* create_partial_application(FunctionClosure* original, PaTLangObject** bound_args, 
                                           size_t bound_count, MemoryManager* mm);
bool is_fully_applied(FunctionClosure* closure, size_t provided_args);

// Higher-Order Function Support
FunctionCallResult apply_function(FunctionClosure* func, FunctionClosure* arg_func, ScopeChain* scope_chain, 
                                 EvaluatorContext* context);
FunctionClosure* compose_functions(FunctionClosure* f, FunctionClosure* g, MemoryManager* mm);

// Lexical Scoping Utilities
bool is_variable_in_scope(LexicalScope* scope, const char* name);
size_t calculate_closure_size(ClosureEnvironment* env);
void update_closure_references(ClosureEnvironment* env);

// Memory Management for Closures
void mark_closure_objects(FunctionClosure* closure);
void sweep_unused_closures(ScopeChain* chain);
bool validate_closure_integrity(FunctionClosure* closure);

// Performance and Statistics
void update_function_statistics(FunctionClosure* closure, double execution_time);
double calculate_average_execution_time(FunctionClosure* closure);
size_t count_active_closures(ScopeChain* chain);

// Debug and Introspection Functions
void print_scope_chain(ScopeChain* chain);
void print_closure_environment(ClosureEnvironment* env);
void print_function_statistics(FunctionClosure* closure);

#ifdef __cplusplus
}
#endif

#endif // PHASE2_FUNCTION_CLOSURE_SYSTEM_H