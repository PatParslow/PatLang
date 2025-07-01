#ifndef RUNTIME_H
#define RUNTIME_H
#include "arithmetic_types.h"
#include "ast.h"


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

ArithmeticResult eval_expr(ast_node_t* expr);

#endif // RUNTIME_H