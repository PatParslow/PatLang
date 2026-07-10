make a class called GoalConstruct inherits BaseObject {
  make a function called initialize { takes: nm, pre, bod, post, strat }
  make a function called name { }
  make a function called precondition { }
  make a function called body { }
  make a function called postcondition { }
  make a function called strategy { }
  make a function called pursue_fn { takes: ctx }
  make a function called validate_precondition { takes: ctx }
  make a function called validate_postcondition { takes: result, ctx }
}

make a class called GoalSystem inherits BaseObject {
  make a function called declare_goal { takes: goal_construct }
  make a function called pursue { takes: goal_name, ctx }
  make a function called pursue_all { takes: goal_names, ctx }
  make a function called monitor { takes: goal_name }
}