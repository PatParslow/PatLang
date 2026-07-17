make a class called Result inherits BaseObject {
  make a function called ok { takes: val }
  make a function called err { takes: error }
}

make a class called ResultCombinators1 inherits BaseObject {
  make a function called is_ok { }
  make a function called is_err { }
}

make a class called ResultCombinators2 inherits BaseObject {
  make a function called unwrap { }
  make a function called unwrap_err { }
}

make a class called ResultCombinators2 inherits BaseObject {
  make a function called map { takes: fn }
  make a function called map_err { takes: fn }
}

make a class called ResultCombinators3 inherits BaseObject {
  make a function called and_then { takes: fn }
  make a function called or_else { takes: fn }
}