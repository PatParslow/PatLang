# PatLang Compiler Frontend - Parser
# Written in PatLang for self-hosting
# Recursive descent parser with expectation-driven token resolution

import "token.pat"
import "ast.pat"

make a class called ParseError {
    takes: message, token, expected
    returns: {
        message is message
        token is token
        expected is expected
    }
}

make a class called Parser {
    takes: tokens
    returns: {
        tokens is tokens
        current is 0
    }
    
    make a function called parse {
        statements is []
        until at_end() or current_token().type == TokenType::EOF {
            stmt is statement()
            if stmt != nil {
                statements.append(stmt)
            }
        }
        ProgramNode(statements)
    }
    
    # Token accessors
    make a function called current_token {
        tokens[current] or TokenType::EOF
    }
    
    make a function called peek_token {
        takes: offset
        offset is 1
        tokens[current + offset] or TokenType::EOF
    }
    
    make a function called advance {
        if not at_end() {
            current is current + 1
        }
        previous_token()
    }
    
    make a function called previous_token {
        tokens[current - 1]
    }
    
    make a function called at_end {
        current >= tokens.length or current_token().type == TokenType::EOF
    }
    
    make a function called check {
        takes: type
        current_token().type == type
    }
    
    make a function called match {
        takes: types
        for type in types {
            if check(type) {
                advance()
                return true
            }
        }
        false
    }
    
    make a function called consume {
        takes: type, message
        message is "Expected " + type
        if check(type) {
            advance()
        } else {
            raise(ParseError(message + ", got " + current_token().type, current_token(), [type]))
        }
    }
    
    make a function called consume_expecting {
        takes: types
        for type in types {
            if check(type) {
                return advance()
            }
        }
        raise(ParseError("Expected one of " + types.to_string() + ", got " + current_token().type, current_token(), types))
    }
    
    # Statement parsing
    make a function called statement {
        if match([TokenType::NEWLINE]) {
            return nil
        }
        
        case = current_token().type
        
        if case == TokenType::MAKE_KEYWORD {
            make_declaration()
        }
        else if case == TokenType::WHEN_KEYWORD {
            event_handler()
        }
        else if case == TokenType::IF_KW {
            if_statement()
        }
        else if case == TokenType::WHILE_KEYWORD {
            while_statement()
        }
        else if case == TokenType::FOR_KEYWORD {
            for_statement()
        }
        else if case == TokenType::ACTIVATE_KEYWORD {
            activate_statement()
        }
        else if case == TokenType::QUERY_KEYWORD {
            query_statement()
        }
        else if case == TokenType::ASSERT_KEYWORD {
            assert_statement()
        }
        else if case == TokenType::RETURN_KEYWORD {
            return_statement()
        }
        else if case == TokenType::IDENTIFIER {
            next_t is peek_token().type
            if next_t == TokenType::IS_KEYWORD or next_t == TokenType::BECOMES_KEYWORD {
                assignment_or_mutation()
            } else {
                expression_statement()
            }
        }
        else {
            expression_statement()
        }
    }
    
    # Declaration parsing
    make a function called make_declaration {
        start_token is consume(TokenType::MAKE_KEYWORD)
        consume_expecting([TokenType::ARTICLE])
        decl_type is consume_expecting([TokenType::FUNCTION_KW, TokenType::CLASS_KW, TokenType::TEMPLATE_KW, TokenType::GOAL_KW, TokenType::LIST_KW, TokenType::TYPE_KW, TokenType::DECL_TYPE])
        consume(TokenType::CALLED)
        name_token is consume(TokenType::IDENTIFIER)
        name is name_token.value
        
        if decl_type.value == "function" {
            parse_function_declaration(name, start_token)
        }
        else if decl_type.value == "class" or decl_type.value == "template" {
            body is block()
            parse_template(name, body, start_token, decl_type.value == "class")
        }
        else if decl_type.value == "goal" {
            parse_goal(name, start_token)
        }
        else if decl_type.value == "list" {
            body is block()
            initialize_list(name, body, start_token)
        }
        else if decl_type.value == "number" or decl_type.value == "text" or decl_type.value == "boolean" {
            body is block()
            initialize_typed_var(name, decl_type.value, body, start_token)
        }
        else {
            raise(ParseError("Unknown declaration type: " + decl_type.value))
        }
    }
    
    make a function called parse_function_declaration {
        takes: name, start_token
        params is []
        return_type is nil
        preconditions is []
        postconditions is []
        body_statements is []
        
        if match([TokenType::BLOCK_START]) {
            until match([TokenType::BLOCK_END]) or at_end() {
                if match([TokenType::TAKES_KEYWORD]) {
                    consume(TokenType::COLON)
                    until match([TokenType::NEWLINE]) or check(TokenType::BLOCK_END) or at_end() {
                        param_name is consume(TokenType::IDENTIFIER).value
                        param_type is nil
                        if match([TokenType::MINUS]) {
                            param_type is consume_expecting([TokenType::TYPE_KW, TokenType::IDENTIFIER]).value
                        }
                        params.append(ParameterNode(param_name, type: param_type))
                        match([TokenType::COMMA])
                    }
                }
                else if match([TokenType::RETURNS_KEYWORD]) {
                    consume(TokenType::COLON)
                    # Check if next is type or expression
                    if check(TokenType::TYPE_KW) or (check(TokenType::IDENTIFIER) and not peek_token().type in [TokenType::PLUS, TokenType::MINUS, TokenType::STAR, TokenType::SLASH, TokenType::LPAREN, TokenType::LBRACKET, TokenType::LBRACE, TokenType::INTEGER_LITERAL, TokenType::FLOAT_LITERAL, TokenType::STRING_LITERAL]) {
                        return_type is parse_type_annotation()
                    } else {
                        body_statements.append(ReturnStatementNode(expression()))
                    }
                    match([TokenType::NEWLINE])
                }
                else if match([TokenType::REQUIRES_KEYWORD]) {
                    consume(TokenType::COLON)
                    until match([TokenType::NEWLINE]) or check(TokenType::BLOCK_END) or at_end() {
                        preconditions.append(expression())
                        match([TokenType::COMMA])
                    }
                }
                else if match([TokenType::ENSURES_KEYWORD]) {
                    consume(TokenType::COLON)
                    until match([TokenType::NEWLINE]) or check(TokenType::BLOCK_END) or at_end() {
                        postconditions.append(expression())
                        match([TokenType::COMMA])
                    }
                }
                else {
                    stmt is statement()
                    if stmt != nil {
                        body_statements.append(stmt)
                    }
                    match([TokenType::NEWLINE])
                }
            }
        }
        else if match([TokenType::BEGIN_KEYWORD]) {
            until match([TokenType::END_KEYWORD]) or at_end() {
                stmt is statement()
                if stmt != nil {
                    body_statements.append(stmt)
                }
                match([TokenType::NEWLINE])
            }
        }
        else {
            body_statements.append(expression_statement())
        }
        
        FunctionDeclarationNode(name, parameters: params, return_type: return_type, preconditions: preconditions, postconditions: postconditions, body: BlockNode(body_statements), line: start_token.line, column: start_token.column)
    }
    
    make a function called parse_template {
        takes: name, body, start_token, is_class
        parent is nil
        fields is []
        invariants is []
        methods is []
        
        for stmt in body.statements {
            if stmt.class == ExpressionStatementNode {
                expr is stmt.expression
                if expr.class == CallNode and expr.callee.class == IdentifierNode {
                    if expr.callee.name == "inherits" {
                        parent is expr.arguments[0]
                    }
                    else if expr.callee.name == "has" {
                        for arg in expr.arguments {
                            if arg.class == CallNode {
                                fields.append(parse_field(arg))
                            }
                        }
                    }
                    else if expr.callee.name == "maintains" {
                        invariants is invariants + expr.arguments
                    }
                    else if stmt.class == FunctionDeclarationNode {
                        methods.append(stmt)
                    }
                }
            }
        }
        
        TemplateDeclarationNode(name, parent: parent, fields: fields, invariants: invariants, methods: methods, line: start_token.line, column: start_token.column)
    }
    
    make a function called parse_goal {
        takes: name, start_token
        requirements is []
        achievement_conditions is []
        goal_body is nil
        
        consume(TokenType::BLOCK_START)
        until match([TokenType::BLOCK_END]) or at_end() {
            match([TokenType::NEWLINE])
            
            if match([TokenType::REQUIRES_KEYWORD]) {
                consume(TokenType::COLON)
                until match([TokenType::NEWLINE]) or check(TokenType::BLOCK_END) or at_end() {
                    req_name is consume(TokenType::IDENTIFIER).value
                    requirements.append(RequirementNode(req_name))
                    match([TokenType::COMMA])
                }
            }
            else if match([TokenType::ACHIEVED_KEYWORD]) {
                if match([TokenType::WHEN_KEYWORD]) {
                    consume(TokenType::COLON)
                } else {
                    consume(TokenType::COLON)
                }
                until match([TokenType::NEWLINE]) or check(TokenType::BLOCK_END) or at_end() {
                    achievement_conditions.append(expression())
                    match([TokenType::COMMA])
                }
            }
            else if match([TokenType::RUNS_KEYWORD]) {
                consume(TokenType::COLON)
                if match([TokenType::BLOCK_START]) {
                    body_statements is []
                    until match([TokenType::BLOCK_END]) or at_end() {
                        body_statements.append(statement())
                        match([TokenType::NEWLINE])
                    }
                    goal_body is BlockNode(body_statements)
                } else {
                    goal_body is expression()
                }
                match([TokenType::NEWLINE])
            }
            else {
                match([TokenType::NEWLINE])
            }
        }
        
        GoalDeclarationNode(name, requirements: requirements, achievement_conditions: achievement_conditions, body: goal_body, line: start_token.line, column: start_token.column)
    }
    
    make a function called parse_field {
        takes: call_node
        name is call_node.callee.name if call_node.callee.class == IdentifierNode else nil
        FieldNode(name)
    }
    
    make a function called initialize_list {
        takes: name, body, start_token
        elements is []
        for stmt in body.statements {
            if stmt.class == ExpressionStatementNode {
                elements.append(stmt.expression)
            }
        }
        VariableDeclarationNode(name, initializer: ListLiteralNode(elements), line: start_token.line, column: start_token.column)
    }
    
    make a function called initialize_typed_var {
        takes: name, type_name, body, start_token
        initializer is nil
        for stmt in body.statements {
            if stmt.class == ExpressionStatementNode {
                initializer is stmt.expression
                break
            }
        }
        VariableDeclarationNode(name, type: TypeAnnotationNode(type_name, line: start_token.line, column: start_token.column), initializer: initializer, line: start_token.line, column: start_token.column)
    }
    
    # Event handler
    make a function called event_handler {
        start_token is consume(TokenType::WHEN_KEYWORD)
        event_name_token is consume(TokenType::IDENTIFIER)
        event_name is event_name_token.value
        event_action is nil
        
        if match([TokenType::COLON]) {
            action_token is consume_expecting([TokenType::EVENT_ACTION_KW, TokenType::IDENTIFIER])
            event_action is action_token.value.to_sym()
        }
        
        body is block()
        EventHandlerNode(event_name, event_action: event_action, body: body, line: start_token.line, column: start_token.column)
    }
    
    # Control flow
    make a function called if_statement {
        start_token is consume(TokenType::IF_KW)
        condition is expression()
        consume(TokenType::THEN_KEYWORD)
        then_branch is block()
        
        elsif_branches is []
        while match([TokenType::ELSIF_KEYWORD]) {
            elsif_condition is expression()
            consume(TokenType::THEN_KEYWORD)
            elsif_branch is block()
            elsif_branches.append([elsif_condition, elsif_branch])
        }
        
        else_branch is nil
        if match([TokenType::ELSE_KEYWORD]) {
            else_branch is block()
        }
        
        consume(TokenType::END_KEYWORD)
        IfStatementNode(condition, then_branch, elsif_branches: elsif_branches, else_branch: else_branch, line: start_token.line, column: start_token.column)
    }
    
    make a function called while_statement {
        start_token is consume(TokenType::WHILE_KEYWORD)
        condition is expression()
        consume(TokenType::DO_KEYWORD)
        body is block()
        consume(TokenType::END_KEYWORD)
        WhileStatementNode(condition, body, line: start_token.line, column: start_token.column)
    }
    
    make a function called for_statement {
        start_token is consume(TokenType::FOR_KEYWORD)
        variable_token is consume(TokenType::IDENTIFIER)
        variable is variable_token.value
        consume(TokenType::IN_KEYWORD)
        
        is_range is false
        range_start is nil
        range_end is nil
        iterable is nil
        
        if match([TokenType::RANGE_KEYWORD]) {
            is_range is true
            consume(TokenType::LPAREN)
            range_start is expression()
            consume(TokenType::COMMA)
            range_end is expression()
            consume(TokenType::RPAREN)
        } else {
            iterable is expression()
        }
        
        consume(TokenType::DO_KEYWORD)
        body is block()
        consume(TokenType::END_KEYWORD)
        ForStatementNode(variable, iterable, body, is_range: is_range, range_start: range_start, range_end: range_end, line: start_token.line, column: start_token.column)
    }
    
    # Assignment / Mutation
    make a function called assignment_or_mutation {
        name_token is consume(TokenType::IDENTIFIER)
        name is name_token.value
        
        if match([TokenType::IS_KEYWORD]) {
            value is expression()
            AssignmentNode(name, value, line: name_token.line, column: name_token.column)
        }
        else if match([TokenType::BECOMES_KEYWORD]) {
            value is expression()
            MutationNode(name, value, line: name_token.line, column: name_token.column)
        }
        else {
            raise(ParseError("Expected 'is' or 'becomes' after identifier"))
        }
    }
    
    # Other statements
    make a function called activate_statement {
        start_token is consume(TokenType::ACTIVATE_KEYWORD)
        goal_name_token is consume(TokenType::IDENTIFIER)
        goal_name is goal_name_token.value
        arguments is nil
        if match([TokenType::WITH_KEYWORD]) {
            arguments is expression()
        }
        ActivateStatementNode(goal_name, arguments: arguments, line: start_token.line, column: start_token.column)
    }
    
    make a function called query_statement {
        start_token is consume(TokenType::QUERY_KEYWORD)
        name_token is consume(TokenType::IDENTIFIER)
        name is name_token.value
        body is block()
        consume(TokenType::END_KEYWORD)
        QueryStatementNode(name, body, line: start_token.line, column: start_token.column)
    }
    
    make a function called assert_statement {
        start_token is consume(TokenType::ASSERT_KEYWORD)
        predicate_token is consume(TokenType::IDENTIFIER)
        predicate is predicate_token.value
        arguments is []
        if match([TokenType::LPAREN]) {
            until match([TokenType::RPAREN]) or at_end() {
                arguments.append(expression())
                match([TokenType::COMMA])
            }
        }
        AssertStatementNode(predicate, arguments: arguments, line: start_token.line, column: start_token.column)
    }
    
    make a function called return_statement {
        start_token is consume(TokenType::RETURN_KEYWORD)
        value is nil
        if not check(TokenType::NEWLINE) and not check(TokenType::END_KEYWORD) and not check(TokenType::EOF) {
            value is expression()
        }
        ReturnStatementNode(value, line: start_token.line, column: start_token.column)
    }
    
    make a function called expression_statement {
        expr is expression()
        ExpressionStatementNode(expr)
    }
    
    # Block parsing
    make a function called block {
        statements is []
        if match([TokenType::BLOCK_START]) {
            until match([TokenType::BLOCK_END]) or at_end() {
                statements.append(statement())
                match([TokenType::NEWLINE])
            }
        }
        else if match([TokenType::BEGIN_KEYWORD]) {
            until match([TokenType::END_KEYWORD]) or at_end() {
                statements.append(statement())
                match([TokenType::NEWLINE])
            }
        }
        else {
            stmt is statement()
            if stmt != nil {
                statements.append(stmt)
            }
        }
        BlockNode(statements)
    }
    
    # Expression parsing (Precedence Climbing)
    make a function called expression {
        logical_or()
    }
    
    make a function called logical_or {
        left is logical_and()
        while match([TokenType::OR_KEYWORD]) {
            operator is previous_token()
            right is logical_and()
            left is BinaryOpNode(left, operator.value, right, line: operator.line, column: operator.column)
        }
        left
    }
    
    make a function called logical_and {
        left is equality()
        while match([TokenType::AND_KEYWORD]) {
            operator is previous_token()
            right is equality()
            left is BinaryOpNode(left, operator.value, right, line: operator.line, column: operator.column)
        }
        left
    }
    
    make a function called equality {
        left is comparison()
        while match([TokenType::IS_KEYWORD, TokenType::IS_NOT_KEYWORD, TokenType::EQ, TokenType::NEQ]) {
            operator is previous_token()
            right is comparison()
            left is BinaryOpNode(left, operator.value, right, line: operator.line, column: operator.column)
        }
        left
    }
    
    make a function called comparison {
        left is additive()
        while match([TokenType::LT, TokenType::GT, TokenType::LTE, TokenType::GTE]) {
            operator is previous_token()
            right is additive()
            left is BinaryOpNode(left, operator.value, right, line: operator.line, column: operator.column)
        }
        left
    }
    
    make a function called additive {
        left is multiplicative()
        while match([TokenType::PLUS, TokenType::MINUS]) {
            operator is previous_token()
            right is multiplicative()
            left is BinaryOpNode(left, operator.value, right, line: operator.line, column: operator.column)
        }
        left
    }
    
    make a function called multiplicative {
        left is unary()
        while match([TokenType::STAR, TokenType::SLASH, TokenType::PERCENT]) {
            operator is previous_token()
            right is unary()
            left is BinaryOpNode(left, operator.value, right, line: operator.line, column: operator.column)
        }
        left
    }
    
    make a function called unary {
        if match([TokenType::NOT_KEYWORD, TokenType::MINUS]) {
            operator is previous_token()
            operand is unary()
            UnaryOpNode(operator.value, operand, line: operator.line, column: operator.column)
        } else {
            primary()
        }
    }
    
    make a function called primary {
        case = current_token().type
        
        if case == TokenType::INTEGER_LITERAL {
            token is advance()
            IntegerLiteralNode(token.value, line: token.line, column: token.column)
        }
        else if case == TokenType::FLOAT_LITERAL {
            token is advance()
            FloatLiteralNode(token.value, line: token.line, column: token.column)
        }
        else if case == TokenType::STRING_LITERAL {
            token is advance()
            StringLiteralNode(token.value, line: token.line, column: token.column)
        }
        else if case == TokenType::TRUE_KEYWORD {
            token is advance()
            BooleanLiteralNode(true, line: token.line, column: token.column)
        }
        else if case == TokenType::FALSE_KEYWORD {
            token is advance()
            BooleanLiteralNode(false, line: token.line, column: token.column)
        }
        else if case == TokenType::NIL_KEYWORD {
            token is advance()
            NilLiteralNode(line: token.line, column: token.column)
        }
        else if case == TokenType::IDENTIFIER {
            parse_identifier_or_call()
        }
        else if case == TokenType::LPAREN {
            parse_paren_or_lambda()
        }
        else if case == TokenType::BLOCK_PARAM_START {
            parse_lambda()
        }
        else if case == TokenType::BLOCK_START {
            if peek_is_takes_or_returns() {
                parse_lambda_expression()
            } else {
                parse_block_expression()
            }
        }
        else if case == TokenType::LBRACKET {
            parse_list_literal()
        }
        else {
            raise(ParseError("Unexpected token in expression: " + current_token().type, current_token()))
        }
    }
    
    make a function called parse_block_expression {
        consume(TokenType::BLOCK_START)
        if is_object_literal() {
            return parse_object_literal()
        }
        body is block()
        consume(TokenType::BLOCK_END)
        body
    }
    
    make a function called is_object_literal {
        saved_idx is current
        advance()  # Skip BLOCK_START
        
        # Skip whitespace/newlines
        while current_token().type == TokenType::NEWLINE {
            advance()
        }
        
        result is false
        if current_token().type == TokenType::IDENTIFIER {
            peek_idx is current + 1
            while peek_idx < tokens.length and tokens[peek_idx].type == TokenType::NEWLINE {
                peek_idx is peek_idx + 1
            }
            if peek_idx < tokens.length and tokens[peek_idx].type == TokenType::COLON {
                result is true
            }
        }
        
        current is saved_idx
        result
    }
    
    make a function called parse_object_literal {
        consume(TokenType::BLOCK_START)
        obj_pairs is []
        
        until at_end() {
            match([TokenType::NEWLINE])
            
            if check(TokenType::BLOCK_END) {
                break
            }
            
            if check(TokenType::IDENTIFIER) and peek_token().type == TokenType::COLON {
                key_token is consume(TokenType::IDENTIFIER)
                key is key_token.value
                consume(TokenType::COLON)
                value is expression()
                obj_pairs.append(KeyValuePairNode(key, value))
                match([TokenType::COMMA])
            } else {
                return parse_block_expression_fallback()
            }
        }
        
        consume(TokenType::BLOCK_END)
        ObjectLiteralNode(obj_pairs)
    }
    
    make a function called parse_block_expression_fallback {
        consume(TokenType::BLOCK_END)
        ObjectLiteralNode([])
    }
    
    make a function called peek_is_takes_or_returns {
        saved_idx is current
        saved_token is tokens[current]
        advance()
        while current_token().type == TokenType::NEWLINE {
            advance()
        }
        result is current_token().type == TokenType::TAKES_KEYWORD or current_token().type == TokenType::RETURNS_KEYWORD
        current is saved_idx
        tokens[saved_idx] is saved_token
        result
    }
    
    make a function called parse_lambda_expression {
        consume(TokenType::BLOCK_START)
        params is []
        return_type is nil
        preconditions is []
        postconditions is []
        body_statements is []
        
        until match([TokenType::BLOCK_END]) or at_end() {
            if match([TokenType::TAKES_KEYWORD]) {
                consume(TokenType::COLON)
                until match([TokenType::NEWLINE]) or check(TokenType::BLOCK_END) or at_end() {
                    param_name is consume(TokenType::IDENTIFIER).value
                    param_type is nil
                    if match([TokenType::MINUS]) {
                        param_type is consume_expecting([TokenType::TYPE_KW, TokenType::IDENTIFIER]).value
                    }
                    params.append(ParameterNode(param_name, type: param_type))
                    match([TokenType::COMMA])
                }
            }
            else if match([TokenType::RETURNS_KEYWORD]) {
                consume(TokenType::COLON)
                if check(TokenType::TYPE_KW) {
                    return_type is parse_type_annotation()
                } else {
                    body_statements.append(ReturnStatementNode(expression()))
                }
                match([TokenType::NEWLINE])
            }
            else if match([TokenType::REQUIRES_KEYWORD]) {
                consume(TokenType::COLON)
                until match([TokenType::NEWLINE]) or check(TokenType::BLOCK_END) or at_end() {
                    preconditions.append(expression())
                    match([TokenType::COMMA])
                }
            }
            else if match([TokenType::ENSURES_KEYWORD]) {
                consume(TokenType::COLON)
                until match([TokenType::NEWLINE]) or check(TokenType::BLOCK_END) or at_end() {
                    postconditions.append(expression())
                    match([TokenType::COMMA])
                }
            }
            else {
                body_statements.append(statement())
                match([TokenType::NEWLINE])
            }
        }
        LambdaNode(params, BlockNode(body_statements))
    }
    
    make a function called parse_identifier_or_call {
        name_token is consume(TokenType::IDENTIFIER)
        name is name_token.value
        
        if match([TokenType::LPAREN]) {
            arguments is []
            until match([TokenType::RPAREN]) or at_end() {
                arguments.append(expression())
                match([TokenType::COMMA])
            }
            CallNode(IdentifierNode(name, line: name_token.line, column: name_token.column), arguments: arguments, line: name_token.line, column: name_token.column)
        } else {
            IdentifierNode(name, line: name_token.line, column: name_token.column)
        }
    }
    
    make a function called parse_paren_or_lambda {
        consume(TokenType::LPAREN)
        
        if current_token().type == TokenType::BLOCK_PARAM_START {
            lambda_node is parse_lambda()
            consume(TokenType::RPAREN)
            lambda_node
        } else {
            expr is expression()
            consume(TokenType::RPAREN)
            ParenExpressionNode(expr)
        }
    }
    
    make a function called parse_lambda {
        consume(TokenType::BLOCK_PARAM_START)
        parameters is []
        until match([TokenType::BLOCK_PARAM_END]) or at_end() {
            param_token is consume(TokenType::IDENTIFIER)
            parameters.append(ParameterNode(param_token.value, line: param_token.line, column: param_token.column))
            match([TokenType::COMMA])
        }
        body is block()
        LambdaNode(parameters, body)
    }
    
    make a function called parse_list_literal {
        consume(TokenType::LBRACKET)
        elements is []
        until match([TokenType::RBRACKET]) or at_end() {
            elements.append(expression())
            match([TokenType::COMMA])
        }
        ListLiteralNode(elements)
    }
    
    make a function called parse_type_annotation {
        token is consume_expecting([TokenType::TYPE_KW, TokenType::IDENTIFIER])
        TypeAnnotationNode(token.value, line: token.line, column: token.column)
    }
}