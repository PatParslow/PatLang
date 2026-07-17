# PatLang Standard Library - Main Entry Point
# Loads all standard library modules

import "core.pat"
import "collections.pat"
import "logic.pat"
import "goals.pat"
import "io.pat"
import "html_gui.pat"

# Re-export everything (PatLang imports are transitive)
# This file serves as the single import for "standard library"