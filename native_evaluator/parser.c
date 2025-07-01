#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "runtime.h"
#include "parser.h"
#include "compat.h"

// Forward declarations and globals for parser state
#include "ast.h"

static ast_list_t ast = {NULL};
static ast_node_t* last = NULL;

// Forward declaration for parse_statement
/* static struct ast_node* parse_statement(const char* line); // Unused */
// Forward declaration for parse_expression
ast_node_t* parse_expression(const char* src);
// Recursive descent parser for +, -, *, /, %, and string concatenation
/* Removed all expr_node_t* and parse_expression logic: all expressions now use ast_node_t* */

int parse_patlang(const char* source) {
    printf("Parser: parse_patlang invoked on source buffer.\n");

    int error_found = 0;
    char* src_copy = strdup(source);
    char* line = strtok(src_copy, "\n");
    while (line) {
        // Skip leading whitespace
        while (*line == ' ' || *line == '\t') line++;
        if (*line == '\0') {
            line = strtok(NULL, "\n");
            continue;
        }

        // Assignment parsing (not "if ...")
        char* eq = strchr(line, '=');
        if (eq && strncmp(line, "if ", 3) != 0) {
            // Assignment statement
            char varname[64] = {0};
            size_t varlen = eq - line;
            if (varlen >= sizeof(varname)) varlen = sizeof(varname) - 1;
            strncpy(varname, line, varlen);
            varname[varlen] = '\0';
            // Remove trailing whitespace from varname
            for (int i = varlen - 1; i >= 0 && (varname[i] == ' ' || varname[i] == '\t'); --i) {
                varname[i] = '\0';
            }
            char* after_eq = eq + 1;
            while (*after_eq == ' ' || *after_eq == '\t') after_eq++;
            if (*after_eq == '\0') {
                printf("Syntax error: incomplete assignment near '%s'\n", line);
                error_found = 1;
            } else {
                ast_node_t* assign_node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
                assign_node->type = AST_ASSIGN;
                strncpy(assign_node->var_name, varname, sizeof(assign_node->var_name) - 1);
                assign_node->expr = parse_expression(after_eq);
                // Add to AST list
                if (!ast.head) {
                    ast.head = assign_node;
                    last = assign_node;
                } else {
                    last->next = assign_node;
                    last = assign_node;
                }
                printf("[DEBUG][parser] Added AST_ASSIGN node for variable '%s'\n", varname);
            }
        } else if (strncmp(line, "print ", 6) == 0) {
            // Print statement
            ast_node_t* print_node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
            print_node->type = AST_PRINT;
            print_node->expr = parse_expression(line + 6);
            // Add to AST list
            if (!ast.head) {
                ast.head = print_node;
                last = print_node;
            } else {
                last->next = print_node;
                last = print_node;
            }
            printf("[DEBUG][parser] Added AST_PRINT node\n");
        } else if (strncmp(line, "if ", 3) == 0) {
            ast_node_t* if_node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
            if_node->type = AST_IF;
            // Parse condition (now supports full expressions)
            char* cond_start = line + 3;
            char* then_pos = strstr(cond_start, "then");
            if (then_pos) {
                size_t cond_len = then_pos - cond_start;
                char cond_buf[128] = {0};
                strncpy(cond_buf, cond_start, cond_len);
                cond_buf[cond_len] = '\0';
                // Build expression tree for condition
                if_node->cond_expr = parse_expression(cond_buf);

                // Parse the statement after "then" as the then_branch
                char* then_stmt = then_pos + 4;
                while (*then_stmt == ' ' || *then_stmt == '\t') then_stmt++;
                if (*then_stmt != '\0') {
                    // Only support print or assignment for single-line then_branch
                    if (strncmp(then_stmt, "print ", 6) == 0) {
                        ast_node_t* print_node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
                        print_node->type = AST_PRINT;
                        print_node->expr = parse_expression(then_stmt + 6);
                        if_node->then_branch = print_node;
                    } else {
                        // Try assignment: look for '='
                        char* eq = strchr(then_stmt, '=');
                        if (eq) {
                            char varname[64] = {0};
                            size_t varlen = eq - then_stmt;
                            if (varlen >= sizeof(varname)) varlen = sizeof(varname) - 1;
                            strncpy(varname, then_stmt, varlen);
                            varname[varlen] = '\0';
                            // Remove trailing whitespace from varname
                            for (int i = varlen - 1; i >= 0 && (varname[i] == ' ' || varname[i] == '\t'); --i) {
                                varname[i] = '\0';
                            }
                            char* after_eq = eq + 1;
                            while (*after_eq == ' ' || *after_eq == '\t') after_eq++;
                            if (*after_eq != '\0') {
                                ast_node_t* assign_node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
                                assign_node->type = AST_ASSIGN;
                                strncpy(assign_node->var_name, varname, sizeof(assign_node->var_name) - 1);
                                assign_node->expr = parse_expression(after_eq);
                                if_node->then_branch = assign_node;
                            }
                        }
                    }
                }
            }
            // Add to AST list
            if (!ast.head) {
                ast.head = if_node;
                last = if_node;
            } else {
                last->next = if_node;
                last = if_node;
            }
        }
        line = strtok(NULL, "\n");
    }
    free(src_copy);
    if (!error_found) {
        run_program(&ast);
    }
    return error_found;
}

