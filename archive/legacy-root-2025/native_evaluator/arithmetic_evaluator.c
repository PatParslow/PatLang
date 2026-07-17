#include "arithmetic_evaluator.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "compat.h"

ArithmeticResult eval_binary_op(ArithmeticOp op, ArithmeticResult left, ArithmeticResult right) {
    ArithmeticResult result = {0};
    // Handle string concatenation for addition
    if (op == ARITH_OP_ADD) {
        if (left.is_string && right.is_string) {
            result.is_string = 1;
            size_t len1 = strlen(left.string_value);
            size_t len2 = strlen(right.string_value);
            result.string_value = (char*)malloc(len1 + len2 + 1);
            strcpy(result.string_value, left.string_value);
            strcat(result.string_value, right.string_value);
            return result;
        } else if (left.is_string && right.is_number) {
            result.is_string = 1;
            char numbuf[64];
            snprintf(numbuf, sizeof(numbuf), "%g", right.number_value);
            size_t len1 = strlen(left.string_value);
            size_t len2 = strlen(numbuf);
            result.string_value = (char*)malloc(len1 + len2 + 1);
            strcpy(result.string_value, left.string_value);
            strcat(result.string_value, numbuf);
            return result;
        } else if (left.is_number && right.is_string) {
            result.is_string = 1;
            char numbuf[64];
            snprintf(numbuf, sizeof(numbuf), "%g", left.number_value);
            size_t len1 = strlen(numbuf);
            size_t len2 = strlen(right.string_value);
            result.string_value = (char*)malloc(len1 + len2 + 1);
            strcpy(result.string_value, numbuf);
            strcat(result.string_value, right.string_value);
            return result;
        }
    }
    // Arithmetic operations: both must be numbers
    if (!left.is_number || !right.is_number) {
                result.error = 1;
        result.error_message = strdup("Operands must be numbers");
        return result;
    }
    switch (op) {
        case ARITH_OP_ADD:
            result.is_number = 1;
            result.number_value = left.number_value + right.number_value;
            break;
        case ARITH_OP_SUBTRACT:
            result.is_number = 1;
            result.number_value = left.number_value - right.number_value;
            break;
        case ARITH_OP_MULTIPLY:
            result.is_number = 1;
            result.number_value = left.number_value * right.number_value;
            break;
        case ARITH_OP_DIVIDE:
            if (right.number_value == 0) {
                result.error = 1;
                result.error_message = strdup("Division by zero");
            } else {
                result.is_number = 1;
                result.number_value = left.number_value / right.number_value;
            }
            break;
        default:
            result.error = 1;
            result.error_message = strdup("Operation not implemented");
            break;
    }
    return result;
}

ArithmeticResult eval_unary_op(ArithmeticOp op __attribute__((unused)), ArithmeticResult operand __attribute__((unused))) {
    ArithmeticResult result = {0};
    // Stub: Implement unary arithmetic logic here
    result.error = 1;
    result.error_message = strdup("Not implemented");
    return result;
}

char *arith_convert_to_string(ArithmeticResult value) {
    char buf[128];
    if (value.is_string && value.string_value) {
        return strdup(value.string_value);
    } else if (value.is_number) {
        snprintf(buf, sizeof(buf), "%g", value.number_value);
        return strdup(buf);
    }
    return strdup("");
}