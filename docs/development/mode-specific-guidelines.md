# Mode-Specific Development Guidelines

## Overview

This document provides development guidelines specific to different modes and tools used in the Patlang project. It focuses on avoiding common anti-patterns and ensuring consistent practices across different development environments and approaches.

## Table of Contents

1. [Code Mode Guidelines](#code-mode-guidelines)
2. [Tool Usage Best Practices](#tool-usage-best-practices)
3. [Common Anti-Patterns to Avoid](#common-anti-patterns-to-avoid)
4. [Testing and Verification Patterns](#testing-and-verification-patterns)
5. [Cross-Platform Development](#cross-platform-development)
6. [Performance Considerations](#performance-considerations)
7. [Integration and Deployment](#integration-and-deployment)

---

## Code Mode Guidelines

### File Operations vs Shell Commands

**Always Prefer Ruby File Operations:**
```ruby
# ❌ BAD: Using shell commands in Code mode
system("echo 'content' > output.txt")
`cat input.txt | grep pattern`
system("mkdir -p src/new_module")

# ✅ GOOD: Ruby file operations
File.write("output.txt", "content")
File.read("input.txt").lines.grep(/pattern/)
FileUtils.mkdir_p("src/new_module")
```

### Write File Tool Usage

**Prefer [`write_file`](../../tools/file-operations.md) over Shell Redirection:**
```ruby
# ❌ BAD: Shell redirection (platform-dependent)
system("ruby script.rb > output.log 2>&1")
`echo "#{data}" >> data.txt`

# ✅ GOOD: Use write_file tool or Ruby methods
# Via tool:
# <write_to_file>
# <path>output.log</path>
# <content>#{script_output}
return input if input.is_a?(String)
    raise ArgumentError, "Unsupported input type"
  end
end

# Step 3: Extend functionality
class NewFeature
  def process(input)
    case input
    when String then process_string(input)
    when Array then process_array(input)
    when Hash then process_hash(input)
    else raise ArgumentError, "Unsupported input type: #{input.class}"
    end
  end
  
  private
  
  def process_string(str)
    # String processing logic
  end
  
  def process_array(arr)
    # Array processing logic
  end
  
  def process_hash(hash)
    # Hash processing logic
  end
end
```

### Git Commit Practices

**Make Incremental Commits:**
```bash
# ✅ GOOD: Small, focused commits
git add test/test_new_feature.rb
git commit -m "test: add basic tests for new feature"

git add src/new_feature.rb
git commit -m "feat: implement basic new feature structure"

git add src/new_feature.rb
git commit -m "feat: add string processing to new feature"

# ❌ BAD: Large, unfocused commits
git add .
git commit -m "fix stuff and add features"
```

### Error Handling in Development

**Fail Fast with Clear Messages:**
```ruby
# ✅ GOOD: Clear error handling
def parse_expression(tokens)
  return nil if tokens.empty?
  
  begin
    parse_primary_expression(tokens)
  rescue ParseError => e
    puts "Parse error at line #{e.line}: #{e.message}"
    puts "Tokens remaining: #{tokens.map(&:type).join(', ')}"
    raise e
  end
end

# ❌ BAD: Silent failures or unclear errors
def parse_expression(tokens)
  return nil if tokens.empty?
  
  begin
    parse_primary_expression(tokens)
  rescue
    nil  # Silent failure - debugging nightmare
  end
end
```

---

## Tool Usage Best Practices

### Prefer Native File Operations

**Tool Selection Priority:**
1. **Ruby File Operations** - First choice for file manipulation
2. **File Tools** ([`write_file`](../../tools/file-operations.md), [`read_file`](../../tools/file-operations.md)) - For tool-based development
3. **Shell Commands** - Only when Ruby alternatives don't exist

```ruby
# ✅ GOOD: Priority order examples

# 1. Ruby operations (preferred)
content = File.read("input.txt")
File.write("output.txt", processed_content)

# 2. File tools (when in tool-based mode)
# <read_file><path>input.txt</path></read_file>
# <write_to_file><path>output.txt</path><content>processed