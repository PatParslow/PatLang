#ifndef PHASE2_TYPE_INFERENCE_FOUNDATION_H
#define PHASE2_TYPE_INFERENCE_FOUNDATION_H

#include "transpiled_core_evaluator.h"
#include "transpiled_memory_manager.h"
#include "phase2_advanced_goal_system.h"
#include "phase2_function_closure_system.h"
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Type System Types
typedef enum {
    TYPE_UNKNOWN,
    TYPE_NUMBER,
    TYPE_STRING,
    TYPE_BOOLEAN,
    TYPE_ARRAY,
    TYPE_FUNCTION,
    TYPE_OBJECT,
    TYPE_NULL,
    TYPE_UNION,
    TYPE_GENERIC,
    TYPE_CONSTRAINT
} BaseType;

typedef enum {
    TYPE_VARIANCE_COVARIANT,
    TYPE_VARIANCE_CONTRAVARIANT,
    TYPE_VARIANCE_INVARIANT,
    TYPE_VARIANCE_BIVARIANT
} TypeVariance;

typedef enum {
    CONSTRAINT_KIND_EQUALITY,
    CONSTRAINT_KIND_SUBTYPE,
    CONSTRAINT_KIND_SUPERTYPE,
    CONSTRAINT_KIND_INSTANCE,
    CONSTRAINT_KIND_MEMBER
} ConstraintKind;

typedef enum {
    INFERENCE_STRATEGY_UNIFICATION,
    INFERENCE_STRATEGY_CONSTRAINT_SOLVING,
    INFERENCE_STRATEGY_FLOW_ANALYSIS,
    INFERENCE_STRATEGY_BIDIRECTIONAL
} InferenceStrategy;

// Type Structures
typedef struct TypeParameter {
    char* name;
    struct TypeInfo* bound;
    TypeVariance variance;
    bool is_phantom;
    struct TypeParameter* next;
} TypeParameter;

typedef struct TypeInfo {
    BaseType base_type;
    char* type_name;
    size_t type_id;
    TypeParameter* parameters;
    size_t parameter_count;
    struct TypeInfo* element_type;  // For arrays
    struct TypeInfo* return_type;   // For functions
    struct TypeInfo** arg_types;   // For functions
    size_t arg_count;
    struct TypeInfo** union_types; // For union types
    size_t union_count;
    bool is_nullable;
    bool is_mutable;
    bool is_generic;
    double confidence;
    MemoryManager* memory_manager;
} TypeInfo;

typedef struct TypeConstraint {
    ConstraintKind kind;
    TypeInfo* left_type;
    TypeInfo* right_type;
    char* description;
    bool is_satisfied;
    double priority;
    MemoryManager* memory_manager;
    struct TypeConstraint* next;
} TypeConstraint;

typedef struct TypeEnvironment {
    char** variable_names;
    TypeInfo** variable_types;
    size_t variable_count;
    size_t capacity;
    struct TypeEnvironment* parent;
    TypeConstraint* constraints;
    MemoryManager* memory_manager;
} TypeEnvironment;

typedef struct UnificationContext {
    TypeConstraint* pending_constraints;
    TypeInfo** substitutions;
    size_t substitution_count;
    bool unification_failed;
    char* failure_reason;
    MemoryManager* memory_manager;
} UnificationContext;

typedef struct InferenceContext {
    TypeEnvironment* type_env;
    UnificationContext* unification_ctx;
    InferenceStrategy strategy;
    bool bidirectional_mode;
    size_t max_inference_depth;
    size_t current_depth;
    bool constraint_solving_enabled;
    bool flow_analysis_enabled;
    MemoryManager* memory_manager;
} InferenceContext;

// Type Inference Results
typedef struct TypeInferenceResult {
    bool success;
    TypeInfo* inferred_type;
    TypeConstraint* generated_constraints;
    size_t constraint_count;
    double inference_time;
    double confidence_score;
    char* error_message;
    bool type_error_detected;
} TypeInferenceResult;

typedef struct UnificationResult {
    bool success;
    TypeInfo* unified_type;
    TypeConstraint* residual_constraints;
    size_t substitutions_applied;
    char* error_message;
} UnificationResult;

typedef struct ConstraintSolutionResult {
    bool success;
    TypeInfo** solved_types;
    size_t solved_count;
    TypeConstraint* unsolved_constraints;
    size_t unsolved_count;
    double solution_time;
    char* error_message;
} ConstraintSolutionResult;

// Main Type Inference Functions
InferenceContext* create_inference_context(InferenceStrategy strategy, MemoryManager* mm);
void destroy_inference_context(InferenceContext* ctx);

TypeEnvironment* create_type_environment(TypeEnvironment* parent, MemoryManager* mm);
void destroy_type_environment(TypeEnvironment* env);

// Type Creation and Management
TypeInfo* create_type_info(BaseType base_type, const char* type_name, MemoryManager* mm);
void destroy_type_info(TypeInfo* type);

TypeInfo* create_function_type(TypeInfo* return_type, TypeInfo** arg_types, size_t arg_count, MemoryManager* mm);
TypeInfo* create_array_type(TypeInfo* element_type, MemoryManager* mm);
TypeInfo* create_union_type(TypeInfo** types, size_t type_count, MemoryManager* mm);
TypeInfo* create_generic_type(const char* name, TypeParameter* parameters, MemoryManager* mm);

