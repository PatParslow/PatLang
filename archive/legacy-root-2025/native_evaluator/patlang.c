// patlang.c - CLI skeleton for Patlang interpreter/compiler

#include <stdio.h>
#include <string.h>
#include "loader.h"

#include "cli_common.h"

int main(int argc, char** argv) {
    cli_args_t args;
    int rc = parse_cli_args(argc, argv, &args);
    if (rc != 0) {
        print_usage(argv[0]);
        return 1;
    }
    if (args.mode == CLI_MODE_INTERPRET) {
        printf("Interpret mode selected. Target file: %s\n", args.filename);
        int rc2 = load_and_parse(args.filename);
        return rc2;
    } else if (args.mode == CLI_MODE_COMPILE) {
        printf("Compile mode selected. Target file: %s\n", args.filename);
        int rc2 = load_and_parse(args.filename);
        return rc2;
    }
    // Should not reach here
    return 1;
}