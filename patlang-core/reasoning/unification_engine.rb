require_relative '../object_model/patlang_object'

# Robinson's Unification Algorithm Implementation
# This is the core unification engine for Patlang's type inference system
class UnificationEngine < PatlangObject
  def initialize(evaluator = nil)
    super("unification_engine", :unification_engine)
    @evaluator = evaluator
    
    # Initialize the event system
    initialize_event_system
    
    # Initialize performance tracking
    @unification_attempts = 0
    @unification_successes = 0
    @unification_failures = 0
    @total_unification_time = 0.0
    @cache_hits = 0
    @occurs_check_calls = 0
    
    # Set up metadata for the PatlangObject
    set_metadata(:type, :unification_engine)
    set_metadata(:created_at, Time.now)
  end
  
  # Main unification method implementing Robinson's algorithm
  def unify(term1, term2, substitution = {})
    validate_inputs(term1, term2, substitution)
    
    start_time = Time.now
    @unification_attempts += 1
    
    fire_event(:unification_started, {
      event_type: :unification_started,
      term1: term1,
      term2: term2,
      timestamp: Time.now
    })
    
    begin
      result = unify_internal(term1, term2, substitution)
      execution_time = Time.now - start_time
      @total_unification_time += execution_time
      
      if result
        @unification_successes += 1
        fire_event(:unification_completed, {
          event_type: :unification_completed,
          term1: term1,
          term2: term2,
          success: true,
          substitution: substitution.dup,
          execution_time: execution_time,
          timestamp: Time.now
        })
      else
        @unification_failures += 1
        fire_event(:unification_failed, {
          event_type: :unification_failed,
          term1: term1,
          term2: term2,
          reason: "Terms do not unify",
          execution_time: execution_time,
          timestamp: Time.now
        })
      end
      
      result
    rescue => error
      execution_time = Time.now - start_time
      @total_unification_time += execution_time
      @unification_failures += 1
      
      fire_event(:unification_failed, {
        event_type: :unification_failed,
        term1: term1,
        term2: term2,
        reason: error.message,
        execution_time: execution_time,
        timestamp: Time.now
      })
      raise
    end
  end
  
  # Statistics method for reasoning coordination integration
  def statistics
    {
      unification_attempts: @unification_attempts,
      unification_successes: @unification_successes,
      unification_failures: @unification_failures,
      success_rate: @unification_attempts > 0 ? (@unification_successes.to_f / @unification_attempts * 100).round(2) : 0.0,
      total_unification_time: @total_unification_time.round(6),
      average_unification_time: @unification_attempts > 0 ? (@total_unification_time / @unification_attempts).round(6) : 0.0,
      occurs_check_calls: @occurs_check_calls,
      cache_hits: @cache_hits
    }
  end
  
  private
  
  def unify_internal(term1, term2, substitution)
    # Dereference variables if they're already bound
    term1 = deref(term1, substitution)
    term2 = deref(term2, substitution)
    
    # Case 1: Both terms are identical (atoms, numbers, strings, etc.)
    return true if term1 == term2
    
    # Case 2: term1 is a variable
    if variable?(term1)
      return unify_variable(term1, term2, substitution)
    end
    
    # Case 3: term2 is a variable
    if variable?(term2)
      return unify_variable(term2, term1, substitution)
    end
    
    # Case 4: Both are compound terms
    if compound?(term1) && compound?(term2)
      return unify_compound(term1, term2, substitution)
    end
    
    # Case 5: Terms are different types and cannot unify
    false
  end
  
  def unify_variable(var, term, substitution)
    # Check if variable is already bound
    if substitution.key?(var.name)
      return unify_internal(substitution[var.name], term, substitution)
    end
    
    # Check if term is a variable that's already bound
    if variable?(term) && substitution.key?(term.name)
      return unify_internal(var, substitution[term.name], substitution)
    end
    
    # Occurs check: prevent infinite structures like X = f(X)
    if occurs_check(var, term, substitution)
      return false
    end
    
    # Bind the variable
    substitution[var.name] = term
    true
  end
  
  def unify_compound(term1, term2, substitution)
    # Check functor and arity match
    return false unless term1.functor == term2.functor
    return false unless term1.arity == term2.arity
    
    # Unify all arguments
    term1.args.zip(term2.args).all? do |arg1, arg2|
      unify_internal(arg1, arg2, substitution)
    end
  end
  
  def occurs_check(var, term, substitution)
    @occurs_check_calls += 1
    return false unless compound?(term)
    
    # Check if variable occurs in the term structure
    occurs_in_term?(var, term, substitution)
  end
  
  def occurs_in_term?(var, term, substitution)
    # Dereference the term first
    term = deref(term, substitution)
    
    # If it's the same variable, we have an occurs check violation
    return true if variable?(term) && term.name == var.name
    
    # If it's a compound term, check recursively
    if compound?(term)
      term.args.any? { |arg| occurs_in_term?(var, arg, substitution) }
    else
      false
    end
  end
  
  def deref(term, substitution)
    if variable?(term) && substitution.key?(term.name)
      # Follow the chain of substitutions
      deref(substitution[term.name], substitution)
    else
      term
    end
  end
  
  def variable?(term)
    term.is_a?(TypeVariable)
  end
  
  def compound?(term)
    term.is_a?(Term)
  end
  
  def validate_inputs(term1, term2, substitution)
    raise ArgumentError, "First term cannot be nil" if term1.nil?
    raise ArgumentError, "Second term cannot be nil" if term2.nil?
    raise ArgumentError, "Substitution must be a Hash" unless substitution.is_a?(Hash)
    
    # Validate term types
    unless valid_term?(term1)
      raise ArgumentError, "Invalid term type: #{term1.class}. Must be atom, variable, or compound term."
    end
    
    unless valid_term?(term2)
      raise ArgumentError, "Invalid term type: #{term2.class}. Must be atom, variable, or compound term."
    end
  end
  
  def valid_term?(term)
    # Valid terms: atoms (symbols), variables, compound terms, numbers, strings, AST nodes
    term.is_a?(Symbol) ||
    term.is_a?(TypeVariable) ||
    term.is_a?(Term) ||
    term.is_a?(Numeric) ||
    term.is_a?(String) ||
    term.respond_to?(:name) ||  # AST nodes like VariableNode
    term.respond_to?(:class_name) ||  # Other AST node types
    term.respond_to?(:function_name)  # Function call nodes
  end
  
end

# Support classes for unification

class TypeVariable
  attr_reader :name
  
  def initialize(name)
    @name = name
  end
  
  def ==(other)
    other.is_a?(TypeVariable) && other.name == @name
  end
  
  def hash
    @name.hash
  end
  
  def eql?(other)
    self == other
  end
  
  def to_s
    @name.to_s
  end
  
  def inspect
    "TypeVariable(#{@name})"
  end
end

class Term
  attr_reader :functor, :args
  
  def initialize(functor, args = [])
    @functor = functor
    @args = args
  end
  
  def arity
    @args.length
  end
  
  def ==(other)
    other.is_a?(Term) && 
    other.functor == @functor && 
    other.args == @args
  end
  
  def hash
    [@functor, @args].hash
  end
  
  def eql?(other)
    self == other
  end
  
  def to_s
    if @args.empty?
      @functor.to_s
    else
      "#{@functor}(#{@args.map(&:to_s).join(', ')})"
    end
  end
  
  def inspect
    "Term(#{@functor}, #{@args.inspect})"
  end
end