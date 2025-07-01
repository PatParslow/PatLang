#ifndef RUNTIME_H
#define RUNTIME_H
#include "arithmetic_types.h"
#include "ast.h"


// Stub for program execution
void run_program(ast_t* ast);

typedef struct {
    char name[64];
    double value;
    char* string_value;
    int type; // 0 = unset, 1 = number, 2 = string
    int is_set;
} variable_entry_t;

#define MAX_VARIABLES 128

double get_variable(const char* name, int* found);
char* get_variable_string(const char* name, int* found);
void set_variable(const char* name, double value);
void set_variable_string(const char* name, const char* value);

ArithmeticResult eval_expr(ast_node_t* expr);

#endif // RUNTIME_H