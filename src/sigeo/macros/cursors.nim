

template letCur*(name, value) =
  ## creates a variable, that is a pointer, but it's name can be used as a var T.
  ## use if many derefences for such pointer is used, prefer regular pointer in simple cases
  let `name pointer` = addr(value)
  template name: var typeof(value) = `name pointer`[]

template varCur*(name, value) =
  ## creates a variable, that is a pointer, but it's name can be used as a var T.
  ## use if many derefences for such pointer is used, prefer regular pointer in simple cases
  var `name pointer` = addr(value)
  template name: var typeof(value) = `name pointer`[]


when isMainModule:
  var arr = @[1, 3, 999, 4, 0]

  var loopLen = 0
  varCur n: arr[0]
  while n != 0:
    inc loopLen
    `n pointer` = arr[n].addr

