#define _GNU_SOURCE
#include <sys/stat.h>
int native_mkdir(const char *path) {
    return mkdir(path, 0777);
}
#include <fcntl.h>
int native_open(const char *filename, int flags) {
    return open(filename, flags, 0644);
}
#include <stdio.h>
#include "runtime.h"

#include "arithmetic_evaluator.h"
#include "string_evaluator.h"
#define _GNU_SOURCE
#include <string.h>
#include <stdlib.h>
// Recursively evaluate an expression tree
// Recursive evaluator for ast_node_t supporting arithmetic and string concatenation
ArithmeticResult eval_expr(ast_node_t* expr) {
    if (!expr) {
        ArithmeticResult result = {0};
        result.error = 1;
        result.error_message = "Null expression";
        return result;
    }
    ArithmeticResult result = {0};
    // If this is an expression node (type == 0), dispatch on expr_type
    if (expr->type == 0) {
        switch (expr->expr_type) {
            case EXPR_LITERAL: {
                int found = 0;
                double val = get_variable(expr->var_name, &found);
                if (found) {
                    result.is_number = 1;
                    result.number_value = val;
                } else {
                    char* sval = get_variable_string(expr->var_name, &found);
                    if (found && sval) {
                        result.is_string = 1;
                        result.string_value = sval;
                    } else {
                        char* endptr = NULL;
                        double num = strtod(expr->var_name, &endptr);
                        if (endptr && *endptr == '\0') {
                            result.is_number = 1;
                            result.number_value = num;
                        } else {
                            result.error = 1;
                            result.error_message = "undefined variable";
                        }
                    }
                }
                break;
            }
            case EXPR_STRING: {
                // If this is a binary string operation (e.g., concatenation)
                if (expr->expr && expr->next && expr->var_name[0] == '+') {
                    ArithmeticResult left = eval_expr(expr->expr);
                    ArithmeticResult right = eval_expr(expr->next);
                    if (left.error) return left;
                    if (right.error) return right;
                    // Use arithmetic_evaluator's string concat logic
                    return eval_binary_op(ARITH_OP_ADD, left, right);
                } else {
                    result.is_string = 1;
                    // Remove leading/trailing whitespace and quotes
                    char* v = expr->var_name;
                    while (*v == ' ' || *v == '\t' || *v == '\n') v++;
                    size_t len = strlen(v);
                    while (len > 0 && (v[len-1] == ' ' || v[len-1] == '\t' || v[len-1] == '\n')) {
                        v[len-1] = '\0';
                        len--;
                    }
                    if ((*v == '"' && v[len-1] == '"') || (*v == '\'' && v[len-1] == '\'')) {
                        v[len-1] = '\0';
                        v++;
                    }
                    // Always duplicate for result, but do not store pointer to stack buffer
                    result.string_value = strdup(v);
                }
                break;
            }
            case EXPR_ARITHMETIC: {
                ArithmeticResult left = eval_expr(expr->expr);
                ArithmeticResult right = eval_expr(expr->next);
                if (left.error) return left;
                if (right.error) return right;
                // Support relational operators for conditionals
                if (strcmp(expr->var_name, "==") == 0) {
                    result.is_number = 1;
                    result.number_value = (left.number_value == right.number_value) ? 1.0 : 0.0;
                    return result;
                }
                if (strcmp(expr->var_name, "!=") == 0) {
                    result.is_number = 1;
                    result.number_value = (left.number_value != right.number_value) ? 1.0 : 0.0;
                    return result;
                }
                if (strcmp(expr->var_name, ">") == 0) {
                    result.is_number = 1;
                    result.number_value = (left.number_value > right.number_value) ? 1.0 : 0.0;
                    return result;
                }
                if (strcmp(expr->var_name, "<") == 0) {
                    result.is_number = 1;
                    result.number_value = (left.number_value < right.number_value) ? 1.0 : 0.0;
                    return result;
                }
                if (strcmp(expr->var_name, ">=") == 0) {
                    result.is_number = 1;
                    result.number_value = (left.number_value >= right.number_value) ? 1.0 : 0.0;
                    return result;
                }
                if (strcmp(expr->var_name, "<=") == 0) {
                    result.is_number = 1;
                    result.number_value = (left.number_value <= right.number_value) ? 1.0 : 0.0;
                    return result;
                }
                // Only support +, -, *, /, %
                char op = expr->var_name[0];
                ArithmeticOp aop;
                switch (op) {
                    case '+': aop = ARITH_OP_ADD; break;
                    case '-': aop = ARITH_OP_SUBTRACT; break;
                    case '*': aop = ARITH_OP_MULTIPLY; break;
                    case '/': aop = ARITH_OP_DIVIDE; break;
                    case '%': aop = ARITH_OP_MODULO; break;
                    default:
                        result.error = 1;
                        result.error_message = "Unknown operator";
                        return result;
                }
                return eval_binary_op(aop, left, right);
            }
            default:
                result.error = 1;
                result.error_message = "Unknown expr_type";
                break;
        }
    } else {
        // Not an expression node; should not be evaluated here
        result.error = 1;
        result.error_message = "Invalid node type for eval_expr";
    }
    return result;
}

