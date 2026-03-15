import std/[macros]


macro makeInterface*(name: untyped, body: untyped) =
  nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      name,
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        newEmptyNode()
      )
    )
  )



macro implementInterfaceFor*(name: typed, implementors: varargs[typed]) =
  ##

