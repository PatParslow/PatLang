#ifndef STRING_EVALUATOR_H
#define STRING_EVALUATOR_H

#include "runtime.h"

// Supported string operations
typedef enum {
    STR_OP_CONCAT,      // Concatenate two strings (arg1: unused, arg2: pointer to second string as int)
    STR_OP_LENGTH,      // Get length of string (arg1/arg2 unused)
    STR_OP_SUBSTRING,
    STR_OP_STARTS_WITH,
    STR_OP_ENDS_WITH,
    STR_OP_UPPERCASE,
    STR_OP_LOWERCASE,
    STR_OP_TRIM
} StringOp;

// String evaluation result type
typedef struct {
    int is_string;
    char *string_value;
    int is_number;
    double number_value;
    int error;
    char *error_message;
} StringResult;

// Evaluate a string node (literal)
StringResult eval_string_node(const char *value);

// Evaluate index access on a string
StringResult eval_index_access(const char *string, int index);

// Evaluate a string method call
StringResult eval_string_method(StringOp op, const char *string, int arg1, int arg2);

// Convert a value to string (for method dispatch)
char *string_convert_to_string(StringResult value);

#endif // STRING_EVALUATOR_H