static variable_entry_t variable_table[MAX_VARIABLES];

double get_variable(const char* name, int* found) {
    for (int i = 0; i < MAX_VARIABLES; ++i) {
        if (variable_table[i].is_set && strcmp(variable_table[i].name, name) == 0 && variable_table[i].type == 1) {
            if (found) *found = 1;
            return variable_table[i].value;
        }
    }
    if (found) *found = 0;
    return 0.0;
}

char* get_variable_string(const char* name, int* found) {
    for (int i = 0; i < MAX_VARIABLES; ++i) {
        if (variable_table[i].is_set && strcmp(variable_table[i].name, name) == 0 && variable_table[i].type == 2) {
            if (found) *found = 1;
            return variable_table[i].string_value;
        }
    }
    if (found) *found = 0;
    return NULL;
}

void set_variable(const char* name, double value) {
    for (int i = 0; i < MAX_VARIABLES; ++i) {
        if (variable_table[i].is_set && strcmp(variable_table[i].name, name) == 0) {
            if (variable_table[i].type == 2 && variable_table[i].string_value) {
                free(variable_table[i].string_value);
                variable_table[i].string_value = NULL;
            }
            variable_table[i].value = value;
            variable_table[i].type = 1;
            variable_table[i].string_value = NULL;
            variable_table[i].string_value = NULL;
            return;
        }
    }
    for (int i = 0; i < MAX_VARIABLES; ++i) {
        if (!variable_table[i].is_set) {
            strncpy(variable_table[i].name, name, sizeof(variable_table[i].name) - 1);
            variable_table[i].name[sizeof(variable_table[i].name) - 1] = '\0';
            variable_table[i].value = value;
            variable_table[i].string_value = NULL;
            variable_table[i].type = 1;
            variable_table[i].is_set = 1;
            return;
        }
    }
}

void set_variable_string(const char* name, const char* value) {
    for (int i = 0; i < MAX_VARIABLES; ++i) {
        if (variable_table[i].is_set && strcmp(variable_table[i].name, name) == 0) {
            if (variable_table[i].type == 2 && variable_table[i].string_value) {
                free(variable_table[i].string_value);
            }
            variable_table[i].string_value = strdup(value);
            variable_table[i].type = 2;
            return;
        }
    }
    for (int i = 0; i < MAX_VARIABLES; ++i) {
        if (!variable_table[i].is_set) {
            strncpy(variable_table[i].name, name, sizeof(variable_table[i].name) - 1);
            variable_table[i].name[sizeof(variable_table[i].name) - 1] = '\0';
            variable_table[i].value = 0.0;
            variable_table[i].string_value = strdup(value);
            variable_table[i].type = 2;
            variable_table[i].is_set = 1;
            return;
        }
    }
}

