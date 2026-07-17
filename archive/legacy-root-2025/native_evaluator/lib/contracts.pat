make a class called Contract inherits BaseObject {
  make a function called initialize { takes: pre, post, inv }
  make a function called check_pre { takes: args }
  make a function called check_post { takes: result }
  make a function called check_invariant { takes: obj }
}

make a class called ContractedFunction inherits BaseObject {
  make a function called initialize { takes: fn, contract }
  make a function called call { takes: args }
  make a function called arity { }
}