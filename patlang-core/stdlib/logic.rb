# frozen_string_literal: true

# PatLang Standard Library - Logic Module
# Provides logic programming functions

module Patlang
  module Stdlib
    module Logic
      FUNCTIONS = {}
      
      def self.register(name, arity, &block)
        FUNCTIONS[name] = { arity: arity, impl: block }
      end
      
      def self.get(name)
        FUNCTIONS[name]
      end
      
      def self.all
        FUNCTIONS.keys
      end
      
      def self.init!
        # Assert fact into database
        register("assert", -1) do |args, env|
          # args[0] = predicate name, args[1..] = arguments
          facts_db = env[:facts_db] || (env[:evaluator]&.instance_variable_get(:@facts_db))
          raise "Facts database not available" unless facts_db
          
          predicate = args[0]
          fact_args = args[1..]
          fact_string = if fact_args.empty?
            predicate.to_s
          else
            "#{predicate}(#{fact_args.map { |a| format_fact_arg(a) }.join(', ')})"
          end
          
          facts_db.assert_fact(fact_string)
          true
        end
        
        # Retract fact from database
        register("retract", -1) do |args, env|
          facts_db = env[:facts_db] || (env[:evaluator]&.instance_variable_get(:@facts_db))
          raise "Facts database not available" unless facts_db
          
          predicate = args[0]
          fact_args = args[1..]
          fact_string = if fact_args.empty?
            predicate.to_s
          else
            "#{predicate}(#{fact_args.map { |a| format_fact_arg(a) }.join(', ')})"
          end
          
          facts_db.retract_fact(fact_string)
        end
        
        # Query database
        register("query", 1) do |args, env|
          facts_db = env[:facts_db] || (env[:evaluator]&.instance_variable_get(:@facts_db))
          raise "Facts database not available" unless facts_db
          
          query_string = args[0]
          facts_db.query(query_string)
        end
        
        # Define rule
        register("rule", -1) do |args, env|
          facts_db = env[:facts_db] || (env[:evaluator]&.instance_variable_get(:@facts_db))
          raise "Facts database not available" unless facts_db
          
          # args: [head_predicate, *body_predicates]
          # This is a simplified implementation
          head = args[0]
          body = args[1..]
          
          if body.empty?
            # Just a fact
            facts_db.assert_fact(head.to_s)
          else
            # Rule: head :- body
            rule_string = "rule #{head} :- #{body.join(', ')}"
            # The facts_db doesn't have define_rule implemented yet
            # For now, just return the rule string
            rule_string
          end
        end
        
        # Get all facts
        register("all_facts", 0) do |args, env|
          facts_db = env[:facts_db] || (env[:evaluator]&.instance_variable_get(:@facts_db))
          raise "Facts database not available" unless facts_db
          
          facts_db.all_facts
        end
        
        # Get fact count
        register("fact_count", 0) do |args, env|
          facts_db = env[:facts_db] || (env[:evaluator]&.instance_variable_get(:@facts_db))
          raise "Facts database not available" unless facts_db
          
          facts_db.fact_count
        end
        
        # Unification
        register("unify", 2) do |args, env|
          engine = ::UnificationEngine.new
          term1 = args[0]
          term2 = args[1]
          subst = {}
          success = engine.unify(term1, term2, subst)
          success ? subst : nil
        end
        
        # Create variable
        register("var", 1) do |args, env|
          ::TypeVariable.new(args[0].to_s)
        end
        
        # Create compound term
        register("term", -1) do |args, env|
          functor = args[0]
          term_args = args[1..]
          ::Term.new(functor, term_args)
        end
      end
      
      def self.format_fact_arg(arg)
        case arg
        when String
          "\"#{arg}\""
        when Numeric, TrueClass, FalseClass, NilClass
          arg.inspect
        else
          arg.inspect
        end
      end
      
      init!
    end
  end
end