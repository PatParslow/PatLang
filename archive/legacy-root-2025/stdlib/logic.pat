# PatLang Standard Library - Logic Module
# Logic programming functions
# Implemented in PatLang with foreign primitives for database access

import "core.pat"

# Fact database access (foreign functions)
make a function called logic_assert {
  takes: pred, args
}

make a function called logic_retract {
  takes: pred, args
}

make a function called logic_query {
  takes: query_str
}

make a function called logic_rule {
  takes: head, body
}

make a function called logic_all_facts {
  takes:
}

make a function called logic_fact_count {
  takes:
}

# Unification (foreign)
make a function called logic_unify {
  takes: term1, term2
}

make a function called logic_var {
  takes: name
}

make a function called logic_term {
  takes: functor, args
}

# Variadic wrappers for convenient syntax
make a function called assert_fact {
  takes: pred
}

make a function called retract_fact {
  takes: pred
}

make a function called rule_fact {
  takes: head
}

# Fact formatter
make a function called format_fact_arg {
  takes: arg
}

# Higher-level query helpers
make a function called find_all {
  takes: pattern
}

make a function called find_one {
  takes: pattern
}

make a function called exists {
  takes: pattern
}

make a function called query_predicate {
  takes: pred
}