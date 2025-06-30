#ifndef LOADER_H
#define LOADER_H

#ifdef __cplusplus
extern "C" {
#endif

// Loads and parses a .pat file at the given path.
// For now, only prints a confirmation message.
int load_and_parse(const char* path);

#ifdef __cplusplus
}
#endif

#endif // LOADER_H