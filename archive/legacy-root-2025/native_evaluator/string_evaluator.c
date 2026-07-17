#include "string_evaluator.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "compat.h"

StringResult eval_string_node(const char *value) {
    StringResult result = {0};
    if (value) {
        result.is_string = 1;
        result.string_value = strdup(value);
    } else {
        result.error = 1;
        result.error_message = strdup("Null string literal");
    }
    return result;
}

StringResult eval_index_access(const char *string, int index) {
    StringResult result = {0};
    if (!string) {
        result.error = 1;
        result.error_message = strdup("Null string for indexing");
        return result;
    }
    int len = strlen(string);
    if (index < 0 || index >= len) {
        result.error = 1;
        result.error_message = strdup("Index out of bounds");
        return result;
    }
    result.is_string = 1;
    result.string_value = (char*)malloc(2);
    result.string_value[0] = string[index];
    result.string_value[1] = '\0';
    return result;
}

StringResult eval_string_method(StringOp op, const char *string, int arg1 __attribute__((unused)), int arg2 __attribute__((unused))) {
    StringResult result = {0};
    switch (op) {
        case STR_OP_CONCAT: {
            // Disabled: pointer cast warning, not supported
            result.error = 1;
            result.error_message = strdup("STR_OP_CONCAT not supported due to pointer cast warning");
            break;
        }
        case STR_OP_LENGTH: {
            if (!string) {
                result.error = 1;
                result.error_message = strdup("Null string for length");
                break;
            }
            result.is_number = 1;
            result.number_value = (double)strlen(string);
            break;
        }
        default:
            result.error = 1;
            result.error_message = strdup("String operation not implemented");
            break;
    }
    return result;
}

char *string_convert_to_string(StringResult value) {
    if (value.is_string && value.string_value) {
        return strdup(value.string_value);
    } else if (value.is_number) {
        char buf[32];
        snprintf(buf, sizeof(buf), "%.0f", value.number_value);
        return strdup(buf);
    } else if (value.error && value.error_message) {
        return strdup(value.error_message);
    }
    return strdup("");
}