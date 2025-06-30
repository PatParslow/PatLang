#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "runtime.h"
#include "parser.h"
#include "compat.h"

// Recursive descent parser for +, -, *, /, %, and string concatenation
expr_node_t* parse_expression(const char* expr_str) {
    // Skip leading whitespace
    size_t len;
    while (*expr_str == ' ' || *expr_str == '\t') expr_str++;
    // Remove trailing whitespace
    len = strlen(expr_str);
    while (len > 0 && (expr_str[len-1] == ' ' || expr_str[len-1] == '\t' || expr_str[len-1] == '\n')) {
        ((char*)expr_str)[len-1] = '\0';
        len--;
    }

    // Handle parentheses
    len = strlen(expr_str);
    if (len >= 2 && expr_str[0] == '(' && expr_str[len-1] == ')') {
        // Remove outer parentheses and parse inside
        char inner[256] = {0};
        strncpy(inner, expr_str + 1, len - 2);
        inner[len - 2] = '\0';
        return parse_expression(inner);
    }

    // Find the last + or - not in parentheses (left-to-right associativity)
    int parens = 0;
    int op_pos = -1;
    char op = 0;
    for (int i = len - 1; i >= 0; --i) {
        if (expr_str[i] == ')') parens++;
        if (expr_str[i] == '(') parens--;
        if (parens == 0 && (expr_str[i] == '+' || expr_str[i] == '-')) {
            op_pos = i;
            op = expr_str[i];
            break;
        }
    }
    // If not found, look for * / %
    if (op_pos == -1) {
        parens = 0;
        for (int i = len - 1; i >= 0; --i) {
            if (expr_str[i] == ')') parens++;
            if (expr_str[i] == '(') parens--;
            if (parens == 0 && (expr_str[i] == '*' || expr_str[i] == '/' || expr_str[i] == '%')) {
                op_pos = i;
                op = expr_str[i];
                break;
            }
        }
    }
    // If found, build binary op node (arithmetic or string concat)
    if (op_pos != -1) {
        // Left and right substrings
        char left[128] = {0}, right[128] = {0};
        strncpy(left, expr_str, op_pos);
        left[op_pos] = '\0';
        strncpy(right, expr_str + op_pos + 1, sizeof(right)-1);

        expr_node_t* left_node = parse_expression(left);
        expr_node_t* right_node = parse_expression(right);

        // If either child is a string, treat as string concatenation for '+'
        if (op == '+' &&
            ((left_node && left_node->type == EXPR_STRING) ||
             (right_node && right_node->type == EXPR_STRING))) {
            expr_node_t* node = (expr_node_t*)calloc(1, sizeof(expr_node_t));
            node->type = EXPR_STRING;
            node->value[0] = op;
            node->value[1] = '\0';
            node->left = left_node;
            node->right = right_node;
            return node;
        } else {
            expr_node_t* node = (expr_node_t*)calloc(1, sizeof(expr_node_t));
            node->type = EXPR_ARITHMETIC;
            node->value[0] = op;
            node->value[1] = '\0';
            node->left = left_node;
            node->right = right_node;
            return node;
        }
    }

    // Handle string literals
    if (*expr_str == '"' || *expr_str == '\'') {
        expr_node_t* node = (expr_node_t*)calloc(1, sizeof(expr_node_t));
        node->type = EXPR_STRING;
        // Remove quotes
        size_t slen = strlen(expr_str);
        if (slen >= 2 && expr_str[slen-1] == expr_str[0]) {
            strncpy(node->value, expr_str + 1, slen - 2);
            node->value[slen - 2] = '\0';
        } else {
            strncpy(node->value, expr_str, sizeof(node->value)-1);
        }
        return node;
    }

    // Otherwise, treat as literal or variable
    expr_node_t* node = (expr_node_t*)calloc(1, sizeof(expr_node_t));
    // Detect numeric literal (integer or float)
    char* endptr = NULL;
    double num = strtod(expr_str, &endptr);
    if (endptr && *endptr != '\0') {
        // Not a pure number, treat as variable reference
        node->type = EXPR_LITERAL;
        strncpy(node->value, expr_str, sizeof(node->value)-1);
    } else {
        // Numeric literal
        node->type = EXPR_LITERAL;
        snprintf(node->value, sizeof(node->value), "%g", num);
    }
    return node;
}

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
                        double lval = atof(leftbuf);
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
        }

        line = strtok(NULL, "\n");
    }
    free(src_copy);
    return error_found;

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
            
                // Handle single-line if/then statement
                char* stmt_start = then_pos + 4; // skip "then"
                while (*stmt_start == ' ' || *stmt_start == '\t') stmt_start++;
                if (*stmt_start != '\0') {
                    // Parse the statement after "then" as a single line
                    ast_node_t* then_stmt = parse_statement(stmt_start);
                    if_node->then_branch = then_stmt;
                }
            }

            // Parse then/else/end blocks
            ast_node_t* then_head = NULL;
            ast_node_t* then_last = NULL;
            ast_node_t* else_head = NULL;
            ast_node_t* else_last = NULL;
            int in_then = 1, in_else = 0;
            line = strtok(NULL, "\n");
            while (line) {
                while (*line == ' ' || *line == '\t') line++;
                if (strncmp(line, "else", 4) == 0) {
                    in_then = 0;
                    in_else = 1;
                    line = strtok(NULL, "\n");
                    continue;
                }
                if (strncmp(line, "end", 3) == 0) {
                    line = strtok(NULL, "\n");
                    break;
                }
                // Recursively parse statements in then/else
                ast_node_t* sub_node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
                if (strncmp(line, "print ", 6) == 0) {
                    printf("[DEBUG][parser] Parsing print statement: '%s'\n", line);
                    sub_node->type = AST_PRINT;
                    char* expr_str = line + 6;
                    // Build expression tree for print
                    sub_node->expr = parse_expression(expr_str);
                    if (sub_node->expr) {
                        printf("[DEBUG][parser] Print node expr parsed, type=%d\n", sub_node->expr->type);
                    } else {
                        printf("[DEBUG][parser] Print node expr parse failed\n");
                    }
                } else {
                    char* eq = strchr(line, '=');
                    if (eq) {
                        sub_node->type = AST_ASSIGN;
                        size_t var_len = eq - line;
                        while (var_len > 0 && (line[var_len-1] == ' ' || line[var_len-1] == '\t')) var_len--;
                        strncpy(sub_node->var_name, line, var_len);
                        sub_node->var_name[var_len] = '\0';
                        char* val = eq + 1;
                        while (*val == ' ' || *val == '\t') val++;
                        // Build expression tree for assignment
                        sub_node->expr = parse_expression(val);
                    } else {
                        free(sub_node);
                        line = strtok(NULL, "\n");
                        continue;
                    }
                }
                sub_node->next = NULL;
                if (in_then) {
                    if (!then_head) then_head = sub_node;
                    else then_last->next = sub_node;
                    then_last = sub_node;
                } else if (in_else) {
                    if (!else_head) else_head = sub_node;
                    else else_last->next = sub_node;
                    else_last = sub_node;
                }
                line = strtok(NULL, "\n");
            }
            if_node->then_branch = then_head;
            if_node->else_branch = else_head;
            if_node->next = NULL;
            if (!ast.head) {
                ast.head = if_node;
            } else {
                last->next = if_node;
            }
            last = if_node;
            continue;
        }

        // WHILE parsing
        if (strncmp(line, "while ", 6) == 0) {
            ast_node_t* while_node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
            while_node->type = AST_WHILE;
            char* cond_start = line + 6;
            char* do_pos = strstr(cond_start, "do");
            if (do_pos) {
                size_t cond_len = do_pos - cond_start;
                char cond_buf[128] = {0};
                strncpy(cond_buf, cond_start, cond_len);
                cond_buf[cond_len] = '\0';
                while_node->while_cond_expr = parse_expression(cond_buf);

                // Parse body
                ast_node_t* body_head = NULL;
                ast_node_t* body_last = NULL;
                line = strtok(NULL, "\n");
                while (line) {
                    while (*line == ' ' || *line == '\t') line++;
                    if (strncmp(line, "end", 3) == 0) {
                        line = strtok(NULL, "\n");
                        break;
                    }
                    ast_node_t* sub_node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
                    if (strncmp(line, "print ", 6) == 0) {
                        sub_node->type = AST_PRINT;
                        char* expr_str = line + 6;
                        sub_node->expr = parse_expression(expr_str);
                    } else {
                        char* eq = strchr(line, '=');
                        if (eq) {
                            sub_node->type = AST_ASSIGN;
                            size_t var_len = eq - line;
                            while (var_len > 0 && (line[var_len-1] == ' ' || line[var_len-1] == '\t')) var_len--;
                            strncpy(sub_node->var_name, line, var_len);
                            sub_node->var_name[var_len] = '\0';
                            char* val = eq + 1;
                            while (*val == ' ' || *val == '\t') val++;
                            sub_node->expr = parse_expression(val);
                        } else {
                            free(sub_node);
                            line = strtok(NULL, "\n");
                            continue;
                        }
                    }
                    sub_node->next = NULL;
                    if (!body_head) body_head = sub_node;
                    else body_last->next = sub_node;
                    body_last = sub_node;
                    line = strtok(NULL, "\n");
                }
                while_node->while_body = body_head;
                while_node->next = NULL;
                if (!ast.head) {
                    ast.head = while_node;
                } else {
                    last->next = while_node;
                }
                last = while_node;
                continue;
            }
        }

        ast_node_t* node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
        if (strncmp(line, "print ", 6) == 0) {
            node->type = AST_PRINT;
            char* expr_str = line + 6;
            // Build expression tree for print
            node->expr = parse_expression(expr_str);
        } else {
            // Look for assignment: var = value
            char* eq = strchr(line, '=');
            if (eq) {
                node->type = AST_ASSIGN;
                size_t var_len = eq - line;
                while (var_len > 0 && (line[var_len-1] == ' ' || line[var_len-1] == '\t')) var_len--;
                strncpy(node->var_name, line, var_len);
                node->var_name[var_len] = '\0';
                // Skip spaces after '='
                char* val = eq + 1;
                while (*val == ' ' || *val == '\t') val++;
                // Build expression tree for assignment
                node->expr = parse_expression(val);
            } else {
                free(node);
                line = strtok(NULL, "\n");
                continue;
            }
        }
        node->next = NULL;
        if (!ast.head) {
            ast.head = node;
        } else {
            last->next = node;
        }
        last = node;
        line = strtok(NULL, "\n");
    }
    free(src_copy);

    run_program(&ast);

    // Free AST nodes
    ast_node_t* cur = ast.head;
    while (cur) {
        ast_node_t* next = cur->next;
        free(cur);
        cur = next;
    }
}