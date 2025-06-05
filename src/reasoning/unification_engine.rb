# frozen_string_literal: true

# Core unification engine for type inference and reasoning
# This is a minimal stub implementation for Phase 1 TDD
class UnificationEngine
  def initialize
    @event_handlers = {}
    @unification_count = 0
  end

  # Register event handlers for unification events
  def on_event(event_type, &block)
    @event_handlers[event_type] ||= []
    @event_handlers[event_type] << block
  end

  # Main unification method - attempts to unify two terms with a substitution
  # Returns true if unification succeeds, false otherwise
  # Modifies the substitution hash in place with new bindings
  def unify(term1, term2, substitution, **options)
    @unification_count += 1
    event_id = generate_event_id
    
    validate_inputs!(term1, term2, substitution)
    
    fire_event(:unification_started, {
      event_id: event_id,
      term1: term1,
      term2: term2,
      substitution: substitution.dup
    })

    begin
      result = perform_unification(term1, term2, substitution, **options)
      
      if result
        fire_event(:unification_completed, {
          event_id: event_id,
          success: true,
          term1: term1,
          term2: term2,
          substitution: substitution.dup
        })
      else
        fire_event(:unification_failed, {
          event_id: event_id,
          term1: term1,
          term2: term2,
          reason: "Terms do not unify"
        })
      end
      
      result
    rescue => e
      fire_event(:unification_failed, {
        event_id: event_id,
        term1: term1,
        term2: term2,
        error: e.message
      })
      raise
    end
  end

  # Get statistics about unification operations
  def statistics
    {
      total_unifications: @unification_count,
      event_handlers: @event_handlers.keys
    }
  end

  private

  def validate_inputs!(term1, term2, substitution)
    if term1.nil? || term2.nil?
      raise UnificationError, "Cannot unify with nil terms"
    end
    
    unless substitution.is_a?(Hash)
      raise UnificationError, "substitution must be a Hash, got #{substitution.class}"
    end
    
    unless valid_term?(term1) && valid_term?(term2)
      raise UnificationError, "Invalid term: malformed term structure"
    end
  end

  def valid_term?(term)
    case term
    when Symbol, String, Numeric, TrueClass, FalseClass
      true
    when TypeVariable
      true
    when Term
      term.valid?
    else
      false
    end
  end

  def perform_unification(term1, term2, substitution, **options)
    # Apply existing substitutions
    term1 = apply_substitution(term1, substitution)
    term2 = apply_substitution(term2, substitution)
    
    # Core unification algorithm
    # Handle identical terms first
    return true if term1 == term2
    
    # Handle variable unification
    if term1.is_a?(TypeVariable)
      return unify_variable_with_term(term1, term2, substitution)
    elsif term2.is_a?(TypeVariable)
      return unify_variable_with_term(term2, term1, substitution)
    end
    
    # Handle compound terms
    if term1.is_a?(Term) && term2.is_a?(Term)
      return unify_compound_terms(term1, term2, substitution)
    end
    
    # Different types that aren't variables can't unify
    false
  end

  def apply_substitution(term, substitution)
    case term
    when TypeVariable
      substitution[term.name] || term
    when Term
      Term.new(term.functor, term.args.map { |arg| apply_substitution(arg, substitution) })
    else
      term
    end
  end

  def unify_variable_with_term(variable, term, substitution)
    return false unless variable.is_a?(TypeVariable)
    
    # Check if variable is already bound
    if substitution.key?(variable.name)
      return unify(substitution[variable.name], term, substitution)
    end
    
    # Occurs check - prevent infinite terms like X = f(X)
    if occurs_check(variable, term, substitution)
      return false
    end
    
    # Create binding
    substitution[variable.name] = term
    true
  end

  def unify_compound_terms(term1, term2, substitution)
    return false if term1.functor != term2.functor
    return false if term1.arity != term2.arity
    
    # Unify all arguments
    term1.args.zip(term2.args).all? do |arg1, arg2|
      unify(arg1, arg2, substitution)
    end
  end

  def occurs_check(variable, term, substitution)
    case term
    when TypeVariable
      if term.name == variable.name
        true
      elsif substitution.key?(term.name)
        occurs_check(variable, substitution[term.name], substitution)
      else
        false
      end
    when Term
      term.args.any? { |arg| occurs_check(variable, arg, substitution) }
    else
      false
    end
  end

  def fire_event(event_type, data)
    handlers = @event_handlers[event_type]
    return unless handlers
    
    handlers.each do |handler|
      begin
        handler.call(data.merge(event_type: event_type, timestamp: Time.now))
      rescue => e
        # Log error but don't let it break unification
        warn "Event handler error for #{event_type}: #{e.message}"
      end
    end
  end

  def generate_event_id
    "unif_#{@unification_count}_#{Time.now.to_f}_#{rand(1000)}"
  end
end

# Type variable for unification
class TypeVariable
  attr_reader :name

  def initialize(name)
    @name = name.to_sym
  end

  def ==(other)
    other.is_a?(TypeVariable) && @name == other.name
  end

  def hash
    @name.hash
  end

  def eql?(other)
    self == other
  end

  def to_s
    "?#{@name}"
  end

  def inspect
    "#<TypeVariable:#{@name}>"
  end
end

# Compound term for unification
class Term
  attr_reader :functor, :args

  def initialize(functor, args = [])
    @functor = functor.to_sym
    @args = Array(args)
  end

  def arity
    @args.length
  end

  def ==(other)
    other.is_a?(Term) && 
      @functor == other.functor && 
      @args == other.args
  end

  def hash
    [@functor, @args].hash
  end

  def eql?(other)
    self == other
  end

  def valid?
    @functor.is_a?(Symbol) && @args.is_a?(Array)
  end

  def to_s
    if @args.empty?
      @functor.to_s
    else
      "#{@functor}(#{@args.map(&:to_s).join(', ')})"
    end
  end

  def inspect
    "#<Term:#{to_s}>"
  end
end

# Custom error for unification failures
class UnificationError < StandardError
  attr_reader :term1, :term2

  def initialize(message, term1: nil, term2: nil)
    super(message)
    @term1 = term1
    @term2 = term2
  end
end