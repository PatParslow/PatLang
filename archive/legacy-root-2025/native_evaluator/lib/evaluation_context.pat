make a class called EvaluationContext inherits BaseObject {
  make a function called initialize { takes: mem_mgr }
  make a function called scope_stack { }
  make a function called value_stack { }
  make a function called call_stack { }
  make a function called recursion_depth { }
  make a function called max_recursion_depth { }
  make a function called memory_manager { }
  make a function called type_checker { }
  make a function called native_bridge { }
  make a function called error_handler { }
  make a function called event_bus { }
  make a function called emit { takes: event_type, payload }
  make a function called check_recursion { }
  make a function called push_frame { takes: frame }
  make a function called pop_frame { }
  make a function called push_scope { }
  make a function called pop_scope { }
}