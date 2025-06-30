#ifndef ARITHMETIC_EVALUATOR_H
#define ARITHMETIC_EVALUATOR_H
// Removed circular include of runtime.h
#include "arithmetic_types.h"


// Supported arithmetic operations
typedef enum {
    ARITH_OP_ADD,
    ARITH_OP_SUBTRACT,
    ARITH_OP_MULTIPLY,
    ARITH_OP_DIVIDE,
    ARITH_OP_MODULO,
    ARITH_OP_UNARY_MINUS,
    ARITH_OP_COMPARE_EQ,
    ARITH_OP_COMPARE_NEQ,
    ARITH_OP_COMPARE_LT,
    ARITH_OP_COMPARE_LTE,
    ARITH_OP_COMPARE_GT,
    ARITH_OP_COMPARE_GTE
} ArithmeticOp;

// Arithmetic evaluation result type
/* ArithmeticResult typedef moved to arithmetic_types.h */

// Evaluate a binary arithmetic operation
ArithmeticResult eval_binary_op(ArithmeticOp op, ArithmeticResult left, ArithmeticResult right);

// Evaluate a unary arithmetic operation
ArithmeticResult eval_unary_op(ArithmeticOp op, ArithmeticResult operand);

// Convert a value to string (for concatenation)
char *arith_convert_to_string(ArithmeticResult value);

#endif // ARITHMETIC_EVALUATOR_H