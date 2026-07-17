# PatLang Compiler Frontend - Evaluator
# Written in PatLang for self-hosting
# Interpreter with environment-based evaluation, closures, and logic programming

import "ast.pat"

# Exception for early returns
make a class called ReturnException {
    takes: value
    returns: {
        value is value
    }
}

make a class called EvaluatorError {
    takes: message
    returns: {
        message is message
    }
}

# Environment for variable storage
make a class called Environment {
    takes: parent
    parent is nil
    returns: {
        store is {}
        parent is parent
    }
    
    make a function called define {
        takes: name, value
        store[name] is value
    }
    
    make a function called assign {
        takes: name, value
        if store.has_key?(name) {
            store[name] is value
        } else if parent != nil {
            parent.assign(name, value)
        } else {
            raise(EvaluatorError("Variable '" + name + "' is not bound"))
        }
    }
    
    make a function called lookup {
        takes: name
        if store.has_key?(name) {
            store[name]
        } else if parent != nil {
            parent.lookup(name)
        } else {
            raise(EvaluatorError("Variable '" + name + "' is not bound"))
        }
    }
    
    make a function called bound? {
        takes: name
        store.has_key?(name) or (parent != nil and parent.bound?(name))
    }
}

# Main evaluator
make a class called Evaluator {
    takes: stdlib_modules
    stdlib_modules is ["core", "collections"]
    returns: {
        env is Environment()
        # Standard library will be loaded when needed
        stdlib is nil
        
        # Define built-ins
        env.define("true", true)
        env.define("false", false)
        env.define("nil", nil)
    }
    
    make a function called eval {
        takes: node
        returns: {
            case = node.class
            
            if case == ProgramNode {
                eval_program(node)
            }
            else if case == ExpressionStatementNode {
                eval(node.expression)
            }
            else if case == BlockNode {
                eval_block(node)
            }
            else if case == IntegerLiteralNode {
                node.value
            }
            else if case == FloatLiteralNode {
                node.value
            }
            else if case == StringLiteralNode {
                node.value
            }
            else if case == BooleanLiteralNode {
                node.value
            }
            else if case == NilLiteralNode {
                nil
            }
            else if case == IdentifierNode {
                env.lookup(node.name)
            }
            else if case == AssignmentNode {
                value is eval(node.value)
                env.define(node.name, value)
                value
            }
            else if case == MutationNode {
                value is eval(node.value)
                env.assign(node.name, value)
                value
            }
            else if case == BinaryOpNode {
                eval_binary_op(node)
            }
            else if case == UnaryOpNode {
                eval_unary_op(node)
            }
            else if case == ParenExpressionNode {
                eval(node.expression)
            }
            else if case == CallNode {
                eval_call(node)
            }
            else if case == LambdaNode {
                # Capture current environment for closure
                node.captured_env is env
                node
            }
            else if case == ListLiteralNode {
                elements is []
                for e in node.elements {
                    elements.append(eval(e))
                }
                elements
            }
            else if case == ObjectLiteralNode {
                result is {}
                for pair in node.pairs {
                    result[pair.key] is eval(pair.value)
                }
                result
            }
            else if case == IfStatementNode {
                eval_if(node)
            }
            else if case == WhileStatementNode {
                eval_while(node)
            }
            else if case == ForStatementNode {
                eval_for(node)
            }
            else if case == ReturnStatementNode {
                value is nil
                if node.value != nil {
                    value is eval(node.value)
                }
                raise(ReturnException(value))
            }
            else if case == FunctionDeclarationNode {
                env.define(node.name, node)
                nil
            }
            else if case == GoalDeclarationNode {
                env.define(node.name, node)
                nil
            }
            else if case == ActivateStatementNode {
                goal_name is node.goal_name
                unless env.bound?(goal_name) {
                    raise(EvaluatorError("Goal '" + goal_name + "' not found"))
                }
                goal is env.lookup(goal_name)
                unless goal.class == GoalDeclarationNode {
                    raise(EvaluatorError("Goal '" + goal_name + "' not found or not a goal"))
                }
                context is {}
                if node.arguments != nil {
                    context is eval(node.arguments)
                }
                execute_goal(goal, context)
            }
            else if case == AssertStatementNode {
                predicate is node.predicate
                arguments is []
                for arg in node.arguments {
                    arguments.append(eval(arg))
                }
                fact_string is build_fact_string(predicate, arguments)
                # This would use a facts database
                fact_string  # For now just return the fact string
            }
            else if case == QueryStatementNode {
                execute_query(node)
            }
            else if case == EventHandlerNode {
                # Event handlers are registered, not evaluated directly
                node
            }
            else {
                raise(EvaluatorError("Unknown node type: " + node.class))
            }
        }
    }
    
    make a function called eval_program {
        takes: node
        result is nil
        for stmt in node.statements {
            result is eval(stmt)
        }
        result
    }
    
    make a function called eval_block {
        takes: node
        old_env is env
        env is Environment(env)
        result is nil
        for stmt in node.statements {
            result is eval(stmt)
        }
        env is old_env
        result
    }
    
    make a function called eval_binary_op {
        takes: node
        left is eval(node.left)
        right is eval(node.right)
        
        case = node.operator
        
        if case == "+" { left + right }
        else if case == "-" { left - right }
        else if case == "*" { left * right }
        else if case == "/" { left / right }
        else if case == "%" { left % right }
        else if case == "=" { left == right }
        else if case == "!=" { left != right }
        else if case == "<" { left < right }
        else if case == ">" { left > right }
        else if case == "<=" { left <= right }
        else if case == ">=" { left >= right }
        else if case == "and" { left and right }
        else if case == "or" { left or right }
        else if case == "is" { left == right }
        else if case == "is not" { left != right }
        else {
            raise(EvaluatorError("Unknown binary operator: " + case))
        }
    }
    
    make a function called eval_unary_op {
        takes: node
        operand is eval(node.operand)
        
        if node.operator == "-" {
            -operand
        } else if node.operator == "not" {
            not operand
        } else {
            raise(EvaluatorError("Unknown unary operator: " + node.operator))
        }
    }
    
    make a function called eval_call {
        takes: node
        callee is eval(node.callee)
        args is []
        for arg in node.arguments {
            args.append(eval(arg))
        }
        
        if callee.class == FunctionDeclarationNode {
            eval_function_call(callee, args)
        } else if callee.class == LambdaNode {
            eval_lambda_call(callee, args)
        } else if callable?(callee) {
            callee(*args)
        } else {
            raise(EvaluatorError("Not callable: " + callee.class))
        }
    }
    
    make a function called eval_function_call {
        takes: func_node, args
        if func_node.parameters.length != args.length {
            raise(EvaluatorError("Function " + func_node.name + " expects " + func_node.parameters.length + " args, got " + args.length))
        }
        
        outer_env is env
        env is Environment(env)
        for i in 0..func_node.parameters.length - 1 {
            param is func_node.parameters[i]
            env.define(param.name, args[i + 1])
        }
        
        result is nil
        try {
            result is eval(func_node.body)
        } catch ReturnException e {
            result is e.value
        } finally {
            env is outer_env
        }
        result
    }
    
    make a function called eval_lambda_call {
        takes: lambda_node, args
        if lambda_node.parameters.length != args.length {
            raise(EvaluatorError("Lambda expects " + lambda_node.parameters.length + " args, got " + args.length))
        }
        
        outer_env is env
        env is Environment(lambda_node.captured_env or env)
        for i in 0..lambda_node.parameters.length - 1 {
            param is lambda_node.parameters[i]
            env.define(param.name, args[i + 1])
        }
        
        result is nil
        try {
            result is eval(lambda_node.body)
        } catch ReturnException e {
            result is e.value
        } finally {
            env is outer_env
        }
        result
    }
    
    make a function called eval_if {
        takes: node
        if truthy?(eval(node.condition)) {
            eval(node.then_branch)
        } else if node.elsif_branches.length > 0 {
            for cond, branch in node.elsif_branches {
                if truthy?(eval(cond)) {
                    return eval(branch)
                }
            }
            if node.else_branch != nil {
                eval(node.else_branch)
            } else {
                nil
            }
        } else {
            if node.else_branch != nil {
                eval(node.else_branch)
            } else {
                nil
            }
        }
    }
    
    make a function called eval_while {
        takes: node
        result is nil
        while truthy?(eval(node.condition)) {
            result is eval(node.body)
        }
        result
    }
    
    make a function called eval_for {
        takes: node
        result is nil
        iter is nil
        if node.is_range {
            iter is (eval(node.range_start)..eval(node.range_end)).to_a()
        } else {
            iter is eval(node.iterable)
        }
        
        for item in iter {
            outer_env is env
            env is Environment(env)
            env.define(node.variable, item)
            result is eval(node.body)
            env is outer_env
        }
        result
    }
    
    make a function called truthy? {
        takes: value
        value != nil and value != false
    }
    
    make a function called execute_goal {
        takes: goal, context
        # Check requirements
        if goal.requirements.length > 0 {
            for req in goal.requirements {
                req_name is req.name
                req_value is context[req_name] or (env.bound?(req_name) ? env.lookup(req_name) : nil)
                unless truthy?(req_value) {
                    raise(EvaluatorError("Goal '" + goal.name + "' requirement '" + req_name + "' not satisfied"))
                }
            }
        }
        
        # Evaluate achievement conditions
        if goal.achievement_conditions.length > 0 {
            all_met = true
            for cond in goal.achievement_conditions {
                val is eval(cond)
                unless truthy?(val) {
                    all_met = false
                    break
                }
            }
            unless all_met {
                raise(EvaluatorError("Goal '" + goal.name + "' achievement conditions not met"))
            }
        }
        
        # Execute goal body
        if goal.body != nil {
            outer_env is env
            env is Environment(env)
            
            for key, value in context {
                env.define(key, value)
            }
            
            try {
                result is eval(goal.body)
            } finally {
                env is outer_env
            }
            result
        } else {
            nil
        }
    }
    
    make a function called build_fact_string {
        takes: predicate, arguments
        if arguments.length == 0 {
            predicate
        } else {
            args_str is ""
            for i in 0..arguments.length - 1 {
                arg is arguments[i + 1]
                if i > 0 {
                    args_str is args_str + ", "
                }
                args_str is args_str + format_fact_arg(arg)
            }
            predicate + "(" + args_str + ")"
        }
    }
    
    make a function called format_fact_arg {
        takes: arg
        if arg.class == String {
            '"' + arg + '"'
        } else {
            arg.to_string()
        }
    }
    
    make a function called extract_query_string {
        takes: body
        if body != nil and body.statements.length > 0 {
            stmt is body.statements[0]
            if stmt.class == ExpressionStatementNode and stmt.expression.class == CallNode {
                call is stmt.expression
                predicate is call.callee.name if call.callee.class == IdentifierNode else nil
                if predicate != nil {
                    args is []
                    for arg in call.arguments {
                        if arg.class == IdentifierNode and arg.name.starts_with?("?") {
                            args.append(arg.name)
                        } else {
                            args.append(eval(arg))
                        }
                    }
                    build_fact_string(predicate, args)
                }
            }
        }
    }
    
    make a function called execute_query {
        takes: node
        query_string is extract_query_string(node.body)
        if query_string == nil or query_string.strip() == "" {
            []
        } else {
            # Query would use facts database
            # For now return the query string as list
            [query_string]
        }
    }
    
    make a function called callable? {
        takes: obj
        obj.respond_to?(:call) or obj.class == Proc
    }
}