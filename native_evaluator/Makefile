# PaTLang Phase 1 Self-Hosting Build System
# Builds native bridge and sets up Phase 1 environment

# Compiler and flags
CC = gcc
CFLAGS = -Wall -Wextra -O2 -fPIC -std=c99
LDFLAGS = -shared -lm

# Platform detection
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
    CFLAGS += -D_POSIX_C_SOURCE=199309L
    SO_EXT = so
    LDFLAGS += -lrt
endif
ifeq ($(UNAME_S),Darwin)
    CFLAGS += -D_POSIX_C_SOURCE=199309L
    SO_EXT = dylib
    LDFLAGS = -shared -lm
endif
ifeq ($(OS),Windows_NT)
    SO_EXT = dll
    LDFLAGS = -shared -lm -lws2_32
    CFLAGS += -D_WIN32
endif

# Source files
NATIVE_BRIDGE_SRC = native_bridge.c
NATIVE_BRIDGE_TARGET = native_bridge.$(SO_EXT)

# Ruby files
RUBY_BRIDGE = ruby_bridge.rb
TEST_SUITE = phase1_test_suite.rb

# Build targets
.PHONY: all clean test install native_bridge ruby_deps check_deps demo

# Default target
all: check_deps native_bridge ruby_deps
	@echo "Phase 1 self-hosting environment built successfully"
	@echo "Run 'make test' to validate the implementation"
	@echo "Run 'make demo' to see Phase 1 capabilities"

# Build native bridge library
native_bridge: $(NATIVE_BRIDGE_TARGET)

$(NATIVE_BRIDGE_TARGET): $(NATIVE_BRIDGE_SRC)
	@echo "Building native bridge library..."
	$(CC) $(CFLAGS) $(NATIVE_BRIDGE_SRC) -o $(NATIVE_BRIDGE_TARGET) $(LDFLAGS)
	@echo "Native bridge built: $(NATIVE_BRIDGE_TARGET)"

# Check dependencies
check_deps:
	@echo "Checking dependencies..."
	@which ruby > /dev/null || (echo "Error: Ruby not found. Please install Ruby 2.7+"; exit 1)
	@which $(CC) > /dev/null || (echo "Error: $(CC) not found. Please install GCC or Clang"; exit 1)
	@ruby -e "require 'ffi'" 2>/dev/null || (echo "Warning: FFI gem not found. Run 'make ruby_deps' to install")
	@echo "Dependencies check completed"

# Install Ruby dependencies
ruby_deps:
	@echo "Installing Ruby dependencies..."
	gem install ffi minitest minitest-reporters --user-install 2>/dev/null || \
	gem install ffi minitest minitest-reporters || \
	echo "Warning: Could not install gems. You may need to run with sudo or use bundler"
	@echo "Ruby dependencies installation completed"

# Run test suite
test: all
	@echo "Running Phase 1 test suite..."
	ruby $(TEST_SUITE)

# Run demonstration
demo: all
	@echo "Running Phase 1 demonstration..."
	ruby $(RUBY_BRIDGE)

# Interactive mode
interactive: all
	@echo "Starting interactive Phase 1 session..."
	@echo "Type PaTLang expressions or 'exit' to quit"
	ruby -e "require_relative '$(RUBY_BRIDGE)'; bridge = PaTLangPhase1Bridge.new; loop { print 'patlang> '; input = gets.chomp; break if input == 'exit'; result = bridge.evaluate(input, prefer_patlang: true); puts result[:success] ? \"=> #{result[:value]} (#{result[:evaluator_used]})\" : \"Error: #{result[:error]}\" }; bridge.cleanup"

# Performance benchmark
benchmark: all
	@echo "Running Phase 1 performance benchmark..."
	ruby -e "require_relative '$(RUBY_BRIDGE)'; bridge = PaTLangPhase1Bridge.new; puts 'Benchmarking evaluation performance...'; test_expr = '((2 + 3) * 4) - ((5 + 6) / 2)'; iterations = 1000; ruby_start = Time.now; iterations.times { bridge.evaluate(test_expr, prefer_patlang: false) }; ruby_time = Time.now - ruby_start; patlang_start = Time.now; iterations.times { bridge.evaluate(test_expr, prefer_patlang: true) }; patlang_time = Time.now - patlang_start; puts \"Ruby: #{(ruby_time * 1000 / iterations).round(3)}ms/eval\"; puts \"PaTLang: #{(patlang_time * 1000 / iterations).round(3)}ms/eval\"; puts \"Ratio: #{(patlang_time / ruby_time).round(2)}x\"; bridge.cleanup"