void run_program(ast_t* ast) {
    ast_node_t* node = ast->head;
    while (node) {
        printf("[DEBUG][runtime] Visiting node type: %d\n", node->type);
        if (node->type == AST_ASSIGN) {
            // Evaluate right-hand side expression
            ArithmeticResult res = eval_expr(node->expr);
            if (res.error) {
                printf("[ERROR] %s\n", res.error_message);
                fflush(stdout);
            } else if (res.is_number) {
                set_variable(node->var_name, res.number_value);
            } else if (res.is_string) {
                set_variable_string(node->var_name, res.string_value);
            }
        } else if (node->type == AST_PRINT) {
            printf("[DEBUG][runtime] Evaluating AST_PRINT node\n");
            ArithmeticResult res = eval_expr(node->expr);
            if (res.error) {
                printf("[ERROR] %s\n", res.error_message);
                fflush(stdout);
            } else if (res.is_string) {
                printf("%s\n", res.string_value);
            } else if (res.is_number) {
                char *outstr = arith_convert_to_string(res);
                printf("%s\n", outstr);
                free(outstr);
            }
        } else if (node->type == AST_IF) {
            // Evaluate condition expression
            ArithmeticResult cond_res = eval_expr(node->cond_expr);
            int cond_true = 0;
            if (!cond_res.error) {
                if (cond_res.is_number)
                    cond_true = (cond_res.number_value != 0.0);
                else if (cond_res.is_string)
                    cond_true = (cond_res.string_value && cond_res.string_value[0] != '\0');
            }
            ast_node_t* branch = cond_true ? node->then_branch : node->else_branch;
            // Execute branch
            ast_node_t* branch_node = branch;
            while (branch_node) {
                // Recurse: run single node as a mini-program
                ast_t branch_ast = { .head = branch_node };
                // Only run the current node, not the whole branch list
                ast_node_t* next_save = branch_node->next;
                branch_node->next = NULL;
                run_program(&branch_ast);
                branch_node->next = next_save;
                branch_node = next_save;
            }
        } else if (node->type == AST_WHILE) {
            // Evaluate while loop
            while (1) {
                ArithmeticResult cond_res = eval_expr(node->while_cond_expr);
                int cond_true = 0;
                if (!cond_res.error) {
                    if (cond_res.is_number)
                        cond_true = (cond_res.number_value != 0.0);
                    else if (cond_res.is_string)
                        cond_true = (cond_res.string_value && cond_res.string_value[0] != '\0');
                }
                if (!cond_true) break;
                ast_node_t* body_node = node->while_body;
                while (body_node) {
                    ast_t body_ast = { .head = body_node };
                    ast_node_t* next_save = body_node->next;
                    body_node->next = NULL;
                    run_program(&body_ast);
                    body_node->next = next_save;
                    body_node = next_save;
                }
            }
        } else if (node->type == AST_FOR) {
            // Evaluate start and end expressions
            ArithmeticResult start_res = eval_expr(node->for_start_expr);
            ArithmeticResult end_res = eval_expr(node->for_end_expr);
            if (start_res.error || end_res.error) {
                printf("[ERROR] Invalid for-loop bounds\n");
            } else {
                int start = (int)start_res.number_value;
                int end = (int)end_res.number_value;
                for (int i = start; i <= end; ++i) {
                    set_variable(node->for_var, (double)i);
                    ast_node_t* body_node = node->for_body;
                    while (body_node) {
                        ast_t body_ast = { .head = body_node };
                        ast_node_t* next_save = body_node->next;
                        body_node->next = NULL;
                        run_program(&body_ast);
                        body_node->next = next_save;
                        body_node = next_save;
                    }
                }
            }
        } else if (node->type == AST_CASE) {
            // Minimal case statement execution for test
            ArithmeticResult case_val = eval_expr(node->case_expr);
            int matched = 0;
            for (int i = 0; i < node->num_when_clauses; ++i) {
                ArithmeticResult when_val = eval_expr(node->when_values[i]);
                // Only support integer/number equality for this test
                if (case_val.is_number && when_val.is_number && case_val.number_value == when_val.number_value) {
                    ast_node_t* body_node = node->when_bodies[i];
                    while (body_node) {
                        ast_t body_ast = { .head = body_node };
                        ast_node_t* next_save = body_node->next;
                        body_node->next = NULL;
                        run_program(&body_ast);
                        body_node->next = next_save;
                        body_node = next_save;
                    }
                    matched = 1;
                    break;
                }
            }
            if (!matched && node->else_body) {
                ast_node_t* body_node = node->else_body;
                while (body_node) {
                    ast_t body_ast = { .head = body_node };
                    ast_node_t* next_save = body_node->next;
                    body_node->next = NULL;
                    run_program(&body_ast);
                    body_node->next = next_save;
                    body_node = next_save;
                }
            }
        } else {
            printf("[UNKNOWN NODE]\n");
        }
        node = node->next;
    }
}