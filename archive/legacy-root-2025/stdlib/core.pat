# PatLang Standard Library - Core Module (Pure Object Model)
# Everything is an object. Primitives are classes with methods.
# Foreign methods (implemented in C runtime) declared with takes: types
# Note: Method/class names that are reserved keywords renamed with _op suffix
# Note: Parent class names that are keywords renamed to BaseX to avoid lexer issues

# ============================================================================
# BASE CLASS HIERARCHY
# ============================================================================

# Root of all objects
make a class called BaseObject {
  make a function called equals { takes: other }
  make a function called to_string { }
  make a function called class_of { }
  make a function called identity { }
}

# Class object (meta-object protocol) - class is keyword, use ClassType
make a class called ClassType inherits BaseObject {
  make a function called name { }
  make a function called superclass { }
  make a function called new { takes: args }
}

# ============================================================================
# BOOLEAN
# ============================================================================

make a class called BooleanType inherits BaseObject {
  make a function called equals { takes: other }
  make a function called not_op { }
  make a function called and_op { takes: other }
  make a function called or_op { takes: other }
  make a function called xor { takes: other }
  make a function called if_true { takes: then_block, else_block }
  make a function called if_false { takes: then_block, else_block }
  make a function called to_string { }
  make a function called true_value { }
  make a function called false_value { }
}

# ============================================================================
# NIL
# ============================================================================

make a class called NilType inherits BaseObject {
  make a function called equals { takes: other }
  make a function called to_string { }
  make a function called is_nil { }
  make a function called default_to { takes: value }
  make a function called nil_value { }
}

# ============================================================================
# NUMBER (abstract)
# ============================================================================

make a class called BaseNumber inherits BaseObject {
  make a function called equals { takes: other }
  make a function called less_than { takes: other }
  make a function called greater_than { takes: other }
  make a function called less_equal { takes: other }
  make a function called greater_equal { takes: other }
  make a function called add { takes: other }
  make a function called subtract { takes: other }
  make a function called multiply { takes: other }
  make a function called divide { takes: other }
  make a function called modulo { takes: other }
  make a function called power { takes: other }
  make a function called abs { }
  make a function called negate { }
  make a function called to_integer { }
  make a function called to_float { }
  make a function called to_string { }
}

# ============================================================================
# INTEGER
# ============================================================================

make a class called Integer inherits BaseNumber {
  make a function called bitwise_and { takes: other }
  make a function called bitwise_or { takes: other }
  make a function called bitwise_xor { takes: other }
  make a function called bitwise_not { }
  make a function called shift_left { takes: bits }
  make a function called shift_right { takes: bits }
  make a function called is_even { }
  make a function called is_odd { }
  make a function called factorial { }
  make a function called gcd { takes: other }
  make a function called lcm { takes: other }
  make a function called to_string { takes: base? }
}

# ============================================================================
# FLOAT
# ============================================================================

make a class called Float inherits BaseNumber {
  make a function called sqrt { }
  make a function called floor { }
  make a function called ceil { }
  make a function called round { }
  make a function called sin { }
  make a function called cos { }
  make a function called tan { }
  make a function called log { takes: base? }
  make a function called exp { }
  make a function called to_string { takes: precision? }
}

# ============================================================================
# STRING
# ============================================================================

make a class called String inherits BaseObject {
  make a function called length { }
  make a function called is_empty { }
  make a function called equals { takes: other }
  make a function called concat { takes: other }
  make a function called substring { takes: start, length }
  make a function called char_at { takes: index }
  make a function called split { takes: delimiter }
  make a function called join { takes: items }
  make a function called uppercase { }
  make a function called lowercase { }
  make a function called trim { }
  make a function called starts_with { takes: prefix }
  make a function called ends_with { takes: suffix }
  make a function called contains { takes: substr }
  make a function called index_of { takes: substr }
  make a function called replace { takes: old, new }
  make a function called matches { takes: pattern }
}

# ============================================================================
# LIST
# ============================================================================

