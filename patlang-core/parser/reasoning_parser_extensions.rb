# Parser extensions for enhanced reasoning syntax support
# This module provides additional parsing capabilities for complex reasoning constructs

module ParserModules
  module ReasoningParserExtensions
    
    # Enhanced constraint parsing with better structural support
    def parse_enhanced_constraint
      return parse_constraint unless @current_token&.type == :CONSTRAIN
      
      eat(:CONSTRAIN)
      
      # Parse variable expression (supports dotted notation)
      variable_expr = parse_constraint_variable_enhanced
      return safe_error("Expected variable after 'constrain'") unless variable_expr
      
      # Parse constraint type
      unless @current_token&.type == :DOUBLE_COLON
        return safe_error("Expected '::' after constraint variable")
      end
      eat(:DOUBLE_COLON)
      
      # Parse constraint specification
      constraint_spec = parse_constraint_specification
      return safe_error("Expected constraint specification") unless constraint_spec
      
      # Parse optional conditions
      conditions = nil
      if @current_token&.type == :WHERE
        eat(:WHERE)
        conditions = expression
      end
      
      # Create appropriate constraint node
      if constraint_spec.is_a?(Hash) && constraint_spec[:type] == :structural
        StructuralConstraintNode.new(variable_expr, constraint_spec[:fields], conditions)
      else
        TypeConstraintNode.new(variable_expr, constraint_spec[:type] || constraint_spec, 
                              constraint_spec[:data], conditions)
      end
    end
    
    # Enhanced variable parsing with full dotted support
    def parse_constraint_variable_enhanced
      return nil unless @current_token&.type == :IDENTIFIER
      
      base = @current_token.value
      eat(:IDENTIFIER)
      
      # Handle dotted expressions
      if @current_token&.type == :DOT
        path_segments = [base]
        while @current_token&.type == :DOT
          eat(:DOT)
          return nil unless @current_token&.type == :IDENTIFIER
          path_segments << @current_token.value
          eat(:IDENTIFIER)
        end
        return path_segments.join(".")
      end
      
      base.to_sym
    end
    
    # Parse constraint specifications (types, ranges, patterns, structures)
    def parse_constraint_specification
      return nil unless @current_token&.type == :IDENTIFIER
      
      constraint_type = @current_token.value
      eat(:IDENTIFIER)
      
      case constraint_type
      when 'Object'
        # Parse structural constraint: Object { field :: Type, ... }
        if @current_token&.type == :LBRACE
          fields = parse_object_structure
          { type: :structural, fields: fields }
        else
          { type: :Object }
        end
      when 'Array'
        # Parse array constraint: Array[ElementType]
        if @current_token&.type == :LBRACKET
          element_type = parse_array_element_type
          { type: :Array, element_type: element_type }
        else
          { type: :Array }
        end
      else
        # Simple type constraint
        { type: constraint_type.to_sym }
      end
    end
    
    # Parse object structure definition
    def parse_object_structure
      fields = {}
      eat(:LBRACE)
      
      while @current_token&.type != :RBRACE && @current_token
        # Parse field name
        return nil unless @current_token&.type == :IDENTIFIER
        field_name = @current_token.value.to_sym
        eat(:IDENTIFIER)
        
        # Parse field constraint
        if @current_token&.type == :DOUBLE_COLON
          eat(:DOUBLE_COLON)
          field_constraint = parse_constraint_specification
          fields[field_name] = field_constraint
        else
          return nil
        end
        
        # Handle comma separation
        if @current_token&.type == :COMMA
          eat(:COMMA)
        elsif @current_token&.type != :RBRACE
          break
        end
      end
      
      eat(:RBRACE) if @current_token&.type == :RBRACE
      fields
    end
    
    # Parse array element type specification
    def parse_array_element_type
      eat(:LBRACKET)
      element_spec = parse_constraint_specification
      eat(:RBRACKET) if @current_token&.type == :RBRACKET
      element_spec
    end
    
    # Enhanced goal parsing with better parameter and condition support
    def parse_enhanced_goal
      return parse_goal unless @current_token&.type == :GOAL
      
      eat(:GOAL)
      return safe_error("Expected goal name") unless @current_token&.type == :IDENTIFIER
      
      goal_name = @current_token.value
      eat(:IDENTIFIER)
      
      # Parse parameters
      parameters = []
      if @current_token&.type == :LPAREN
        parameters = parse_goal_parameters
      end
      
      # Parse goal body
      goal_attributes = {}
      if @current_token&.type == :LBRACE
        goal_attributes = parse_goal_body_enhanced
      end
      
      # Create enhanced goal node
      EnhancedGoalNode.new(goal_name, parameters, 
                          goal_attributes[:preconditions] || [],
                          goal_attributes[:postconditions] || [],
                          goal_attributes[:strategies] || [],
                          goal_attributes[:metadata] || {})
    end
    
    # Parse goal parameters with type annotations
    def parse_goal_parameters
      parameters = []
      eat(:LPAREN)
      
      while @current_token&.type != :RPAREN && @current_token
        param = parse_goal_parameter
        parameters << param if param
        
        if @current_token&.type == :COMMA
          eat(:COMMA)
        elsif @current_token&.type != :RPAREN
          break
        end
      end
      
      eat(:RPAREN) if @current_token&.type == :RPAREN
      parameters
    end
    
    # Parse individual goal parameter
    def parse_goal_parameter
      return nil unless @current_token&.type == :IDENTIFIER
      
      param_name = @current_token.value
      eat(:IDENTIFIER)
      
      # Check for type annotation
      param_type = nil
      if @current_token&.type == :DOUBLE_COLON
        eat(:DOUBLE_COLON)
        param_type = @current_token&.value if @current_token&.type == :IDENTIFIER
        eat(:IDENTIFIER) if @current_token&.type == :IDENTIFIER
      end
      
      { name: param_name.to_sym, type: param_type&.to_sym }
    end
    
    # Enhanced goal body parsing
    def parse_goal_body_enhanced
      attributes = {
        preconditions: [],
        postconditions: [],
        strategies: [],
        metadata: {}
      }
      
      eat(:LBRACE)
      
      while @current_token&.type != :RBRACE && @current_token
        case @current_token.type
        when :PRECONDITION
          eat(:PRECONDITION)
          eat(:COLON) if @current_token&.type == :COLON
          condition = expression
          attributes[:preconditions] << condition if condition
          
        when :POSTCONDITION
          eat(:POSTCONDITION)
          eat(:COLON) if @current_token&.type == :COLON
          condition = expression
          attributes[:postconditions] << condition if condition
          
        when :STRATEGY
          eat(:STRATEGY)
          eat(:COLON) if @current_token&.type == :COLON
          strategy = parse_strategy_specification
          attributes[:strategies] << strategy if strategy
          
        when :IDENTIFIER
          # Handle extended goal attributes
          attr_name = @current_token.value
          eat(:IDENTIFIER)
          eat(:COLON) if @current_token&.type == :COLON
          
          case attr_name
          when 'strategies'
            strategies = parse_strategies_array
            attributes[:strategies].concat(strategies) if strategies
          when 'timeout'
            timeout_expr = expression
            attributes[:metadata][:timeout] = timeout_expr
          when 'priority'
            priority_expr = expression
            attributes[:metadata][:priority] = priority_expr
          else
            # Generic metadata
            value_expr = expression
            attributes[:metadata][attr_name.to_sym] = value_expr
          end
        end
        
        # Handle comma separation
        if @current_token&.type == :COMMA
          eat(:COMMA)
        end
      end
      
      eat(:RBRACE) if @current_token&.type == :RBRACE
      attributes
    end
    
    # Parse strategy specification
    def parse_strategy_specification
      if @current_token&.type == :IDENTIFIER
        strategy_name = @current_token.value
        eat(:IDENTIFIER)
        strategy_name.to_sym
      elsif @current_token&.type == :STRING
        strategy_name = @current_token.value
        eat(:STRING)
        strategy_name.to_sym
      end
    end
    
    # Parse strategies array
    def parse_strategies_array
      return nil unless @current_token&.type == :LBRACKET
      
      strategies = []
      eat(:LBRACKET)
      
      while @current_token&.type != :RBRACKET && @current_token
        if @current_token.type == :STRING
          strategies << @current_token.value.to_sym
          eat(:STRING)
        elsif @current_token.type == :IDENTIFIER
          strategies << @current_token.value.to_sym
          eat(:IDENTIFIER)
        end
        
        if @current_token&.type == :COMMA
          eat(:COMMA)
        end
      end
      
      eat(:RBRACKET) if @current_token&.type == :RBRACKET
      strategies
    end
    
    # Enhanced rule parsing with better body composition
    def parse_enhanced_rule
      return parse_rule unless @current_token&.type == :RULE
      
      eat(:RULE)
      return safe_error("Expected rule head") unless @current_token
      
      # Parse rule head
      head = expression
      return safe_error("Invalid rule head") unless head
      
      # Parse rule body
      body = nil
      rule_type = :standard
      
      if @current_token&.type == :IF
        eat(:IF)
        body = parse_rule_body_conjunction
      elsif @current_token&.type == :COLON && peek(1)&.type == :MINUS
        eat(:COLON)
        eat(:MINUS)
        body = parse_rule_body_conjunction
        rule_type = :prolog
      end
      
      EnhancedLogicRuleNode.new(head, body, rule_type)
    end
    
    # Parse rule body as conjunction of terms
    def parse_rule_body_conjunction
      terms = []
      
      # Parse first term
      term = expression
      terms << term if term
      
      # Parse additional terms separated by commas or AND
      while (@current_token&.type == :COMMA || @current_token&.type == :AND) && @current_token
        advance  # Skip comma or AND
        term = expression
        terms << term if term
      end
      
      case terms.length
      when 0
        nil
      when 1
        terms.first
      else
        ConjunctionNode.new(terms)
      end
    end
  end
end