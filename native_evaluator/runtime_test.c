/*
 * runtime_test.c
 * Tests for variable assignment, lookup, reference, and if/else in Patlang evaluator.
 *
 * Usage:
 *   ./runtime_test [--json]
 *     --json   Output test results in JSON format (pass/fail counts and failed test details).
 *     Standard output remains developer-friendly unless --json is specified.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "arithmetic_evaluator.h"
#include "runtime.h"

int passes = 0, fails = 0;
int json_mode = 0;
#define MAX_FAILS 128
static const char* fail_msg[MAX_FAILS];
static int fail_line[MAX_FAILS];
static const char* fail_file[MAX_FAILS];
static int fail_detail_count = 0;

#define ASSERT_EQ(actual, expected, tol, msg) \
    do { \
        int failed = 0; \
        if ((tol) == 0) { \
            if ((actual) != (expected)) { \
                printf("[FAIL] %s: got %d, expected %d\n", msg, (int)(actual), (int)(expected)); \
                failed = 1; \
            } \
        } else { \
            if (((actual) < (expected) - (tol)) || ((actual) > (expected) + (tol))) { \
                printf("[FAIL] %s: got %g, expected %g\n", msg, (double)(actual), (double)(expected)); \
                failed = 1; \
            } \
        } \
        if (failed) { \
            if (fail_detail_count < MAX_FAILS) { \
                fail_msg[fail_detail_count] = msg; \
                fail_line[fail_detail_count] = __LINE__; \
                fail_file[fail_detail_count] = __FILE__; \
                fail_detail_count++; \
            } \
            fails++; \
        } else { \
            passes++; \
        } \
    } while (0)

#define ASSERT(cond, msg) \
    do { \
        if (!(cond)) { \
            printf("[FAIL] %s\n", msg); \
            if (fail_detail_count < MAX_FAILS) { \
                fail_msg[fail_detail_count] = msg; \
                fail_line[fail_detail_count] = __LINE__; \
                fail_file[fail_detail_count] = __FILE__; \
                fail_detail_count++; \
            } \
            fails++; \
        } else { \
            passes++; \
        } \
    } while (0)

void test_assignment_and_lookup() {
    set_variable("x", 5.0);
    int found = 0;
    double v = get_variable("x", &found);
    ASSERT_EQ(v, 5.0, 1e-9, "x assignment/lookup");
    ASSERT_EQ(found, 1, 0, "x found");
}
// Test for arithmetic and string concatenation
void test_binary_ops_and_concat() {
    // Arithmetic: 1 + 2
    ast_node_t* add_left = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    add_left->type = (ast_type_t)EXPR_LITERAL;
    strncpy(add_left->var_name, "1", sizeof(add_left->var_name)-1);

    ast_node_t* add_right = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    add_right->type = (ast_type_t)EXPR_LITERAL;
    strncpy(add_right->var_name, "2", sizeof(add_right->var_name)-1);

    ast_node_t* add = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    add->type = (ast_type_t)EXPR_ARITHMETIC;
    strncpy(add->var_name, "+", sizeof(add->var_name)-1);
    add->expr = add_left;
    add->next = add_right;

    ArithmeticResult r = eval_expr(add);
    ASSERT_EQ(r.number_value, 3.0, 1e-9, "1 + 2 == 3");
    free(add_left);
    free(add_right);
    free(add);

    // String concat: "a" + "b"
    ast_node_t* s_add_left = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    s_add_left->type = (ast_type_t)EXPR_STRING;
    strncpy(s_add_left->var_name, "a", sizeof(s_add_left->var_name)-1);

    ast_node_t* s_add_right = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    s_add_right->type = (ast_type_t)EXPR_STRING;
    strncpy(s_add_right->var_name, "b", sizeof(s_add_right->var_name)-1);

    ast_node_t* s_add = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    s_add->type = (ast_type_t)EXPR_STRING;
    strncpy(s_add->var_name, "+", sizeof(s_add->var_name)-1);
    s_add->expr = s_add_left;
    s_add->next = s_add_right;

    ArithmeticResult sr = eval_expr(s_add);
    ASSERT(sr.is_string && strcmp(sr.string_value, "ab") == 0, "\"a\" + \"b\" == \"ab\"");
    free(s_add_left);
    free(s_add_right);
    free(s_add);

    // String + number: "foo" + 1
    ast_node_t* sn_add_left = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    sn_add_left->type = (ast_type_t)EXPR_STRING;
    strncpy(sn_add_left->var_name, "foo", sizeof(sn_add_left->var_name)-1);

    ast_node_t* sn_add_right = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    sn_add_right->type = (ast_type_t)EXPR_LITERAL;
    strncpy(sn_add_right->var_name, "1", sizeof(sn_add_right->var_name)-1);

    ast_node_t* sn_add = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    sn_add->type = (ast_type_t)EXPR_STRING;
    strncpy(sn_add->var_name, "+", sizeof(sn_add->var_name)-1);
    sn_add->expr = sn_add_left;
    sn_add->next = sn_add_right;

    ArithmeticResult snr = eval_expr(sn_add);
    ASSERT(snr.is_string && strcmp(snr.string_value, "foo1") == 0, "\"foo\" + 1 == \"foo1\"");
    free(sn_add_left);
    free(sn_add_right);
    free(sn_add);

    // Number + string: 2 + "bar"
    ast_node_t* ns_add_left = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    ns_add_left->type = (ast_type_t)EXPR_LITERAL;
    strncpy(ns_add_left->var_name, "2", sizeof(ns_add_left->var_name)-1);

    ast_node_t* ns_add_right = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    ns_add_right->type = (ast_type_t)EXPR_STRING;
    strncpy(ns_add_right->var_name, "bar", sizeof(ns_add_right->var_name)-1);

    ast_node_t* ns_add = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    ns_add->type = (ast_type_t)EXPR_STRING;
    strncpy(ns_add->var_name, "+", sizeof(ns_add->var_name)-1);
    ns_add->expr = ns_add_left;
    ns_add->next = ns_add_right;

    ArithmeticResult nsr = eval_expr(ns_add);
    ASSERT(nsr.is_string && strcmp(nsr.string_value, "2bar") == 0, "2 + \"bar\" == \"2bar\"");
    free(ns_add_left);
    free(ns_add_right);
    free(ns_add);

    // Nested: ("a" + "b") + "c"
    ast_node_t* nest_left_left = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    nest_left_left->type = (ast_type_t)EXPR_STRING;
    strncpy(nest_left_left->var_name, "a", sizeof(nest_left_left->var_name)-1);

    ast_node_t* nest_left_right = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    nest_left_right->type = (ast_type_t)EXPR_STRING;
    strncpy(nest_left_right->var_name, "b", sizeof(nest_left_right->var_name)-1);

    ast_node_t* nest_left = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    nest_left->type = (ast_type_t)EXPR_STRING;
    strncpy(nest_left->var_name, "+", sizeof(nest_left->var_name)-1);
    nest_left->expr = nest_left_left;
    nest_left->next = nest_left_right;

    ast_node_t* nest_right = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    nest_right->type = (ast_type_t)EXPR_STRING;
    strncpy(nest_right->var_name, "c", sizeof(nest_right->var_name)-1);

    ast_node_t* nest = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    nest->type = (ast_type_t)EXPR_STRING;
    strncpy(nest->var_name, "+", sizeof(nest->var_name)-1);
    nest->expr = nest_left;
    nest->next = nest_right;

    ArithmeticResult nestr = eval_expr(nest);
    ASSERT(nestr.is_string && strcmp(nestr.string_value, "abc") == 0, "(\"a\"+\"b\")+\"c\" == \"abc\"");
    free(nest_left_left);
    free(nest_left_right);
    free(nest_left);
    free(nest_right);
    free(nest);
}

void test_reference_in_expression() {
    set_variable("a", 10.0);
    set_variable("b", 2.0);
    int found = 0;
    double a = get_variable("a", &found);
    double b = get_variable("b", &found);
    double sum = a + b;
    ASSERT_EQ(sum, 12.0, 1e-9, "a + b");
}

// Test for if/else control flow
void test_if_else_control_flow() {
    // Set up: x = 1
    set_variable("x", 1.0);

    // Build AST for:
    // if x == 1 then
    //   y = 42
    // else
    //   y = 99
    // end

    // Construct then branch: y = 42
    ast_node_t* then_node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    then_node->type = AST_ASSIGN;
    strncpy(then_node->var_name, "y", sizeof(then_node->var_name)-1);
    then_node->expr = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    then_node->expr->type = (ast_type_t)EXPR_LITERAL;
    strncpy(then_node->expr->var_name, "42", sizeof(then_node->expr->var_name)-1);

    // Construct else branch: y = 99
    ast_node_t* else_node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    else_node->type = AST_ASSIGN;
    strncpy(else_node->var_name, "y", sizeof(else_node->var_name)-1);
    else_node->expr = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    else_node->expr->type = (ast_type_t)EXPR_LITERAL;
    strncpy(else_node->expr->var_name, "99", sizeof(else_node->expr->var_name)-1);

    // Construct condition: x == 1 as a binary expression
    ast_node_t* cond_left = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    cond_left->type = (ast_type_t)EXPR_LITERAL;
    strncpy(cond_left->var_name, "x", sizeof(cond_left->var_name)-1);

    ast_node_t* cond_right = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    cond_right->type = (ast_type_t)EXPR_LITERAL;
    strncpy(cond_right->var_name, "1", sizeof(cond_right->var_name)-1);

    ast_node_t* cond_expr = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    cond_expr->type = (ast_type_t)EXPR_ARITHMETIC; // Use EXPR_ARITHMETIC for binary ops
    strncpy(cond_expr->var_name, "==", sizeof(cond_expr->var_name)-1);
    cond_expr->expr = cond_left;
    cond_expr->next = cond_right;

    // Construct if node
    ast_node_t* if_node = (ast_node_t*)calloc(1, sizeof(ast_node_t));
    if_node->type = AST_IF;
    if_node->cond_expr = cond_expr;
    if_node->then_branch = then_node;
    if_node->else_branch = else_node;

    ast_t ast = { .head = if_node };
    run_program(&ast);

    int found = 0;
    double y_val = get_variable("y", &found);
    ASSERT_EQ(y_val, 42.0, 1e-9, "if/else then branch executed");
    ASSERT_EQ(found, 1, 0, "y found after if/else");

    // Now test else branch: x = 0
    set_variable("x", 0.0);
    // Reset y
    set_variable("y", 0.0);
    run_program(&ast);
    y_val = get_variable("y", &found);
    ASSERT_EQ(y_val, 99.0, 1e-9, "if/else else branch executed");
    ASSERT_EQ(found, 1, 0, "y found after else branch");

    free(then_node->expr);
    free(then_node);
    free(else_node->expr);
    free(else_node);
    free(cond_left);
    free(cond_right);
    free(cond_expr);
    free(if_node);
}

int main(int argc, char** argv) {
    int json_mode = 0;
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--json") == 0) {
            json_mode = 1;
        }
    }
    test_assignment_and_lookup();
    test_reference_in_expression();
    test_if_else_control_flow();
    if (json_mode) {
        printf("{\n");
        printf("  \"passed\": %d,\n", passes);
        printf("  \"failed\": %d,\n", fails);
        printf("  \"failures\": [\n");
        for (int i = 0; i < fail_detail_count; ++i) {
            printf("    {\"file\": \"%s\", \"line\": %d, \"message\": \"%s\"}%s\n",
                fail_file[i], fail_line[i], fail_msg[i],
                (i + 1 < fail_detail_count) ? "," : "");
        }
        printf("  ]\n}\n");
    } else {
        if (!json_mode) printf("Runtime variable tests: %d passed, %d failed\n", passes, fails);
    }
    return fails ? 1 : 0;
}