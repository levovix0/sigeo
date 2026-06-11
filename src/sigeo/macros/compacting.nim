

template compact*[T](arr: var seq[T], keep: untyped, body: untyped) =
  ## removes elements for which `keep` is false, inplace.
  ## the element is available as `it` inside `keep` and `body`.
  ## `body` runs for every surviving element with `oldI` and `newI` injected,
  ## so indices referencing the elements can be updated as they shift
  block:
    var newI {.inject.} = 0
    for oldI {.inject.} in 0 ..< arr.len:
      template it: untyped {.inject, used.} = arr[oldI]
      if keep:
        body
        if newI != oldI: arr[newI] = move arr[oldI]
        inc newI
    arr.setLen newI

