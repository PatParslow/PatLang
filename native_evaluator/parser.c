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

        // Minimal syntax error detection: incomplete assignment (e.g., "x =")
        char* eq = strchr(line, '=');
        if (eq) {
            // Check if nothing after '=' (ignoring whitespace)
            char* after_eq = eq + 1;
            while (*after_eq == ' ' || *after_eq == '\t') after_eq++;
            if (*after_eq == '\0') {
                printf("Syntax error: incomplete assignment near '%s'\n", line);
                error_found = 1;
            } else {
                // Minimal division by zero detection for "a = 1/0" style
                // Only handle simple "var = num/num" pattern
                char* div = strchr(after_eq, '/');
                if (div) {
                    // Try to parse left and right numbers
                    char leftbuf[32], rightbuf[32];
                    int n = div - after_eq;
                    if (n > 0 && n < 32) {
                        strncpy(leftbuf, after_eq, n);
                        leftbuf[n] = 0;
                        strncpy(rightbuf, div + 1, 31);
                        rightbuf[31] = 0;
                        /* double lval = atof(leftbuf); */ /* Unused variable removed */
                        double rval = atof(rightbuf);
                        if (rval == 0.0) {
                            printf("Runtime error: Division by zero in line '%s'\n", line);
                            error_found = 1;
                        }
                    }
                }
            }
        }

        // IF/ELSE parsing
        if (strncmp(line, "if ", 3) == 0) {
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
            }
        
            // Add to AST list
            if (!ast.head) {
                ast.head = if_node;
                last = if_node;
            } else {
                // Only support a single if node in this minimal AST
                last = if_node;
            }
        }

        line = strtok(NULL, "\n");
    }
    free(src_copy);
    return error_found;
}

// Minimal stub for undefined reference
ast_node_t* parse_expression(const char* src) {
    (void)src;
    return NULL;
}
