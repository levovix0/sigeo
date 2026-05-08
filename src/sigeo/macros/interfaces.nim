import std/[macros, hashes]


## Interfaces are unowned fat pointers to arbitrary object. Basicaly an (obj: pointer, vtable: ptr VtableType).
## Inheritance is not supported, there is one vtable for any type that implements an interface.
## A type may implement many interfaces at once. There is no given wat to cast diffirent interfaces into each other.
## If you need to retrieve a type from an interface, you can check the .vtable.typenameHash.
## To cast `x` interface back to a known type, first check the x.vtable.typenameHash == hash"MyKnownType", then cast[ptr MyKnownType](x.obj).
##
## If you created an interface, make sure the lifetime of the interface is less then the lifetime of an actual object.
## You can use OwnedXXX (where XXX is the name of the interface) to store arbitrary objects of that interface type.
## OwnedXXX behaves like regular Nim object with copying and move semantics, but it is allocated on the heap.
## Use toOwnedXXX to create an OwnedXXX by moving (or copying) a known type object into it


type
  MethodSig = object
    name: string
    nonThisParams: seq[NimNode]  # IdentDefs with original types (no pointer substitution)
    retType: NimNode


proc publicField(name: string, typ: NimNode): NimNode =
  nnkIdentDefs.newTree(
    nnkPostfix.newTree(ident"*", ident(name)),
    typ,
    newEmptyNode()
  )


proc procTy(params: seq[NimNode], retType: NimNode, raisesNone: bool): NimNode =
  var formalParams = @[retType]
  formalParams.add(params)
  var pragma = nnkPragma.newTree(ident"nimcall")
  if raisesNone:
    pragma.add nnkExprColonExpr.newTree(ident"raises", nnkBracket.newTree())
  nnkProcTy.newTree(nnkFormalParams.newTree(formalParams), pragma)


