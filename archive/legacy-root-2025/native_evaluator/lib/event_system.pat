make a class called Event inherits BaseObject {
  make a function called initialize { takes: typ, payload, ts, src }
  make a function called type_name { }
  make a function called payload { }
  make a function called timestamp { }
  make a function called source { }
  make a function called to_json { }
}

make a class called EventBus inherits BaseObject {
  make a function called subscribe { takes: event_type, handler }
  make a function called publish { takes: event }
  make a function called publish_async { takes: event }
}