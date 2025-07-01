#ifndef TRANSPILED_CORE_EVALUATOR_H
#define TRANSPILED_CORE_EVALUATOR_H

#include "../native_bridge.h"
#include "../ast.h"
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Evaluator Context Structure
typedef struct {
    ast_node_t** scope_stack;
    size_t scope_depth;
    size_t max_scope_depth;
    size_t recursion_depth;
    size_t max_recursion_depth;
    void* native_bridge;
} EvaluatorContext;

// PaTLang Object Structure
typedef struct {
    void* data;
    size_t size;
    int ref_count;
    bool gc_marked;
} PaTLangObject;

// PaTLang Result Structure
typedef struct {
    PaTLangObject* value;
    char* type_name;
    bool success;
    char* error_message;
    double evaluation_time;
    size_t memory_allocated;
} PaTLangResult;

// Main evaluation functions
PaTLangResult patlang_evaluate_ast_node(ast_node_t* node, EvaluatorContext* context);
PaTLangResult patlang_dispatch_by_node_type(ast_node_t* node, EvaluatorContext* context);
PaTLangResult patlang_evaluate_number_literal(ast_node_t* node, EvaluatorContext* context);
PaTLangResult patlang_evaluate_string_literal(ast_node_t* node, EvaluatorContext* context);
PaTLangResult patlang_evaluate_binary_operation(ast_node_t* node, EvaluatorContext* context);
PaTLangResult patlang_evaluate_function_call(ast_node_t* node, EvaluatorContext* context);
PaTLangResult patlang_evaluate_program(ast_node_t* program_node, EvaluatorContext* context);

// Week 2: Enhanced pattern evaluation functions
PaTLangResult patlang_evaluate_variable_assignment(ast_node_t* node, EvaluatorContext* context);
PaTLangResult patlang_evaluate_if_statement(ast_node_t* node, EvaluatorContext* context);
PaTLangResult patlang_evaluate_while_loop(ast_node_t* node, EvaluatorContext* context);
PaTLangResult patlang_evaluate_complex_expression(ast_node_t* node, EvaluatorContext* context);
PaTLangResult patlang_evaluate_goal_construct(ast_node_t* node, EvaluatorContext* context);

// Week 2: Enhanced binary operation functions
PaTLangResult patlang_perform_binary_operation(char operator, PaTLangResult* left, PaTLangResult* right, EvaluatorContext* context);
PaTLangResult patlang_perform_numeric_operation(char operator, PaTLangResult* left, PaTLangResult* right, EvaluatorContext* context);
PaTLangResult patlang_perform_string_operation(char operator, PaTLangResult* left, PaTLangResult* right, EvaluatorContext* context);

// Week 2: Utility functions for result creation
PaTLangResult patlang_create_number_result(double value);
PaTLangResult patlang_create_boolean_result(bool value);

// Context management functions
EvaluatorContext* create_evaluator_context(size_t max_recursion_depth);
void destroy_evaluator_context(EvaluatorContext* ctx);
bool check_recursion_limit(EvaluatorContext* ctx);

// Memory management functions
void patlang_release_object(PaTLangObject* obj);

#ifdef __cplusplus
}
#endif

#endif // TRANSPILED_CORE_EVALUATOR_H
