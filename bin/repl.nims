import typetraits
template on_ce(state: void): void = discard
template on_ce[T: not void](arg: T): void =
    echo arg
template on_ce(args: varargs[untyped]): void =
    echo args
template on_ce[T: type](arg: T): void =
    echo arg
proc hoge(x:int):string=
  return $x