make a class called BaseList inherits BaseObject {
  make a function called length { }
  make a function called is_empty { }
  make a function called get { takes: index }
  make a function called set { takes: index, value }
  make a function called first { }
  make a function called last { }
  make a function called append { takes: value }
  make a function called prepend { takes: value }
  make a function called concat { takes: other }
  make a function called insert { takes: index, value }
  make a function called remove_at { takes: index }
  make a function called pop { }
  make a function called reverse { }
  make a function called map { takes: fn }
  make a function called filter { takes: pred }
  make a function called reduce { takes: init, fn }
  make a function called reduce1 { takes: fn }
  make a function called find { takes: pred }
  make a function called find_index { takes: pred }
  make a function called any { takes: pred }
  make a function called all { takes: pred }
  make a function called none { takes: pred }
  make a function called count { takes: pred_or_val }
  make a function called sort { }
  make a function called sort_by { takes: key_fn }
  make a function called slice { takes: start, finish }
  make a function called take { takes: n }
  make a function called drop { takes: n }
  make a function called flatten { }
  make a function called uniq { }
  make a function called zip { takes: lists }
  make a function called group_by { takes: key_fn }
  make a function called partition { takes: pred }
  make a function called chunk { takes: size }
  make a function called join { takes: delimiter }
  make a function called each { takes: fn }
  make a function called to_string { }
}

# ============================================================================
# OBJECT (Dictionary/Map) - renamed to ObjectDict to avoid conflict
# ============================================================================

make a class called ObjectDict inherits BaseObject {
  make a function called length { }
  make a function called is_empty { }
  make a function called get { takes: key }
  make a function called set { takes: key, value }
  make a function called has_key { takes: key }
  make a function called remove { takes: key }
  make a function called keys { }
  make a function called values { }
  make a function called merge { takes: other }
  make a function called each { takes: fn }
  make a function called map_values { takes: fn }
  make a function called filter_keys { takes: pred }
  make a function called to_string { }
}

# ============================================================================
# FUNCTION
# ============================================================================

make a class called BaseFunction inherits BaseObject {
  make a function called call { takes: args }
  make a function called arity { }
  make a function called parameters { }
  make a function called curry { takes: args }
  make a function called compose { takes: other }
  make a function called to_string { }
}

# ============================================================================
# CHANNEL
# ============================================================================

make a class called BaseChannel inherits BaseObject {
  make a function called send { takes: value }
  make a function called receive_op { }
  make a function called try_receive { }
  make a function called close { }
  make a function called is_closed { }
  make a function called size { }
}

# ============================================================================
# MUTEX
# ============================================================================

make a class called BaseMutex inherits BaseObject {
  make a function called lock_op { }
  make a function called unlock_op { }
  make a function called try_lock { }
  make a function called synchronize { takes: block }
}

# ============================================================================
# ACTOR
# ============================================================================

make a class called ActorType inherits BaseObject {
  make a function called send { takes: message }
  make a function called state { }
  make a function called stop { }
  make a function called is_running { }
}

# ============================================================================
# FUTURE / PROMISE
# ============================================================================

make a class called Future inherits BaseObject {
  make a function called await_op { }
  make a function called is_ready { }
  make a function called value { }
  make a function called then_op { takes: fn }
  make a function called catch_op { takes: fn }
}

# ============================================================================
# SELECT (for channel operations)
# ============================================================================

make a class called SelectCase inherits BaseObject {
  make a function called channel_of { }
  make a function called pattern { }
  make a function called body { }
}

make a class called BaseSelect inherits BaseObject {
  make a function called add_case { takes: ch, pattern, body }
  make a function called execute { }
}

# ============================================================================
# EXCEPTION / ERROR
# ============================================================================

make a class called Exception inherits BaseObject {
  make a function called message { }
  make a function called stack_trace { }
  make a function called raise_op { }
}

# ============================================================================
# GLOBAL CONSTRUCTORS / FACTORIES (in Core module)
# ============================================================================

make a class called Core inherits BaseObject {
  make a function called nil_op { }
  make a function called true_op { }
  make a function called false_op { }
  make a function called integer { takes: value }
  make a function called integer_from_string { takes: s, base? }
  make a function called float { takes: value }
  make a function called float_from_string { takes: s }
  make a function called string { takes: value }
  make a function called list_op { takes: items }
  make a function called list_of { takes: count, fn }
  make a function called range_op { takes: start, finish, step? }
  make a function called object { takes: pairs }
  make a function called channel_op { takes: size? }
  make a function called mutex_op { }
  make a function called actor_op { takes: behavior, initial_state }
  make a function called async_op { takes: fn }
  make a function called await_op { takes: future }
  make a function called select_op { takes: cases }
  make a function called goal_system { }
  make a function called print { takes: value }
  make a function called println { takes: value }
  make a function called error_op { takes: message }
}

# Access to the global Core instance
make a function called core { }