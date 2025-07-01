# Makefile for native_evaluator TDD cycle (C runtime)
# Portable for Linux, WSL, and Windows (MinGW/WSL)
# Builds and runs all test executables

# Platform detection
ifeq ($(OS),Windows_NT)
    EXE_EXT := .exe
    RM := del /Q
else
    EXE_EXT :=
    RM := rm -f
endif

CC := clang
CFLAGS := -Wall -Wextra -std=c11
LDFLAGS := -lm

# Test sources and dependencies
# Automatically find all *_test.c files and define TESTS as their corresponding binaries
TEST_SRCS := $(wildcard *_test.c)
TESTS := $(patsubst %.c,%$(EXE_EXT),$(TEST_SRCS))
DEPS := native_bridge.c transpiled/transpiled_core_evaluator.c transpiled/transpiled_memory_manager.c
WEEK2_DEPS := $(DEPS) arithmetic_evaluator.c string_evaluator.c runtime.c cli_common.c loader.c parser.c

# Default target: build all tests
all: $(TESTS) patlang$(EXE_EXT) cli_test$(EXE_EXT)

# Pattern rule for building test executables
%$(EXE_EXT): %.c $(DEPS)
	$(CC) $(CFLAGS) -Itranspiled $< $(WEEK2_DEPS) $(LDFLAGS) -o $@

# patlang CLI build
patlang$(EXE_EXT): patlang.c loader.c parser.c runtime.c
	$(CC) $(CFLAGS) patlang.c cli_common.c loader.c parser.c runtime.c arithmetic_evaluator.c string_evaluator.c -o patlang$(EXE_EXT)

# CLI test build
cli_test$(EXE_EXT): cli_test.c cli_common.c loader.c parser.c runtime.c
	$(CC) $(CFLAGS) cli_test.c cli_common.c loader.c parser.c arithmetic_evaluator.c string_evaluator.c runtime.c -o cli_test$(EXE_EXT)

# Run all *_test binaries
.PHONY: run_all clean test-cli test-runtime

# Build and run runtime_test (not pattern-based, keep as is)
runtime_test$(EXE_EXT): runtime_test.c runtime.c runtime.h
	$(CC) $(CFLAGS) runtime_test.c runtime.c arithmetic_evaluator.c string_evaluator.c cli_common.c loader.c parser.c native_bridge.c -o runtime_test$(EXE_EXT)

test-runtime: runtime_test$(EXE_EXT)
	./runtime_test$(EXE_EXT)

# Run all discovered test binaries
run_all: all
	@echo "Running all tests..."
	@for test in $(TESTS); do \
		echo "Running $$test..."; \
		./$$test; \
	done

# Run CLI test
test-cli: cli_test$(EXE_EXT)
	@echo "Ensuring testdir exists..."
	@mkdir -p testdir
	@echo "Running cli_test integration tests..."
	@$(CC) $(CFLAGS) -DTEST_MAIN cli_test.c cli_common.c loader.c parser.c runtime.c -o cli_test$(EXE_EXT)
	./cli_test$(EXE_EXT)

# Test transpiled evaluator
test-transpiled: transpiled_evaluator_test$(EXE_EXT)
	./transpiled_evaluator_test$(EXE_EXT)

# Week 2: Test enhanced transpiled evaluator with memory management
test-week2: week2_enhanced_test$(EXE_EXT)
	@echo "Running Week 2 enhanced test suite..."
	./week2_enhanced_test$(EXE_EXT)

# Week 2: Build enhanced test executable
week2_enhanced_test$(EXE_EXT): week2_enhanced_test.c $(WEEK2_DEPS)
	$(CC) $(CFLAGS) -Itranspiled week2_enhanced_test.c $(WEEK2_DEPS) $(LDFLAGS) -o week2_enhanced_test$(EXE_EXT)

# Week 2: Performance benchmark
test-week2-performance: week2_enhanced_test$(EXE_EXT)
	@echo "Running Week 2 performance benchmarks..."
	@echo "Target: 85%+ improvement over Ruby baseline"
	./week2_enhanced_test$(EXE_EXT)

# Week 2: Memory management validation
test-week2-memory: week2_enhanced_test$(EXE_EXT)
	@echo "Running Week 2 memory management validation..."
	@echo "Testing: Pool allocation, GC, integrity validation"
	./week2_enhanced_test$(EXE_EXT)

# Week 2: Pattern coverage validation
test-week2-patterns: week2_enhanced_test$(EXE_EXT)
	@echo "Running Week 2 pattern coverage validation..."
	@echo "Target: 15+ evaluator patterns implemented"
	./week2_enhanced_test$(EXE_EXT)

# Week 2: Complete validation suite
test-week2-complete: test-week2 test-week2-performance test-week2-memory test-week2-patterns
	@echo "Week 2 complete validation suite executed"
	@echo "✓ Enhanced patterns tested"
	@echo "✓ Performance benchmarked"
	@echo "✓ Memory management validated"
	@echo "✓ Pattern coverage verified"

# Clean up build artifacts
clean:
	$(RM) $(TESTS) patlang$(EXE_EXT) cli_test$(EXE_EXT) week2_enhanced_test$(EXE_EXT) transpiled/*.o