// Type Environment Management
bool bind_type(TypeEnvironment* env, const char* var_name, TypeInfo* type);
TypeInfo* lookup_type(TypeEnvironment* env, const char* var_name);
bool update_type(TypeEnvironment* env, const char* var_name, TypeInfo* new_type);

// Type Inference Core Functions
TypeInferenceResult infer_expression_type(ast_node_t* expr, InferenceContext* ctx);
TypeInferenceResult infer_literal_type(ast_node_t* literal, InferenceContext* ctx);
TypeInferenceResult infer_binary_op_type(ast_node_t* binary_op, InferenceContext* ctx);
TypeInferenceResult infer_function_call_type(ast_node_t* call, InferenceContext* ctx);
TypeInferenceResult infer_variable_type(ast_node_t* var, InferenceContext* ctx);

// Type Constraint Generation and Solving
TypeConstraint* create_type_constraint(ConstraintKind kind, TypeInfo* left, TypeInfo* right, MemoryManager* mm);
void destroy_type_constraint(TypeConstraint* constraint);

bool add_constraint(InferenceContext* ctx, TypeConstraint* constraint);
ConstraintSolutionResult solve_constraints(InferenceContext* ctx);
bool is_constraint_satisfied(TypeConstraint* constraint);

// Type Unification
UnificationResult unify_types(TypeInfo* type1, TypeInfo* type2, UnificationContext* ctx);
UnificationResult unify_function_types(TypeInfo* func1, TypeInfo* func2, UnificationContext* ctx);
UnificationResult unify_array_types(TypeInfo* arr1, TypeInfo* arr2, UnificationContext* ctx);
bool occurs_check(TypeInfo* var_type, TypeInfo* target_type);

// Type Checking and Validation
bool is_subtype(TypeInfo* sub, TypeInfo* super);
bool is_assignable(TypeInfo* from, TypeInfo* to);
bool are_types_compatible(TypeInfo* type1, TypeInfo* type2);
bool is_well_formed_type(TypeInfo* type);

// Type Optimization and Simplification
TypeInfo* simplify_type(TypeInfo* type, MemoryManager* mm);
TypeInfo* normalize_type(TypeInfo* type, MemoryManager* mm);
TypeInfo* instantiate_generic_type(TypeInfo* generic_type, TypeInfo** type_args, size_t arg_count, MemoryManager* mm);

// Flow Analysis Support
TypeInfo* analyze_control_flow_type(ast_node_t* control_flow, InferenceContext* ctx);
TypeInfo* merge_branch_types(TypeInfo** branch_types, size_t branch_count, MemoryManager* mm);
bool propagate_type_information(ast_node_t* node, TypeInfo* expected_type, InferenceContext* ctx);

// Bidirectional Type Checking
TypeInferenceResult check_against_type(ast_node_t* expr, TypeInfo* expected_type, InferenceContext* ctx);
TypeInferenceResult synthesize_type(ast_node_t* expr, InferenceContext* ctx);
TypeInfo* apply_type_application(TypeInfo* poly_type, TypeInfo** type_args, size_t arg_count, MemoryManager* mm);

// Generic Type Support
TypeParameter* create_type_parameter(const char* name, TypeInfo* bound, TypeVariance variance, MemoryManager* mm);
void destroy_type_parameter(TypeParameter* param);

bool is_generic_type(TypeInfo* type);
TypeInfo* instantiate_type_parameters(TypeInfo* type, TypeParameter* params, TypeInfo** args, MemoryManager* mm);

// Type Annotation and Metadata
bool annotate_ast_with_types(ast_node_t* node, InferenceContext* ctx);
TypeInfo* extract_type_annotation(ast_node_t* node);
void attach_type_information(ast_node_t* node, TypeInfo* type);

// Performance and Statistics
void update_inference_statistics(InferenceContext* ctx, TypeInferenceResult* result);
double calculate_inference_complexity(ast_node_t* expr);
size_t count_type_variables(TypeInfo* type);

// Error Handling and Reporting
char* format_type_error(TypeInfo* expected, TypeInfo* actual);
char* format_unification_error(TypeInfo* type1, TypeInfo* type2);
bool report_type_mismatch(ast_node_t* node, TypeInfo* expected, TypeInfo* actual);

// Utility Functions
char* type_to_string(TypeInfo* type);
bool types_equal(TypeInfo* type1, TypeInfo* type2);
TypeInfo* copy_type(TypeInfo* type, MemoryManager* mm);
size_t calculate_type_hash(TypeInfo* type);

// Debug and Introspection
void print_type_info(TypeInfo* type);
void print_type_environment(TypeEnvironment* env);
void print_constraint_system(InferenceContext* ctx);
void print_unification_context(UnificationContext* ctx);

// Main Type Inference Function - CRITICAL FOR PERFORMANCE
TypeInferenceResult perform_type_inference(ast_node_t* expression, InferenceContext* ctx);

// Integration Functions for Phase 2 Systems
struct GoalEvaluationContext;  // Forward declaration
struct ScopeChain;            // Forward declaration

bool integrate_goal_types(TypeEnvironment* env, struct GoalEvaluationContext* goal_ctx);
bool integrate_closure_types(TypeEnvironment* env, struct ScopeChain* scope_chain);

// Type Inference Cache Management
TypeInferenceResult* lookup_cached_inference(ast_node_t* expr, InferenceContext* ctx);
void cache_inference_result(ast_node_t* expr, TypeInferenceResult* result, InferenceContext* ctx);

#ifdef __cplusplus
}
#endif

#endif // PHASE2_TYPE_INFERENCE_FOUNDATION_H