macro makeInterface*(name: untyped, body: untyped) =
  let nameStr = name.strVal
  let vtableName = ident("Vtable" & nameStr)

  proc lifecycleProc(fname: string, params: seq[NimNode]): NimNode =
    publicField(fname, procTy(params, newEmptyNode(), raisesNone=true))

  var vtableFields = nnkRecList.newTree()
  vtableFields.add publicField("typenameHash", bindSym"Hash")

  vtableFields.add lifecycleProc("destroy", @[
    newIdentDefs(ident("this"), bindSym("pointer"))
  ])
  vtableFields.add lifecycleProc("trace", @[
    newIdentDefs(ident("this"), bindSym("pointer")),
    newIdentDefs(ident"env", bindSym("pointer"))
  ])
  # dup/sink: this=source (ptr), other=dest (var ptr)
  vtableFields.add lifecycleProc("dup", @[
    newIdentDefs(ident("this"), bindSym("pointer")),
    newIdentDefs(ident"other", nnkVarTy.newTree(bindSym("pointer")))
  ])
  vtableFields.add lifecycleProc("sink", @[
    newIdentDefs(ident("this"), bindSym("pointer")),
    newIdentDefs(ident"other", nnkVarTy.newTree(bindSym("pointer")))
  ])

  # Collect methods while building vtable fields
  var methods: seq[MethodSig]

  for stmt in body:
    if stmt.kind == nnkProcDef:
      let methodName = $stmt[0]
      let formalParams = stmt[3]
      let retType = formalParams[0]

      var vtableParams: seq[NimNode]
      var nonThisParams: seq[NimNode]
      for i in 1 ..< formalParams.len:
        let p = formalParams[i]
        if p[1].kind == nnkEmpty:
          vtableParams.add(nnkIdentDefs.newTree(p[0], ident"pointer", newEmptyNode()))
        else:
          vtableParams.add(nnkIdentDefs.newTree(p[0], p[1], newEmptyNode()))
          nonThisParams.add(nnkIdentDefs.newTree(p[0], p[1], newEmptyNode()))

      vtableFields.add(publicField(methodName, procTy(vtableParams, retType, false)))
      methods.add(MethodSig(name: methodName, nonThisParams: nonThisParams, retType: retType))

  # Xxx / OwnedXxx share the same shape
  proc wrapperType(typName: NimNode): NimNode =
    nnkTypeDef.newTree(
      nnkPostfix.newTree(ident"*", typName),
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        nnkRecList.newTree(
          publicField("vtable", nnkPtrTy.newTree(ident("Vtable" & nameStr))),
          publicField("obj", ident"pointer")
        )
      )
    )

  let typeSection = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      nnkPostfix.newTree(ident"*", vtableName),
      newEmptyNode(),
      nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), vtableFields)
    ),
    wrapperType(name),
    wrapperType(ident("Owned" & nameStr))
  )

  # --- Proc generation ---

  let ownedName = ident("Owned" & nameStr)

  proc mkProc(procName: NimNode, params: seq[NimNode], body: NimNode): NimNode =
    nnkProcDef.newTree(
      procName, newEmptyNode(), newEmptyNode(),
      nnkFormalParams.newTree(params),
      nnkPragma.newTree(ident"inline"), newEmptyNode(), body
    )

  proc mkConverter(convName: NimNode, params: seq[NimNode], body: NimNode): NimNode =
    nnkConverterDef.newTree(
      convName, newEmptyNode(), newEmptyNode(),
      nnkFormalParams.newTree(params),
      newEmptyNode(), newEmptyNode(), body
    )

  proc dot(obj, field: string): NimNode = nnkDotExpr.newTree(ident(obj), ident(field))

  proc callThrough(obj, methodName: string, args: seq[NimNode]): NimNode =
    result = nnkCall.newTree(
      nnkDotExpr.newTree(nnkDotExpr.newTree(ident(obj), ident"vtable"), ident(methodName))
    )
    for a in args: result.add(a)

  result = nnkStmtList.newTree(typeSection)

  # Method forwarders on the base (Xxx) type
  for m in methods:
    var fparams: seq[NimNode] = @[m.retType, newIdentDefs(ident"this", name)]
    var callArgs: seq[NimNode] = @[dot("this", "obj")]
    for p in m.nonThisParams:
      fparams.add(nnkIdentDefs.newTree(p[0], p[1], newEmptyNode()))
      callArgs.add(p[0])
    result.add mkProc(
      nnkPostfix.newTree(ident"*", ident(m.name)),
      fparams,
      newStmtList(callThrough("this", m.name, callArgs))
    )

  # OwnedXxx lifecycle hooks
  result.add mkProc(
    nnkAccQuoted.newTree(ident"=destroy"),
    @[newEmptyNode(), newIdentDefs(ident"this", ownedName)],
    newStmtList(callThrough("this", "destroy", @[dot("this", "obj")]))
  )
  result.add mkProc(
    nnkAccQuoted.newTree(ident"=trace"),
    @[newEmptyNode(), newIdentDefs(ident"this", nnkVarTy.newTree(ownedName)),
      newIdentDefs(ident"env", ident"pointer")],
    newStmtList(callThrough("this", "trace", @[dot("this", "obj"), ident"env"]))
  )
  # =copy: destroy this, then dup from other (source) into this (dest)
  result.add mkProc(
    nnkAccQuoted.newTree(ident"=copy"),
    @[newEmptyNode(), newIdentDefs(ident"this", nnkVarTy.newTree(ownedName)),
      newIdentDefs(ident"other", ownedName)],
    newStmtList(
      callThrough("this", "destroy", @[dot("this", "obj")]),
      callThrough("other", "dup", @[dot("other", "obj"), dot("this", "obj")]),
      nnkAsgn.newTree(dot("this", "vtable"), dot("other", "vtable"))
    )
  )
  # =dup: set vtable, then dup from this (source) into result (dest)
  result.add mkProc(
    nnkAccQuoted.newTree(ident"=dup"),
    @[ownedName, newIdentDefs(ident"this", ownedName)],
    newStmtList(
      nnkAsgn.newTree(dot("result", "vtable"), dot("this", "vtable")),
      callThrough("this", "dup", @[dot("this", "obj"), dot("result", "obj")])
    )
  )
  # =sink: destroy this, move from other (source) into this (dest), update vtable
  result.add mkProc(
    nnkAccQuoted.newTree(ident"=sink"),
    @[newEmptyNode(), newIdentDefs(ident"this", nnkVarTy.newTree(ownedName)),
      newIdentDefs(ident"other", ownedName)],
    newStmtList(
      callThrough("this", "destroy", @[dot("this", "obj")]),
      callThrough("other", "sink", @[dot("other", "obj"), dot("this", "obj")]),
      nnkAsgn.newTree(dot("this", "vtable"), dot("other", "vtable"))
    )
  )

  # Converter: OwnedXxx -> Xxx
  result.add mkConverter(
    nnkPostfix.newTree(ident"*", ident"asPtr"),
    @[name, newIdentDefs(ident"this", ownedName)],
    newStmtList(nnkCast.newTree(name, ident"this"))
  )


