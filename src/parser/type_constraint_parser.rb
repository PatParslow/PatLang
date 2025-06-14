module ParserModules
  # Parser extension for handling type constraint syntax
  class TypeConstraintParser
    def initialize(parser, *additional_args)
      @parser = parser
      @recursion_depth = 0
      @max_recursion_depth = 50  # CRITICAL FIX: Prevent infinite recursion
    end

    # Parse type annotation syntax: variable :: type_constraint
    def parse_type_annotation
      variable_name = expect_identifier
      @parser.eat(:DOUBLE_COLON)
      type_constraint = parse_type_constraint
      
      # Fire event when type annotation is parsed
      if @parser.respond_to?(:fire_event)
        @parser.fire_event(:type_annotation_parsed, {
          variable: variable_name,
          type: type_constraint
        })
      end
      
      TypeAnnotationNode.new(variable_name, type_constraint)
    end

    # Parse various type constraint forms
    def parse_type_constraint
      # CRITICAL FIX: Check recursion depth to prevent infinite loops
      @recursion_depth += 1
      if @recursion_depth > @max_recursion_depth
        @parser.error("Type constraint parsing recursion depth exceeded (#{@max_recursion_depth})")
      end
      
      begin
        if @parser.current_token.type == :IDENTIFIER
          base_type = @parser.current_token.value.to_sym
          @parser.advance
          
          # Check for generic type: Type[...]
          if @parser.current_token&.type == :LEFT_BRACKET
            return parse_generic_type_constraint(base_type)
          end
          
          # Check for constraint parameters: Type(...)
          if @parser.current_token&.type == :LEFT_PAREN
            return parse_parameterized_constraint(base_type)
          end
          
          # Simple type constraint
          base_type
        elsif @parser.current_token.type == :LEFT_BRACE
          # Structural constraint: {...}
          parse_structural_constraint
        else
          @parser.error("Expected type constraint")
        end
      ensure
        @recursion_depth -= 1
      end
    end

    # Parse generic type constraints: Array[Number], Hash[String, Number]
    def parse_generic_type_constraint(base_type)
      @parser.eat(:LEFT_BRACKET)
      
      type_parameters = []
      loop do
        type_parameters << parse_type_constraint
        
        if @parser.current_token.type == :COMMA
          @parser.advance
        elsif @parser.current_token.type == :RIGHT_BRACKET
          break
        else
          @parser.error("Expected , or ] in generic type parameters")
        end
      end
      
      @parser.eat(:RIGHT_BRACKET)
      GenericTypeConstraint.new(base_type, type_parameters)
    end

    # Parse parameterized constraints: Number(0..100), String(/pattern/)
    def parse_parameterized_constraint(base_type)
      @parser.eat(:LEFT_PAREN)
      
      case base_type
      when :Number
        parse_range_constraint(base_type)
      when :String
        parse_pattern_constraint(base_type)
      else
        @parser.error("Unknown parameterized constraint for #{base_type}")
      end
    end

    # Parse range constraints: (0..100), (0...100)
    def parse_range_constraint(base_type)
      min_value = parse_number
      
      if @parser.current_token.type == :DOT_DOT
        @parser.advance
        exclusive = false
      elsif @parser.current_token.type == :DOT_DOT_DOT
        @parser.advance
        exclusive = true
      else
        @parser.error("Expected .. or ... in range constraint")
      end
      
      max_value = parse_number
      @parser.eat(:RIGHT_PAREN)
      
      RangeConstraint.new(base_type, min_value, max_value, exclusive)
    end

    # Parse pattern constraints: (/regex/)
    def parse_pattern_constraint(base_type)
      if @parser.current_token.type == :REGEX
        pattern = @parser.current_token.value
        @parser.advance
        @parser.eat(:RIGHT_PAREN)
        PatternConstraint.new(base_type, pattern)
      else
        @parser.error("Expected regex pattern in pattern constraint")
      end
    end

    # Parse structural constraints: {field: Type, field2: Type}
    def parse_structural_constraint
      @parser.eat(:LEFT_BRACE)
      
      field_constraints = {}
      
      until @parser.current_token.type == :RIGHT_BRACE
        field_name = expect_identifier.to_sym
        
        # Check for required/optional markers
        required = true
        if @parser.current_token.type == :QUESTION
          required = false
          @parser.advance
        elsif @parser.current_token.type == :EXCLAMATION
          required = true
          @parser.advance
        end
        
        @parser.eat(:COLON)
        field_type = parse_type_constraint
        
        field_constraints[field_name] = FieldConstraint.new(field_type, required)
        
        if @parser.current_token.type == :COMMA
          @parser.advance
        elsif @parser.current_token.type == :RIGHT_BRACE
          break
        else
          @parser.error("Expected , or } in structural constraint")
        end
      end
      
      @parser.eat(:RIGHT_BRACE)
      StructuralConstraint.new(field_constraints)
    end

    # Parse union types: Type1 | Type2 | Type3
    def parse_union_type_constraint
      types = [parse_type_constraint]
      
      while @parser.current_token.type == :PIPE
        @parser.advance
        types << parse_type_constraint
      end
      
      if types.length > 1
        UnionTypeConstraint.new(types)
      else
        types.first
      end
    end

    # Parse typed assignment: variable: Type = value
    def parse_typed_assignment
      variable_name = expect_identifier
      @parser.eat(:COLON)
      type_constraint = parse_type_constraint
      @parser.eat(:EQUALS)
      value = @parser.parse_expression
      
      TypedAssignmentNode.new(variable_name, type_constraint, value)
    end

    # Parse function with type constraints
    def parse_typed_function_definition
      @parser.eat(:DEF)
      function_name = expect_identifier
      @parser.eat(:LEFT_PAREN)
      
      parameters = parse_typed_parameters
      @parser.eat(:RIGHT_PAREN)
      
      return_type = nil
      if @parser.current_token.type == :ARROW
        @parser.advance
        return_type = parse_type_constraint
      end
      
      body = @parser.parse_block if @parser.current_token.type == :LEFT_BRACE
      
      TypedFunctionDefinitionNode.new(function_name, parameters, return_type, body)
    end

    # Parse function parameters with type constraints
    def parse_typed_parameters
      parameters = []
      
      until @parser.current_token.type == :RIGHT_PAREN
        param_name = expect_identifier
        
        # Check for optional parameter
        required = true
        if @parser.current_token.type == :QUESTION
          required = false
          @parser.advance
        end
        
        @parser.eat(:COLON)
        param_type = parse_type_constraint
        
        parameters << ParameterNode.new(param_name, param_type, required)
        
        if @parser.current_token.type == :COMMA
          @parser.advance
        elsif @parser.current_token.type == :RIGHT_PAREN
          break
        else
          @parser.error("Expected , or ) in parameter list")
        end
      end
      
      parameters
    end

    private

    def expect_identifier
      if @parser.current_token.type == :IDENTIFIER
        name = @parser.current_token.value
        @parser.advance
        name
      else
        @parser.error("Expected identifier")
      end
    end

    def parse_number
      if @parser.current_token.type == :NUMBER
        value = @parser.current_token.value
        @parser.advance
        value
      else
        @parser.error("Expected number")
      end
    end
  end
end