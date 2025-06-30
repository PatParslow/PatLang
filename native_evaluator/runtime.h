#ifndef RUNTIME_H
#define RUNTIME_H
#include "arithmetic_types.h"

// AST node types for minimal Patlang
typedef enum {
    AST_ASSIGN,
    AST_PRINT,
    AST_IF,
    AST_WHILE,
    AST_FOR,
    AST_CASE // Added for case statement support
} ast_node_type_t;

typedef enum {
    EXPR_LITERAL,
    EXPR_ARITHMETIC,
    EXPR_STRING
} expr_type_t;

typedef struct expr_node {
    expr_type_t type;
    char value[256]; // For literals/variables/strings
    struct expr_node* left;
    struct expr_node* right;
} expr_node_t;

typedef struct ast_node {
    ast_node_type_t type;
    char var_name[64];   // For assignment
    expr_node_t* expr;   // Expression for assignment, print, or condition
    struct ast_node* next;

    // For if/else
    expr_node_t* cond_expr;           // Expression for condition
    struct ast_node* then_branch;     // AST for then branch
    struct ast_node* else_branch;     // AST for else branch

    // For while
    expr_node_t* while_cond_expr;     // Condition for while
    struct ast_node* while_body;      // Body of while loop
    // For for-loop
    char for_var[64];              // Loop variable name
    expr_node_t* for_start_expr;   // Start value
    expr_node_t* for_end_expr;     // End value
    struct ast_node* for_body;     // Body of for loop
    // For case statement
    expr_node_t* case_expr;           // Expression to match against
    int num_when_clauses;             // Number of when clauses
    expr_node_t** when_values;        // Array of expressions for when values
    ast_node_t** when_bodies;         // Array of ASTs for when bodies
    ast_node_t* else_body;            // AST for else branch
} ast_node_t;

typedef struct ast_t {
    ast_node_t* head;
} ast_t;

// Stub for program execution
void run_program(ast_t* ast);

typedef struct {
    char name[64];
    double value;
    int is_set;
} variable_entry_t;

#define MAX_VARIABLES 128

double get_variable(const char* name, int* found);
void set_variable(const char* name, double value);

ArithmeticResult eval_expr(expr_node_t* expr);

#endif // RUNTIME_H