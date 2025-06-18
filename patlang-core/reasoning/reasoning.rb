# Main Reasoning Module for PATLANG
# Provides unified access to all reasoning components

require_relative 'type_constraint_system'
require_relative 'type_constraint'
require_relative 'reasoning_coordinator'

module Reasoning
  def self.create_constraint_system
    TypeConstraintSystem.new
  end
  
  def self.create_coordinator
    ReasoningCoordinator.new
  end
end
