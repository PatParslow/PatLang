make a class called NativeBridge inherits BaseObject {
  make a function called initialize { }
  make a function called send_msg { takes: operation, arguments }
  make a function called allocate { takes: size }
  make a function called deallocate { takes: ptr }
  make a function called gc_collect { }
  make a function called channel_create { takes: size }
  make a function called channel_send { takes: chan, val }
  make a function called channel_receive { takes: chan }
  make a function called channel_select { takes: cases }
  make a function called actor_create { takes: beh, st }
  make a function called actor_send { takes: act, msg }
  make a function called async_spawn { takes: fn }
  make a function called await_fn { takes: future }
  make a function called mutex_create { }
  make a function called mutex_lock { takes: mtx }
  make a function called mutex_unlock { takes: mtx }
  make a function called type_check { takes: val, typ }
  make a function called unify { takes: t1, t2 }
}