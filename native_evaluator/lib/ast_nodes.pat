make a class ProgramNode inherits ASTNode {
  make a function called statements { }
  make a function called evaluate { takes: ctx }
}

make a class NumberLiteralNode inherits ASTNode {
  make a function called value { }
  make a function called evaluate { takes: ctx }
}

make a class StringLiteralNode inherits ASTNode {
  make a function called value { }
  make a function called evaluate { takes: ctx }
}

make a class IdentifierNode inherits ASTNode {
  make a function called name { }
  make a function called evaluate { takes: ctx }
}

make a class BinaryOperationNode1 inherits ASTNode {
  make a function called left { }
  make a function called right { }
}

make a class BinaryOperationNode2 inherits ASTNode {
  make a function called operator { }
  make a function called evaluate { takes: ctx }
}

make a class AssignmentNode1 inherits ASTNode {
  make a function called variable { }
  make a function called value { }
}

make a class AssignmentNode2 inherits ASTNode {
  make a function called evaluate { takes: ctx }
}

make a class FunctionCallNode1 inherits ASTNode {
  make a function called callee { }
  make a function called arguments { }
}

make a class FunctionCallNode2 inherits ASTNode {
  make a function called evaluate { takes: ctx }
}

make a class FunctionDefinitionNode1 inherits ASTNode {
  make a function called name { }
  make a function called parameters { }
}

make a class FunctionDefinitionNode2 inherits ASTNode {
  make a function called body { }
  make a function called return_type { }
}

make a class FunctionDefinitionNode3 inherits ASTNode {
  make a function called evaluate { takes: ctx }
}

make a class GoalNode1 inherits ASTNode {
  make a function called precondition { }
  make a function called body { }
}

make a class GoalNode2 inherits ASTNode {
  make a function called postcondition { }
  make a function called strategy { }
}

make a class GoalNode3 inherits ASTNode {
  make a function called evaluate { takes: ctx }
}

make a class FactNode1 inherits ASTNode {
  make a function called predicate { }
  make a function called arguments { }
}

make a class FactNode2 inherits ASTNode {
  make a function called evaluate { takes: ctx }
}

make a class RuleNode1 inherits ASTNode {
  make a function called head { }
  make a function called body { }
}

make a class RuleNode2 inherits ASTNode {
  make a function called evaluate { takes: ctx }
}