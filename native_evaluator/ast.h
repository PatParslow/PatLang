// AST node types and structures for parser/runtime

#ifndef AST_H
#define AST_H

#ifdef __cplusplus
extern "C" {
#endif

// Expression node types
typedef enum {
    EXPR_STRING,
    EXPR_ARITHMETIC,
    EXPR_LITERAL
} expr_type_t;

// Removed expr_node_t; all expressions now use ast_node_t*

// AST node types
typedef enum {
    AST_ASSIGN,
    AST_PRINT,
    AST_IF,
    AST_WHILE,
    AST_FOR,
    AST_CASE,
    AST_INCLUDE
    // Add more as needed
} ast_type_t;

// Forward declaration for ast_node_t
typedef struct ast_node {
    ast_type_t type;
    expr_type_t expr_type; // Only meaningful for expression nodes
    // Common fields
    struct ast_node* next; // For statement lists

    // Assignment
    char var_name[64];
    struct ast_node* expr;

    // IF
    struct ast_node* cond_expr;
    struct ast_node* then_branch;
    struct ast_node* else_branch;

    // WHILE
    struct ast_node* while_cond_expr;
    struct ast_node* while_body;

    // FOR
    char for_var[64];
    struct ast_node* for_start_expr;
    struct ast_node* for_end_expr;
    struct ast_node* for_body;

    // CASE
    struct ast_node* case_expr;
    struct ast_node* when_exprs[8];
    struct ast_node* when_bodies[8];
    int num_when_clauses;
    // All expr_node_t* removed; all expressions are ast_node_t*

    // CASE
    // (removed stray expr_node_t* declarations)
    int when_count;
    struct ast_node* else_body;
    // For pattern matching (Patlang 'when' clauses)
    struct ast_node** when_values;
} ast_node_t;

// AST list type
typedef struct ast_list {
    struct ast_node* head;
} ast_list_t;

// For compatibility with runtime.c
typedef ast_list_t ast_t;

#ifdef __cplusplus
}
#endif

#endif // AST_H