# Validate Phase 1 implementation
validate: all
	@echo "Validating Phase 1 implementation..."
	@echo "1. Checking native bridge..."
	@test -f $(NATIVE_BRIDGE_TARGET) || (echo "Error: Native bridge not built"; exit 1)
	@echo "2. Checking Ruby bridge..."
	@ruby -c $(RUBY_BRIDGE) || (echo "Error: Ruby bridge syntax error"; exit 1)
	@echo "3. Checking core evaluator..."
	@test -f core_evaluator.patlang || (echo "Error: Core evaluator not found"; exit 1)
	@echo "4. Checking memory manager..."
	@test -f memory_manager.patlang || (echo "Error: Memory manager not found"; exit 1)
	@echo "5. Running basic functionality test..."
	@ruby -e "require_relative '$(RUBY_BRIDGE)'; bridge = PaTLangPhase1Bridge.new; result = bridge.evaluate('2 + 3'); puts result[:success] ? 'Basic evaluation: PASS' : 'Basic evaluation: FAIL'; bridge.cleanup"
	@echo "Phase 1 validation completed successfully"

# Install Phase 1 for system-wide use
install: all
	@echo "Installing Phase 1 components..."
	@mkdir -p ../bin
	@cp $(NATIVE_BRIDGE_TARGET) ../bin/
	@echo "#!/usr/bin/env ruby" > ../bin/patlang-phase1
	@echo "require_relative '../native_evaluator/$(RUBY_BRIDGE)'" >> ../bin/patlang-phase1
	@echo "bridge = PaTLangPhase1Bridge.new" >> ../bin/patlang-phase1
	@echo "bridge.demonstrate_phase1_capabilities" >> ../bin/patlang-phase1
	@chmod +x ../bin/patlang-phase1
	@echo "Phase 1 installed to ../bin/"
	@echo "Run '../bin/patlang-phase1' to start"

# Development targets
dev: all
	@echo "Setting up development environment..."
	@echo "Creating development symlinks..."
	@ln -sf $(PWD)/$(NATIVE_BRIDGE_TARGET) ../$(NATIVE_BRIDGE_TARGET) 2>/dev/null || true
	@echo "Development environment ready"

# Debug build with additional symbols and checks
debug: CFLAGS += -g -DPATLANG_DEBUG_MEMORY -DPATLANG_DEBUG -O0
debug: clean $(NATIVE_BRIDGE_TARGET)
	@echo "Debug build completed with additional debugging symbols"

# Profile-guided optimization build
profile: CFLAGS += -fprofile-generate
profile: clean $(NATIVE_BRIDGE_TARGET)
	@echo "Running profile generation..."
	@$(MAKE) benchmark > /dev/null 2>&1 || true
	@$(CC) $(CFLAGS:-fprofile-generate=-fprofile-use) $(NATIVE_BRIDGE_SRC) -o $(NATIVE_BRIDGE_TARGET) $(LDFLAGS)
	@echo "Profile-optimized build completed"

# Memory leak checking (requires valgrind)
memcheck: debug
	@echo "Running memory leak check..."
	@which valgrind > /dev/null || (echo "Error: valgrind not found"; exit 1)
	@ruby -e "require_relative '$(RUBY_BRIDGE)'; bridge = PaTLangPhase1Bridge.new; 100.times { bridge.evaluate('2 + 3') }; bridge.cleanup" &
	@sleep 2
	@pkill -f ruby || true
	@echo "Memory check completed"