macro implementInterfaceFor*(name: typed, implementors: varargs[typed]) =
  let nameStr = name.strVal
  # Navigate to VtableXxx via the wrapper type's vtable field:
  # getImpl(Xxx) -> TypeDef[2]=ObjectTy[2]=RecList, field[0]=vtable IdentDefs
  # vtable type = PtrTy[VtableXxx], so [1][0] gives the VtableXxx sym
  let wrapperImpl = name.getImpl
  let vtableTypeSym = wrapperImpl[2][2][0][1][0]  # ptr VtableXxx -> VtableXxx sym
  let vtableImpl = vtableTypeSym.getImpl
  # TypeDef[2] = ObjectTy, ObjectTy[2] = RecList
  let recList = vtableImpl[2][2]

  const lifecycleNames = ["typenameHash", "destroy", "trace", "dup", "sink"]

  # Extract interface method signatures from the vtable RecList
  var methods: seq[MethodSig]
  for fieldDef in recList:
    let nameNode = fieldDef[0]
    let fname = (if nameNode.kind == nnkPostfix: nameNode[1] else: nameNode).strVal
    if fname in lifecycleNames: continue

    let procType = fieldDef[1]
    let formalParams = procType[0]
    let retType = formalParams[0]

    var nonThisParams: seq[NimNode]
    for i in 1 ..< formalParams.len:
      let p = formalParams[i]
      if p[0].strVal != "this":
        nonThisParams.add(nnkIdentDefs.newTree(p[0], p[1], newEmptyNode()))

    methods.add(MethodSig(name: fname, nonThisParams: nonThisParams, retType: retType))

  result = nnkStmtList.newTree()

  let raisesNone = nnkPragma.newTree(ident"nimcall",
    nnkExprColonExpr.newTree(ident"raises", nnkBracket.newTree()))
  let nimcall = nnkPragma.newTree(ident"nimcall")

  proc mkLambda(fParams: seq[NimNode], retType: NimNode, pragma: NimNode,
                body: NimNode): NimNode =
    nnkLambda.newTree(
      newEmptyNode(), newEmptyNode(), newEmptyNode(),
      nnkFormalParams.newTree(@[retType] & fParams),
      pragma, newEmptyNode(), body
    )

  for impl in implementors:
    let implStr = impl.strVal
    let vtableConstName = ident("vtable_" & implStr & "_" & nameStr)

    proc ptrImpl(): NimNode = nnkPtrTy.newTree(impl.copy)
    proc derefCast(x: NimNode): NimNode =
      nnkDerefExpr.newTree(nnkCast.newTree(ptrImpl(), x))

    var objConstr = nnkObjConstr.newTree(ident("Vtable" & nameStr))

    objConstr.add nnkExprColonExpr.newTree(
      ident"typenameHash",
      newCall(bindSym("hash"), newLit(implStr))
    )

    objConstr.add nnkExprColonExpr.newTree(ident"destroy",
      mkLambda(
        @[newIdentDefs(ident"this", ident"pointer")],
        newEmptyNode(), raisesNone.copy,
        newStmtList(newCall(nnkAccQuoted.newTree(ident"=destroy"), derefCast(ident"this")))
      )
    )

    objConstr.add nnkExprColonExpr.newTree(ident"trace",
      mkLambda(
        @[newIdentDefs(ident"this", ident"pointer"),
          newIdentDefs(ident"env", ident"pointer")],
        newEmptyNode(), raisesNone.copy,
        newStmtList(newCall(nnkAccQuoted.newTree(ident"=trace"),
          derefCast(ident"this"), ident"env"))
      )
    )

    # dup: this=source, other=dest — allocate and copy
    objConstr.add nnkExprColonExpr.newTree(ident"dup",
      mkLambda(
        @[newIdentDefs(ident"this", ident"pointer"),
          newIdentDefs(ident"other", nnkVarTy.newTree(ident"pointer"))],
        newEmptyNode(), raisesNone.copy,
        newStmtList(
          nnkAsgn.newTree(ident"other",
            newCall(ident"alloc0", newCall(ident"sizeof", impl.copy))),
          nnkAsgn.newTree(derefCast(ident"other"), derefCast(ident"this"))
        )
      )
    )

    # sink: this=source, other=dest — allocate and move
    objConstr.add nnkExprColonExpr.newTree(ident"sink",
      mkLambda(
        @[newIdentDefs(ident"this", ident"pointer"),
          newIdentDefs(ident"other", nnkVarTy.newTree(ident"pointer"))],
        newEmptyNode(), raisesNone.copy,
        newStmtList(
          nnkAsgn.newTree(ident"other",
            newCall(ident"alloc0", newCall(ident"sizeof", impl.copy))),
          nnkAsgn.newTree(derefCast(ident"other"),
            newCall(ident"move", derefCast(ident"this")))
        )
      )
    )

    # Interface methods: delegate to the implementor's method
    for m in methods:
      var lambdaParams: seq[NimNode] = @[newIdentDefs(ident"this", ident"pointer")]
      var callArgs: seq[NimNode]
      for p in m.nonThisParams:
        # p[0] is a sym from getImpl — use a fresh ident so it's the lambda's own param
        let pname = ident(p[0].strVal)
        lambdaParams.add(nnkIdentDefs.newTree(pname, p[1], newEmptyNode()))
        callArgs.add(pname)

      var methodExpr: NimNode
      let access = nnkDotExpr.newTree(derefCast(ident"this"), ident(m.name))
      if callArgs.len == 0:
        methodExpr = access
      else:
        methodExpr = nnkCall.newTree(access)
        for a in callArgs: methodExpr.add(a)

      objConstr.add nnkExprColonExpr.newTree(ident(m.name),
        mkLambda(lambdaParams, m.retType, nimcall.copy, newStmtList(methodExpr))
      )

    result.add nnkConstSection.newTree(
      nnkConstDef.newTree(
        nnkPostfix.newTree(ident"*", vtableConstName),
        newEmptyNode(),
        objConstr
      )
    )

    # converter toXxx*(this: Impl): Xxx — unowned borrow
    result.add nnkConverterDef.newTree(
      nnkPostfix.newTree(ident"*", ident("to" & nameStr)),
      newEmptyNode(), newEmptyNode(),
      nnkFormalParams.newTree(
        ident(nameStr),
        newIdentDefs(ident"this", impl.copy)
      ),
      nnkPragma.newTree(ident"inline"),
      newEmptyNode(),
      newStmtList(nnkObjConstr.newTree(
        ident(nameStr),
        nnkExprColonExpr.newTree(ident"vtable",
          nnkAddr.newTree(ident("vtable_" & implStr & "_" & nameStr))),
        nnkExprColonExpr.newTree(ident"obj",
          nnkAddr.newTree(ident"this"))
      ))
    )

    # proc toOwnedXxx*(this: sink Impl): OwnedXxx — moves impl onto the heap
    result.add nnkProcDef.newTree(
      nnkPostfix.newTree(ident"*", ident("toOwned" & nameStr)),
      newEmptyNode(), newEmptyNode(),
      nnkFormalParams.newTree(
        ident("Owned" & nameStr),
        newIdentDefs(ident"this", newCall(ident("sink"), impl.copy))
      ),
      nnkPragma.newTree(ident"inline"),
      newEmptyNode(),
      newStmtList(
        nnkAsgn.newTree(
          nnkDotExpr.newTree(ident"result", ident"vtable"),
          nnkAddr.newTree(ident("vtable_" & implStr & "_" & nameStr))
        ),
        nnkAsgn.newTree(
          nnkDotExpr.newTree(ident"result", ident"obj"),
          newCall(ident"alloc0", newCall(ident"sizeof", impl.copy))
        ),
        nnkAsgn.newTree(
          nnkDerefExpr.newTree(nnkCast.newTree(
            nnkPtrTy.newTree(impl.copy),
            nnkDotExpr.newTree(ident"result", ident"obj")
          )),
          ident"this"
        )
      )
    )
