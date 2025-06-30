#ifndef CLI_COMMON_H
#define CLI_COMMON_H

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    CLI_MODE_NONE = 0,
    CLI_MODE_INTERPRET,
    CLI_MODE_COMPILE
} cli_mode_t;

typedef struct {
    cli_mode_t mode;
    const char* filename;
} cli_args_t;

void print_usage(const char* progname);
int parse_cli_args(int argc, char** argv, cli_args_t* out_args);

#ifdef __cplusplus
}
#endif

#endif // CLI_COMMON_H