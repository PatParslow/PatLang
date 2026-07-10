make a class called Evaluator inherits BaseObject {
  make a function called initialize { takes: cfg }
  make a function called context { }
  make a function called config { }
  make a function called native_bridge { }
  make a function called evaluate { takes: node, ctx }
  make a function called dispatch { takes: node, ctx }
  make a function called evaluate_program { takes: node, ctx }
  make a function called evaluate_number_literal { takes: node, ctx }
  make a function called evaluate_string_literal { takes: node, ctx }
  make a function called evaluate_binary_op { takes: node, ctx }
  make a function called evaluate_assignment { takes: node, ctx }
  make a function called evaluate_function_call { takes: node, ctx }
  make a function called evaluate_function_def { takes: node, ctx }
  make a function called evaluate_goal { takes: node, ctx }
  make a function called evaluate_fact { takes: node, ctx }
  make a function called evaluate_rule { takes: node, ctx }
  make a function called evaluate_identifier { takes: node, ctx }
  make a function called evaluate_async { takes: body, ctx }
  make a function called evaluate_await { takes: future, ctx }
  make a function called call_native { takes: operation, arguments, ctx }
}