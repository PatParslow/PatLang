make a class called FactDatabase inherits BaseObject {
  make a function called assert_fact { takes: predicate, arguments }
  make a function called retract { takes: predicate, arguments }
}

make a class called FactDatabaseQuery inherits BaseObject {
  make a function called query_fn { takes: query_string }
  make a function called all_facts { }
}

make a class called LogicQuery inherits BaseObject {
  make a function called initialize { takes: pat }
  make a function called execute { takes: db }
}

make a class called LogicQueryAsync inherits BaseObject {
  make a function called execute_async { takes: db }
}