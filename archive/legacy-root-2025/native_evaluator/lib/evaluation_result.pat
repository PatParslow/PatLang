make a class called EvaluationResult inherits BaseObject {
  make a function called initialize { takes: val, typ, success_flag, err, effects, eval_time, mem }
  make a function called value { }
}

make a class called EvaluationResultAccessors inherits BaseObject {
  make a function called type { }
  make a function called success { }
}

make a class called EvaluationResultError inherits BaseObject {
  make a function called error { }
  make a function called side_effects { }
}

make a class called EvaluationResultMeta inherits BaseObject {
  make a function called evaluation_time { }
  make a function called memory_allocated { }
}

make a class called EvaluationResultCombinators1 inherits BaseObject {
  make a function called map { takes: fn }
  make a function called flat_map { takes: fn }
}

make a class called EvaluationResultCombinators2 inherits BaseObject {
  make a function called chain { takes: other }
  make a function called or_else { takes: fallback }
}