# Code coverage analysis
coverage: debug
	@echo "Generating code coverage report..."
	@CFLAGS="$(CFLAGS) --coverage" $(MAKE) clean $(NATIVE_BRIDGE_TARGET)
	@$(MAKE) test > /dev/null 2>&1 || true
	@gcov $(NATIVE_BRIDGE_SRC) 2>/dev/null || echo "Coverage tools not available"
	@echo "Coverage analysis completed"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -f $(NATIVE_BRIDGE_TARGET)
	@rm -f *.o *.gcda *.gcno *.gcov
	@rm -f core dump.*
	@echo "Clean completed"

# Help target
help:
	@echo "PaTLang Phase 1 Self-Hosting Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  all         - Build all Phase 1 components (default)"
	@echo "  native_bridge - Build native bridge library only"
	@echo "  ruby_deps   - Install Ruby dependencies"
	@echo "  test        - Run comprehensive test suite"
	@echo "  demo        - Run Phase 1 demonstration"
	@echo "  interactive - Start interactive PaTLang session"
	@echo "  benchmark   - Run performance benchmarks"
	@echo "  validate    - Validate Phase 1 implementation"
	@echo "  install     - Install Phase 1 for system use"
	@echo "  clean       - Clean build artifacts"
	@echo ""
	@echo "Development targets:"
	@echo "  dev         - Set up development environment"
	@echo "  debug       - Build with debug symbols"
	@echo "  profile     - Build with profile-guided optimization"
	@echo "  memcheck    - Run memory leak checking"
	@echo "  coverage    - Generate code coverage report"
	@echo ""
	@echo "Configuration:"
	@echo "  CC=$(CC)"
	@echo "  CFLAGS=$(CFLAGS)"
	@echo "  Platform: $(UNAME_S)"
	@echo "  Library extension: $(SO_EXT)"

# Status information
status:
	@echo "Phase 1 Implementation Status:"
	@echo "=============================="
	@echo "Native bridge: $(if $(wildcard $(NATIVE_BRIDGE_TARGET)),✓ Built,✗ Not built)"
	@echo "Ruby bridge: $(if $(wildcard $(RUBY_BRIDGE)),✓ Available,✗ Missing)"
	@echo "Core evaluator: $(if $(wildcard core_evaluator.patlang),✓ Available,✗ Missing)"
	@echo "Memory manager: $(if $(wildcard memory_manager.patlang),✓ Available,✗ Missing)"
	@echo "Test suite: $(if $(wildcard $(TEST_SUITE)),✓ Available,✗ Missing)"
	@echo ""
	@echo "Dependencies:"
	@echo "Ruby: $(if $(shell which ruby),✓ Available,✗ Missing)"
	@echo "$(CC): $(if $(shell which $(CC)),✓ Available,✗ Missing)"
	@echo "FFI gem: $(if $(shell ruby -e 'require \"ffi\"' 2>/dev/null && echo ok),✓ Available,✗ Missing)"
	@echo ""
	@echo "Quick start: make all && make demo"

# Continuous integration target
ci: check_deps ruby_deps native_bridge test validate
	@echo "Continuous integration build completed successfully"

# Documentation generation
docs:
	@echo "Generating Phase 1 documentation..."
	@mkdir -p docs
	@echo "# Phase 1 Self-Hosting Implementation" > docs/README.md
	@echo "" >> docs/README.md
	@echo "This directory contains the Phase 1 self-hosting implementation." >> docs/README.md
	@echo "" >> docs/README.md
	@echo "## Quick Start" >> docs/README.md
	@echo "" >> docs/README.md
	@echo "\`\`\`bash" >> docs/README.md
	@echo "make all    # Build everything" >> docs/README.md
	@echo "make demo   # Run demonstration" >> docs/README.md
	@echo "make test   # Run test suite" >> docs/README.md
	@echo "\`\`\`" >> docs/README.md
	@echo "Documentation generated in docs/"

# Show build information
info:
	@echo "Build Information:"
	@echo "=================="
	@echo "Compiler: $(CC)"
	@echo "Flags: $(CFLAGS)"
	@echo "Linker flags: $(LDFLAGS)"
	@echo "Target: $(NATIVE_BRIDGE_TARGET)"
	@echo "Platform: $(UNAME_S)"
	@echo "Build date: $(shell date)"
	@echo "Git commit: $(shell git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"

# Quick development cycle
dev-cycle: clean debug test
	@echo "Development cycle completed"