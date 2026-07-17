#ifndef ARITHMETIC_TYPES_H
#define ARITHMETIC_TYPES_H

// Arithmetic evaluation result type
typedef struct {
    int is_number;
    double number_value;
    int is_string;
    char *string_value;
    int error;
    char *error_message;
} ArithmeticResult;

#endif // ARITHMETIC_TYPES_H