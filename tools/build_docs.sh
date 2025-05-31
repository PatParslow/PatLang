#!/bin/bash

# Patlang Documentation Builder
# Generates HTML documentation from markdown files

echo "Building Patlang documentation..."

# Make sure we're in the project root
cd "$(dirname "$0")/.."

# Run the documentation generator
ruby tools/doc_generator.rb

echo "Documentation built successfully!"
echo "To view: open docs_html/index.html in your browser"

# Optional: Start a simple HTTP server for local viewing
if command -v python3 &> /dev/null; then
    echo ""
    echo "To serve locally, run:"
    echo "  cd docs_html && python3 -m http.server 8000"
    echo "  Then open: http://localhost:8000"
elif command -v ruby &> /dev/null; then
    echo ""
    echo "To serve locally, run:"
    echo "  cd docs_html && ruby -run -ehttpd . -p8000"
    echo "  Then open: http://localhost:8000"
fi
