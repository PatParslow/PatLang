#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "loader.h"
#include "parser.h"

int load_and_parse(const char* path) {
    FILE* file = fopen(path, "r");
    if (file) {
        printf("Loader: Successfully read file: %s\n", path);
        fseek(file, 0, SEEK_END);
        long len = ftell(file);
        fseek(file, 0, SEEK_SET);
        char* buffer = (char*)malloc(len + 1);
        if (buffer) {
            fread(buffer, 1, len, file);
            buffer[len] = '\0';
            int parse_result = parse_patlang(buffer); // Pass file content to parser
            free(buffer);
            fclose(file);
            return parse_result;
        } else {
            printf("Loader: Memory allocation failed for file buffer.\n");
            fclose(file);
            return 1;
        }
    } else {
        printf("Loader: Failed to open file: %s\n", path);
        return 1;
    }
}