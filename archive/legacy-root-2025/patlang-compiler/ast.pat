# PatLang Compiler Frontend - AST Nodes
# Written in PatLang for self-hosting

import "token.pat"

# Base node class
make a class called Node {
    takes: line, column
    returns: {
        line is line
        column is column
    }
}

# Program - root node
make a class called ProgramNode {
    inherits Node
    takes: statements
    returns: {
        statements is statements
    }
}

# Literal nodes
make a class called IntegerLiteralNode {
    inherits Node
    takes: value
    returns: {
        value is value
    }
}

make a class called FloatLiteralNode {
    inherits Node
    takes: value
    returns: {
        value is value
    }
}

make a class called StringLiteralNode {
    inherits Node
    takes: value
    returns: {
        value is value
    }
}

make a class called BooleanLiteralNode {
    inherits Node
    takes: value
    returns: {
        value is value
    }
}

make a class called NilLiteralNode {
    inherits Node
    returns: {}
}

# Identifier
make a class called IdentifierNode {
    inherits Node
    takes: name
    returns: {
        name is name
    }
}

# Binary operations
make a class called BinaryOpNode {
    inherits Node
    takes: left, operator, right
    returns: {
        left is left
        operator is operator
        right is right
    }
}

# Unary operations
make a class called UnaryOpNode {
    inherits Node
    takes: operator, operand
    returns: {
        operator is operator
        operand is operand
    }
}

# Parenthesized expression
make a class called ParenExpressionNode {
    inherits Node
    takes: expression
    returns: {
        expression is expression
    }
}

# Function call
make a class called CallNode {
    inherits Node
    takes: callee, arguments
    returns: {
        callee is callee
        arguments is arguments
    }
}

# Lambda expression
make a class called LambdaNode {
    inherits Node
    takes: parameters, body
    returns: {
        parameters is parameters
        body is body
        captured_env is nil
    }
}

# Parameter
make a class called ParameterNode {
    inherits Node
    takes: name, type
    type is nil
    returns: {
        name is name
        type is type
    }
}

# List literal
make a class called ListLiteralNode {
    inherits Node
    takes: elements
    returns: {
        elements is elements
    }
}

# Object literal (key-value pairs)
make a class called ObjectLiteralNode {
    inherits Node
    takes: pairs
    returns: {
        pairs is pairs
    }
}

make a class called KeyValuePairNode {
    inherits Node
    takes: key, value
    returns: {
        key is key
        value is value
    }
}

# Block
make a class called BlockNode {
    inherits Node
    takes: statements
    returns: {
        statements is statements
    }
}

# Statements
make a class called ExpressionStatementNode {
    inherits Node
    takes: expression
    returns: {
        expression is expression
    }
}

# Assignment (IS)
make a class called AssignmentNode {
    inherits Node
    takes: name, value
    returns: {
        name is name
        value is value
    }
}

# Mutation (BECOMES)
make a class called MutationNode {
    inherits Node
    takes: name, value
    returns: {
        name is name
        value is value
    }
}

# If statement
make a class called IfStatementNode {
    inherits Node
    takes: condition, then_branch, elsif_branches, else_branch
    elsif_branches is []
    else_branch is nil
    returns: {
        condition is condition
        then_branch is then_branch
        elsif_branches is elsif_branches
        else_branch is else_branch
    }
}

# While statement
make a class called WhileStatementNode {
    inherits Node
    takes: condition, body
    returns: {
        condition is condition
        body is body
    }
}

# For statement
make a class called ForStatementNode {
    inherits Node
    takes: variable, iterable, body, is_range, range_start, range_end
    is_range is false
    range_start is nil
    range_end is nil
    returns: {
        variable is variable
        iterable is iterable
        body is body
        is_range is is_range
        range_start is range_start
        range_end is range_end
    }
}

# Return statement
make a class called ReturnStatementNode {
    inherits Node
    takes: value
    value is nil
    returns: {
        value is value
    }
}

# Function declaration
make a class called FunctionDeclarationNode {
    inherits Node
    takes: name, parameters, return_type, preconditions, postconditions, body
    returns: {
        name is name
        parameters is parameters
        return_type is return_type
        preconditions is preconditions
        postconditions is postconditions
        body is body
    }
}

# Event handler
make a class called EventHandlerNode {
    inherits Node
    takes: event_name, event_action, body
    event_action is nil
    returns: {
        event_name is event_name
        event_action is event_action
        body is body
    }
}

# Goal declaration
make a class called GoalDeclarationNode {
    inherits Node
    takes: name, requirements, achievement_conditions, body
    returns: {
        name is name
        requirements is requirements
        achievement_conditions is achievement_conditions
        body is body
    }
}

make a class called RequirementNode {
    inherits Node
    takes: name
    returns: {
        name is name
    }
}

# Activate statement
make a class called ActivateStatementNode {
    inherits Node
    takes: goal_name, arguments
    arguments is nil
    returns: {
        goal_name is goal_name
        arguments is arguments
    }
}

# Query statement
make a class called QueryStatementNode {
    inherits Node
    takes: name, body
    returns: {
        name is name
        body is body
    }
}

# Assert statement
make a class called AssertStatementNode {
    inherits Node
    takes: predicate, arguments
    returns: {
        predicate is predicate
        arguments is arguments
    }
}

# Type annotation
make a class called TypeAnnotationNode {
    inherits Node
    takes: type_name
    returns: {
        type_name is type_name
    }
}

# Template/Class declaration
make a class called TemplateDeclarationNode {
    inherits Node
    takes: name, parent, fields, invariants, methods
    parent is nil
    returns: {
        name is name
        parent is parent
        fields is fields
        invariants is invariants
        methods is methods
    }
}

make a class called FieldNode {
    inherits Node
    takes: name
    returns: {
        name is name
    }
}