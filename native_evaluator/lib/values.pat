make a class Value inherits BaseObject {
  make a function called initialize { takes: dat, typ }
  make a function called data { }
  make a function called type_name { }
  make a function called ref_count { }
  make a function called gc_mark { }
  make a function called source_location { }
  make a function called next { }
  make a function called is_number { }
  make a function called is_string { }
  make a function called is_list { }
  make a function called is_function { }
  make a function called is_goal { }
}

make a class ValueTypeChecks inherits BaseObject {
  make a function called is_fact { }
  make a function called is_actor { }
  make a function called is_channel { }
  make a function called is_future { }
  make a function called is_boolean { }
  make a function called is_nil { }
}

make a class ValueOps1 inherits BaseObject {
  make a function called add { takes: other }
  make a function called subtract { takes: other }
}

make a class ValueOps2 inherits BaseObject {
  make a function called multiply { takes: other }
  make a function called divide { takes: other }
}

make a class ValueOps3 inherits BaseObject {
  make a function called equals { takes: other }
  make a function called less_than { takes: other }
}

make a class NumberValue inherits Value {
  make a function called raw { }
  make a function called bitwise_and { takes: other }
  make a function called bitwise_or { takes: other }
  make a function called shift_left { takes: bits }
  make a function called shift_right { takes: bits }
}

make a class StringValue1 inherits Value {
  make a function called raw { }
  make a function called length { }
  make a function called char_at { takes: idx }
}

make a class StringValue2 inherits Value {
  make a function called concat { takes: other }
  make a function called substring { takes: start, len }
}

make a class StringValue3 inherits Value {
  make a function called split { takes: delim }
}

make a class ListValue1 inherits Value {
  make a function called head { }
  make a function called tail { }
  make a function called is_empty { }
  make a function called length { }
}

make a class ListValue2 inherits Value {
  make a function called map { takes: fn }
  make a function called filter { takes: pred }
}

make a class ListValue3 inherits Value {
  make a function called reduce { takes: init, fn }
  make a function called append { takes: val }
}

make a class FunctionValue1 inherits Value {
  make a function called name { }
  make a function called parameters { }
  make a function called body { }
  make a function called closure { }
}

make a class FunctionValue2 inherits Value {
  make a function called call { takes: args, ctx }
  make a function called curry { takes: args }
}

make a class FunctionValue3 inherits Value {
  make a function called compose { takes: other }
}

make a class GoalConstructValueObj inherits Value {
  make a function called goal_fn { takes: ctx }
  make a function called pursue_fn { takes: ctx }
}

make a class ChannelValue1 inherits Value {
  make a function called send_msg { takes: val }
  make a function called receive_fn { }
}

make a class ChannelValue2 inherits Value {
  make a function called try_receive { }
  make a function called close { }
}

make a class ActorValue1 inherits Value {
  make a function called send_msg { takes: msg }
  make a function called state { }
}

make a class ActorValue2 inherits Value {
  make a function called stop { }
}

make a class FutureValueObj1 inherits Value {
  make a function called await_fn { }
  make a function called is_ready { }
}

make a class FutureValueObj2 inherits Value {
  make a function called then_op { takes: fn }
  make a function called catch_op { takes: fn }
}