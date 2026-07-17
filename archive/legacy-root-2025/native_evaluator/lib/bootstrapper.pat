make a class called Bootstrapper inherits BaseObject {
  make a function called initialize { }
  make a function called create_evaluator { }
}

make a class called BootstrapperOps inherits BaseObject {
  make a function called load_stdlib { takes: evaluator }
  make a function called run_self_test { }
  make a function called self_host { takes: evaluator_source }
  make a function called evaluate_evaluator { takes: ctx }
}