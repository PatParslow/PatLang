#!/bin/bash

echo "🚀 Starting Patlang Codebase Migration"
echo "=================================="

# Phase 1: Move Core Language Files
echo "📁 Phase 1: Moving Core Language Files..."

# Lexer files
echo "  Moving lexer files..."
cp src/lexer.rb patlang-core/lexer/
cp src/token.rb patlang-core/lexer/
cp src/ambiguous_token.rb patlang-core/lexer/

# Parser files
echo "  Moving parser files..."
cp src/parser.rb patlang-core/parser/
cp -r src/parser/* patlang-core/parser/

# AST files
echo "  Moving AST files..."
cp src/ast_nodes.rb patlang-core/ast/
cp -r src/ast/* patlang-core/ast/

# Evaluator files
echo "  Moving evaluator files..."
cp src/evaluator.rb patlang-core/evaluator/
cp -r src/evaluator/* patlang-core/evaluator/

# Reasoning files  
echo "  Moving reasoning files..."
cp -r src/reasoning/* patlang-core/reasoning/

# Object model files
echo "  Moving object model files..."
cp -r src/object_model/* patlang-core/object_model/

# Core exceptions
echo "  Moving core exception handling..."
cp src/exceptions.rb patlang-core/

echo "✅ Phase 1 Complete: Core language files moved"

# Phase 2: Move Ruby Host Files
echo "📁 Phase 2: Moving Ruby Host Files..."

# Bootstrap files
echo "  Moving bootstrap files..."
cp src/patlang.rb ruby-host/bootstrap/
cp src/hash_extensions.rb ruby-host/bootstrap/
cp src/emergency_timeout.rb ruby-host/bootstrap/

# Move old evaluator as part of runtime
echo "  Moving runtime files..."
cp src/evaluator_old.rb ruby-host/runtime/

echo "✅ Phase 2 Complete: Ruby host files moved"

# Phase 3: Move Development Tools
echo "📁 Phase 3: Moving Development Tools..."

# Move tools directory contents
echo "  Moving tools..."
if [ -d "tools" ]; then
    cp -r tools/* dev-tools/build/
fi

# Move coverage and testing scripts
echo "  Moving coverage tools..."
find test -name "*coverage*" -type f | head -10 | while read file; do
    cp "$file" dev-tools/coverage/
done

find test -name "*test_runner*" -type f | head -5 | while read file; do
    cp "$file" dev-tools/testing/
done

echo "✅ Phase 3 Complete: Development tools moved"

# Phase 4: Archive Management
echo "📁 Phase 4: Managing Archive..."

# Move src/archive to root level
if [ -d "src/archive" ]; then
    echo "  Moving src/archive to root level..."
    cp -r src/archive/* archive/
fi

echo "✅ Phase 4 Complete: Archive organized"

# Phase 5: Test Structure Update
echo "📁 Phase 5: Updating Test Structure..."

# Create new test structure
mkdir -p tests/patlang-core/lexer
mkdir -p tests/patlang-core/parser  
mkdir -p tests/patlang-core/evaluator
mkdir -p tests/patlang-core/reasoning
mkdir -p tests/patlang-core/integration
mkdir -p tests/ruby-host/bootstrap
mkdir -p tests/ruby-host/runtime
mkdir -p tests/cross-platform/language_spec

echo "  New test directories created"
echo "✅ Phase 5 Complete: Test structure prepared"

echo ""
echo "🎉 Migration Complete!"
echo "=================================="
echo "Summary:"
echo "- ✅ Core language files moved to patlang-core/"
echo "- ✅ Ruby host files moved to ruby-host/"  
echo "- ✅ Development tools moved to dev-tools/"
echo "- ✅ Archive organized"
echo "- ✅ New test structure created"
echo ""
echo "Next steps:"
echo "1. Update require paths in moved files"
echo "2. Migrate tests to new structure" 
echo "3. Update documentation and build scripts"
echo "4. Verify all tests still pass"