// Minimal stub for undefined reference
ast_node_t* parse_expression(const char* src) {
    // Minimal parser for numbers, variables, arithmetic, and relational ops
    char buf[128];
    strncpy(buf, src, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';
    // Remove leading/trailing whitespace
    char* s = buf;
    while (*s == ' ' || *s == '\t') s++;
    size_t len = strlen(s);
    while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t')) s[--len] = '\0';

    // Relational operators (lowest precedence): ==, !=, >=, <=, >, <
    const char* rel_ops[] = {"==", "!=", ">=", "<=", ">", "<"};
    int rel_op_count = 6;
    for (int r = 0; r < rel_op_count; ++r) {
        char* pos = strstr(s, rel_ops[r]);
        if (pos && pos != s) {
            char left[64], right[64];
            size_t l_len = pos - s;
            strncpy(left, s, l_len);
            left[l_len] = '\0';
            strncpy(right, pos + strlen(rel_ops[r]), sizeof(right) - 1);
            right[sizeof(right) - 1] = '\0';
            ast_node_t* node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
            node->type = 0;
            node->expr_type = EXPR_ARITHMETIC; // Reuse for relational
            strncpy(node->var_name, rel_ops[r], sizeof(node->var_name) - 1);
            node->expr = parse_expression(left);
            node->next = parse_expression(right);
            return node;
        }
    }

    // Arithmetic: +, -, *, /
    char* ops = "+-*/";
    char* op_pos = NULL;
    char op = 0;
    // Rightmost lowest-precedence operator (+ or -)
    for (int i = len - 1; i >= 0; --i) {
        if (s[i] == '+' || s[i] == '-') {
            op = s[i];
            op_pos = s + i;
            break;
        }
    }
    // If no +/-, look for */ (higher precedence)
    if (!op_pos) {
        for (int i = len - 1; i >= 0; --i) {
            if (s[i] == '*' || s[i] == '/') {
                op = s[i];
                op_pos = s + i;
                break;
            }
        }
    }
    if (op_pos) {
        // Split into left and right
        char left[64], right[64];
        size_t l_len = op_pos - s;
        strncpy(left, s, l_len);
        left[l_len] = '\0';
        strncpy(right, op_pos + 1, sizeof(right) - 1);
        right[sizeof(right) - 1] = '\0';
        ast_node_t* node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
        node->type = 0; // Not a statement node
        node->expr_type = EXPR_ARITHMETIC;
        strncpy(node->var_name, &op, 1);
        node->var_name[1] = '\0';
        node->expr = parse_expression(left);
        node->next = parse_expression(right);
        return node;
    }
    // If quoted string
    if ((*s == '"' && s[len-1] == '"') || (*s == '\'' && s[len-1] == '\'')) {
        ast_node_t* node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
        node->type = 0;
        node->expr_type = EXPR_STRING;
        strncpy(node->var_name, s, sizeof(node->var_name) - 1);
        node->var_name[sizeof(node->var_name) - 1] = '\0';
        return node;
    }
    // Otherwise, treat as literal or variable
    ast_node_t* node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    node->type = 0;
    node->expr_type = EXPR_LITERAL;
    strncpy(node->var_name, s, sizeof(node->var_name) - 1);
    node->var_name[sizeof(node->var_name) - 1] = '\0';
    return node;
}
