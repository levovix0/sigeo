import macros

proc formalArgs_names(n: NimNode): seq[NimNode] =
  n.expectKind nnkFormalParams
  for i, x in n:
    if i == 0: continue
    result.add x[0..^3]


macro aliases*(names: untyped, fdef: untyped): untyped =
  #[runnableExamples:
    proc lenOnAxis*(v: Vec3, axis: NormalVec3): Float {.aliases: [dot, lenAtAxis].} =
      ## ...
    
    # will generate
    #[
      template dot*(v: Vec3, axis: NormalVec3): Float =
        v.lenOnAxis(axis)
      
      template lenAtAxis*(v: Vec3, axis: NormalVec3): Float =
        v.lenOnAxis(axis)
    ]#
  ]#
  
  result = newStmtList()

  var fdef = fdef
  if fdef.kind == nnkStmtList:
    if fdef.len != 1: error("unexpected syntax, expected single proc definition")
    else: fdef = fdef[0]
  
  result.add fdef

  let ftyp =
    when not defined(release): nnkProcDef  # use proc to not mess up with line info in stacktraces
    else: nnkTemplateDef

  let pragmas =
    when not defined(release): nnkPragma.newTree(newIdentNode("inline"))
    else: newEmptyNode()

  for alias in names:
    result.add ftyp.newTree(
      (
        if fdef[0].kind == nnkPostfix:
          nnkPostfix.newTree(
            newIdentNode("*"),
            alias
          )
        else:
          alias
      ),
      fdef[1],
      fdef[2],
      fdef[3],
      pragmas,
      fdef[5],
      nnkCall.newTree(@[fdef.name] & fdef[3].formalArgs_names)
    )
    result[^1][0].copyLineInfo(fdef[0])

