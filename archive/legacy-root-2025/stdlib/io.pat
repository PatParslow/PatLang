# PatLang Standard Library - IO Module
# Input/output functions
# Implemented in PatLang with foreign primitives for system I/O

import "core.pat"

# STDOUT/STDIN (foreign)
make a function called io_print_raw {
  takes: val
}

make a function called io_println_raw {
  takes: val
}

make a function called print {
  takes: val
}

make a function called println {
  takes: val
}

# Print multiple values
make a function called print_all {
  takes: args
}

make a function called println_all {
  takes: args
}

# Format string (printf-style)
make a function called format {
  takes: fmt_str, args
}

make a function called sprintf {
  takes: fmt_str, args
}

# Read from stdin
make a function called read_line {
  takes:
}

make a function called read_all {
  takes:
}

# File operations
make a function called file_read {
  takes: path
}

make a function called file_write {
  takes: path, content
}

make a function called file_append {
  takes: path, content
}

make a function called file_exists {
  takes: path
}

make a function called file_delete {
  takes: path
}

make a function called file_read_lines {
  takes: path
}

make a function called file_write_lines {
  takes: path, lines
}

# Directory operations
make a function called dir_exists {
  takes: path
}

make a function called dir_create {
  takes: path
}

make a function called dir_list {
  takes: path
}

# JSON
make a function called json_parse {
  takes: json_str
}

make a function called json_stringify {
  takes: val
}

# YAML
make a function called yaml_parse {
  takes: yaml_str
}

make a function called yaml_stringify {
  takes: val
}

# Higher-level IO helpers
make a function called read_file_lines {
  takes: path
}

make a function called write_file_lines {
  takes: path, lines
}

make a function called read_file {
  takes: path
}

make a function called write_file {
  takes: path, content
}

make a function called append_file {
  takes: path, content
}

make a function called copy_file {
  takes: src, dst
}

make a function called is_file {
  takes: path
}

make a function called is_dir {
  takes: path
}

make a function called file_size {
  takes: path
}

make a function called file_modified {
  takes: path
}

make a function called temp_file {
  takes: prefix
}

make a function called temp_dir {
  takes: prefix
}

# Environment variables
make a function called env_get {
  takes: key
}

make a function called env_set {
  takes: key, val
}

make a function called env_has {
  takes: key
}

# Command execution
make a function called execute {
  takes: cmd
}

make a function called execute_with_args {
  takes: cmd, args
}

make a function called last_exit_code {
  takes:
}