# PatLang Compiler Frontend - Main Entry Point
# Written in PatLang for self-hosting

import "token.pat"
import "lexer.pat"
import "ast.pat"
import "parser.pat"
import "evaluator.pat"

# Test the self-hosting compiler
make a function called compile_and_run {
    takes: source
    returns: {
        # Tokenize
        lexer is Lexer(source)
        tokens is lexer.tokenize()
        
        # Parse
        parser is Parser(tokens)
        ast is parser.parse()
        
        # Evaluate
        evaluator is Evaluator()
        evaluator.eval(ast)
    }
}

# Run a simple test
make a function called run_tests {
    takes:
    returns: {
        # Test 1: Simple variable assignment
        result1 is compile_and_run("
            x is 42
            y is x + 8
            y
        ")
        print("Test 1 (variable): " + result1.to_string())
        
        # Test 2: Function definition and call
        result2 is compile_and_run("
            make a function called add {
                takes: a, b
                returns: a + b
            }
            add(10, 20)
        ")
        print("Test 2 (function): " + result2.to_string())
        
        # Test 3: Lambda with map
        result3 is compile_and_run("
            double is {|x| x * 2}
            result is map([1, 2, 3], double)
            result
        ")
        print("Test 3 (map): " + result3.to_string())
        
        # Test 4: Goal activation
        result4 is compile_and_run("
            make a goal called hello {
                achieved when: true
                runs: { \"Hello, World!\" }
            }
            activate hello
        ")
        print("Test 4 (goal): " + result4.to_string())
        
        # Test 5: Logic programming
        result5 is compile_and_run("
            assert parent(\"john\", \"mary\")
            query test {
                parent(\"john\", \"mary\")
            }
            end
        ")
        print("Test 5 (logic): " + result5.to_string())
        
        "All tests completed"
    }
}

# Run tests if executed directly
run_tests()