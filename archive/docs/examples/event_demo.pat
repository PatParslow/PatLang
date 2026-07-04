when foo {
  print(event_name + ":" + event_data)
}

emit("foo", "PAYLOAD")
