// native_evaluator/parser.h
#ifndef PARSER_H
#define PARSER_H

#ifdef __cplusplus
extern "C" {
#endif

#include "runtime.h"

// Minimal parse interface for integration
// For now, returns void and prints a stub message
int parse_patlang(const char* source);

#ifdef __cplusplus
}
#endif

#endif // PARSER_H