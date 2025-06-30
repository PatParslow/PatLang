#include <stdio.h>
#include <string.h>
#include "cli_common.h"

void print_usage(const char* progname) {
    printf("Usage:\n");
    printf("  %s <file>           # Interpret mode\n", progname);
    printf("  %s -c <file>        # Compile mode\n", progname);
}

int parse_cli_args(int argc, char** argv, cli_args_t* out_args) {
    if (argc == 2) {
        // Interpret mode: patlang myprog.pat
        const char* filename = argv[1];
        out_args->mode = CLI_MODE_INTERPRET;
        out_args->filename = filename;
        return 0;
    } else if (argc == 3 && strcmp(argv[1], "-c") == 0) {
        // Compile mode: patlang -c myprog.pat
        const char* filename = argv[2];
        out_args->mode = CLI_MODE_COMPILE;
        out_args->filename = filename;
        return 0;
    } else {
        fprintf(stderr, "Error: Invalid arguments.\n");
        return -1;
    }
}