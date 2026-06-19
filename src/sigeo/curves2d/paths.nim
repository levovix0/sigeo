import ../[core]
import ../macros/[interfaces, cursors, genAliases]
import ./[icurve2, lineSection, circleArc]

when sigeo_backend == SigeoOpencascade:
  import ./[ellipseArc]
  import pkg/opencascade except sin, cos, min, max, floor

when sigeo_backend == SigeoC3d:
  import pkg/c3d, pkg/c3d/bindings


type
  Path2_BuildPoint_Kind = enum
    StartPoint
    BevelPoint
    FilletPoint

  Path2_BuildPoint = object
    ## helper "Curve2" type for temporary use for Path2 building
    pos: Point2
    kind: Path2_BuildPoint_Kind
    radius: Float
  
  Path2_X = distinct ptr Path2
  Path2_Y = distinct ptr Path2


  Path2* = object
    ## continuous sequence of curves
    curves*: seq[OwnedCurve2]
    reversed*: Bitmask  # todo: remove, use cut instead



Curve2.implementInterfaceFor(Path2, fwd = Declare)


proc length*(this: Path2): float =
  result = 0
  for x in this.curves:
    result += x.length


proc `[]`*(this: Path2, i: int|BackwardsIndex): Curve2 {.inline.} =
  this.curves.view[i]  # todo: without `.view` it tries to copy OwnedCurve


proc pointAtCurve*(this: Path2, curve: int|BackwardsIndex, param: FloatParam): Point2 {.inline.} =
  if this.reversed[curve]:
    this[curve].pointAtParam(1 - param)
  else:
    this[curve].pointAtParam(param)


proc pointAtParam*(this: Path2; param: FloatParam): Point2 =
  assert this.curves.len != 0, "empty contour"
  if classify(param) != fcNormal: return this.pointAtCurve(0, 0)
  if param <= 0: return this.pointAtCurve(0, 0)
  if param >= 1: return this.pointAtCurve(^1, 1)
  let t = param.Float * this.curves.len.Float
  this.pointAtCurve(t.int, t mod 1)


proc isContinuous*(c: Path2): bool =
  if c.curves.len <= 1: return true
  for i in 0 ..< c.curves.len-1:
    let prev = c.pointAtCurve(i, 1)
    let next = c.pointAtCurve(i + 1, 0)
    if prev ~!= next: return false
  true

proc isClosed*(c: Path2): bool =
  return c.pointAtParam(0) ~== c.pointAtParam(1)


proc derAtCurve*(this: Path2, curve: int|BackwardsIndex, param: FloatParam): V2 {.inline.} =
  if this.reversed[curve]:
    -this[curve].derAtParam(1 - param)
  else:
    this[curve].derAtParam(param)


proc derAtParam*(this: Path2; param: FloatParam): V2 =
  ## derivative of `pointAtParam` with respect to the contour param
  assert this.curves.len != 0, "empty contour"
  let n = this.curves.len.Float
  if classify(param) != fcNormal: return this.derAtCurve(0, 0) * n
  if param <= 0: return this.derAtCurve(0, 0) * n
  if param >= 1: return this.derAtCurve(^1, 1) * n
  let t = param.Float * n
  this.derAtCurve(t.int, t mod 1) * n


proc approxSignedArea*(this: Path2, samplesPerCurve = 32): Float =
  ## approximate signed area enclosed by the contour, computed from a polyline approximation.
  ## positive if the contour is counterclockwise in coordinate space
  for i in 0..<this.curves.len:
    var prev = this.pointAtCurve(i, 0)
    for j in 1..samplesPerCurve:
      let p = this.pointAtCurve(i, FloatParam(j / samplesPerCurve))
      result += prev.x * p.y - p.x * prev.y
      prev = p
  result /= 2


proc bounds*(this: Path2, a, b: FloatParam): Bounds2 =
  ## bounding box of the part of the contour between params `a` and `b`
  assert this.curves.len != 0, "empty contour"
  let n = this.curves.len
  let ta = a.Float * n.Float
  let tb = b.Float * n.Float
  let i0 = clamp(int(floor(ta)), 0, n - 1)
  let i1 = clamp(int(ceil(tb)) - 1, i0, n - 1)

  result = bounds2(this.pointAtCurve(i0, clamp(ta - i0.Float, 0, 1)))
  for i in i0..i1:
    var la = clamp(ta - i.Float, 0, 1)
    var lb = clamp(tb - i.Float, 0, 1)
    if this.reversed[i]:
      (la, lb) = (1 - lb, 1 - la)
    result.add this[i].bounds(la.FloatParam, lb.FloatParam)


proc cut*(this: Path2, a, b: FloatParam): OwnedCurve2 =
  if this.curves.len == 0: return

  let n = this.curves.len
  let ta = a.Float.clamp(0, 1) * n.Float
  let tb = b.Float.clamp(0, 1) * n.Float

  proc localParam(this: Path2, curve: int, t: Float): FloatParam =
    let lp = (t - curve.Float).clamp(0, 1)
    if this.reversed[curve]: (1 - lp).FloatParam else: lp.FloatParam

  let ia = clamp(int(ta), 0, n - 1)
  let ib = clamp(int(tb), 0, n - 1)

  if ia == ib:
    return this[ia].cut(this.localParam(ia, ta), this.localParam(ib, tb))
  elif ta < tb:
    var res: Path2
    for i in countup(ia, ib):
      res.curves.add this[i].cut(this.localParam(i, ta), this.localParam(i, tb))
    res.reversed.len = res.curves.len
    return res.toOwnedCurve2
  else:
    var res: Path2
    for i in countdown(ia, ib):
      res.curves.add this[i].cut(this.localParam(i, ta), this.localParam(i, tb))
    res.reversed.len = res.curves.len
    return res.toOwnedCurve2



# --- Path2 construction API ---

Curve2.implementInterfaceFor(Path2_BuildPoint, fwd = Declare)

proc length(this: Path2_BuildPoint;): Float = 0
proc pointAtParam(this: Path2_BuildPoint; param: FloatParam): Point2 = this.pos
proc derAtParam(this: Path2_BuildPoint; param: FloatParam): V2 = v2(1, 0)
proc bounds(this: Path2_BuildPoint; a: FloatParam, b: FloatParam): Bounds2 = bounds2(this.pos)
proc cut(this: Path2_BuildPoint; a: FloatParam, b: FloatParam): OwnedCurve2 = this.toOwnedCurve2
proc transform(this: Path2_BuildPoint; m: M4): Path2_BuildPoint {.aliases: [`*`].} =
  result = this
  result.pos = this.pos.transform(m)

when sigeo_backend == SigeoOpencascade:
  proc toOpencascadeShape(this: Path2_BuildPoint;): TopoDS_Shape = discard

Curve2.implementInterfaceFor(Path2_BuildPoint, fwd = Implement)


proc makeNotReversed*(this: var Path2, i: int) =
  if i notin 0..this.curves.high: return
  if this.reversed[i]:
    this.curves[i] = this.curves[i].cut(1, 0)
    this.reversed[i] = false


proc insertBevel*(this: var Path2, radius: Float, c1i = this.curves.len - 2)
proc insertFillet*(this: var Path2, radius: Float, c1i = this.curves.len - 2)


proc add*(this: var Path2, c: Curve2) =
  ## adds a curve to path. If curve does not start or end at path end, adds a line section to start of the added curve
  if this.curves.len == 0:
    this.curves.add c.toOwnedCurve2
    this.reversed.len = this.curves.len
    return
  
  var bp: Path2_BuildPoint

  let p =
    if this.curves.len != 0 and this.curves[^1].isOf(Path2_BuildPoint):
      bp = this.curves[^1].castTo(Path2_BuildPoint)
      if this.curves.len == 1 and bp.kind != StartPoint:
        discard
      else:
        this.curves.setLen this.curves.len - 1
        this.reversed.len = this.curves.len
      bp.pos
    else:
      this.pointAtParam(1)
  
  if p ~== c.pointAtParam(0):
    this.curves.add c.toOwnedCurve2
    this.reversed.len = this.curves.len
  elif p ~== c.pointAtParam(1):
    this.curves.add c.toOwnedCurve2
    this.reversed[this.curves.high] = true
  else:
    this.curves.add lineSection(p, c.pointAtParam(0)).toOwnedCurve2
    this.curves.add c.toOwnedCurve2
    this.reversed.len = this.curves.len
  
  if (this.curves.len - (if this.curves[0].isOf(Path2_BuildPoint): 1 else: 0)) < 2 and bp.kind != StartPoint:
    discard
  else:
    if bp.kind == BevelPoint:
      this.insertBevel(bp.radius)
    elif bp.kind == FilletPoint:
      this.insertFillet(bp.radius)
  
  if this.curves.len >= 2 and this.isClosed and this.curves[0].isOf(Path2_BuildPoint):
    let bp = this.curves[0].castTo(Path2_BuildPoint)
    this.curves.delete 0
    this.reversed.delete 0
    if bp.kind == BevelPoint:
      this.insertBevel(bp.radius, this.curves.high)
    elif bp.kind == FilletPoint:
      this.insertFillet(bp.radius, this.curves.high)



proc add*(this: var Path2, p: Point2) =
  if this.curves.len == 0:
    this.curves.add Path2_BuildPoint(pos: p, kind: StartPoint).toOwnedCurve2
    this.reversed.len = this.curves.len
  else:
    this.add lineSection(this.pointAtParam(1), p).toOwnedCurve2


proc close*(this: var Path2) =
  if not this.isClosed:
    this.add this.pointAtParam(0)


proc add*(this: var Path2, v: V2) =
  this.add this.pointAtParam(1) + v


proc bevel*(this: var Path2, radius: Float) =
  if this.curves.len != 0 and this.curves[^1].isOf(Path2_BuildPoint):
    this.curves[^1].castTo(Path2_BuildPoint) = Path2_BuildPoint(pos: this.pointAtParam(1), kind: BevelPoint, radius: radius)
  else:
    this.curves.add Path2_BuildPoint(pos: this.pointAtParam(1), kind: BevelPoint, radius: radius).toOwnedCurve2


proc fillet*(this: var Path2, radius: Float) =
  if this.curves.len != 0 and this.curves[^1].isOf(Path2_BuildPoint):
    this.curves[^1].castTo(Path2_BuildPoint) = Path2_BuildPoint(pos: this.pointAtParam(1), kind: FilletPoint, radius: radius)
  else:
    this.curves.add Path2_BuildPoint(pos: this.pointAtParam(1), kind: FilletPoint, radius: radius).toOwnedCurve2


# todo: proc addArc*(this: var Path2, p: Point2)


proc insertBevel*(this: var Path2, radius: Float, c1i = this.curves.len - 2) =
  ## adds bevel between curve `c1i` and the next curve.
  ## if `c1i` == this.curves.high, then the next curve is this.curves[0]
  assert this.curves.len >= 2
  let c2i = (c1i + 1) mod this.curves.len

  if this.curves[c1i].isOf(LineSection2) and this.curves[c2i].isOf(LineSection2):
    let betweenI = c1i + 1
    this.makeNotReversed c1i
    this.makeNotReversed c2i
    letCur c1: this.curves[c1i].castTo(LineSection2)
    letCur c2: this.curves[c2i].castTo(LineSection2)
    let p1 = c1.endPoint - c1.direction * radius
    let p2 = c2.startPoint + c2.direction * radius
    c1 = c1.cut(0, c1.paramAtPoint(p1))
    c2 = c2.cut(c2.paramAtPoint(p2), 1)
    this.curves.insert lineSection(p1, p2).toOwnedCurve2, betweenI
    this.reversed.insert false, betweenI
  
  else:
    raise ValueError.newException("not implemented")


proc insertFillet*(this: var Path2, radius: Float, c1i = this.curves.len - 2) =
  ## adds circular arc fillet between curve `c1i` and the next curve.
  ## if `c1i` == this.curves.high, then the next curve is this.curves[0]
  assert this.curves.len >= 2
  let c2i = (c1i + 1) mod this.curves.len

  if this.curves[c1i].isOf(LineSection2) and this.curves[c2i].isOf(LineSection2):
    let betweenI = c1i + 1
    this.makeNotReversed c1i
    this.makeNotReversed c2i
    letCur c1: this.curves[c1i].castTo(LineSection2)
    letCur c2: this.curves[c2i].castTo(LineSection2)
    let d1 = c1.direction
    let d2 = c2.direction
    let p1 = c1.endPoint - d1 * radius
    let p2 = c2.startPoint + d2 * radius
    c1 = c1.cut(0, c1.paramAtPoint(p1))
    c2 = c2.cut(c2.paramAtPoint(p2), 1)
    let turnSign = d1.skew(d2)
    let normal = if turnSign >= 0: d1.rot90cc else: d1.rot90c
    let center = p1 + normal * radius
    let startAngle = (p1 - center).planarAngle
    let endAngle = (p2 - center).planarAngle
    let direction = if (turnSign > 0) == sigeo_axisY_up: counterclockwise else: clockwise
    this.curves.insert circleArc(center, radius, startAngle, endAngle, direction).toOwnedCurve2, betweenI
    this.reversed.insert false, betweenI

  else:
    raise ValueError.newException("not implemented")


proc addBevel*(this: var Path2, radius: Float) {.deprecated: "use bevel or insertBevel instead".} =
  this.insertBevel(radius)

proc addFillet*(this: var Path2, radius: Float) {.deprecated: "use fillet or insertFillet instead".} =
  this.insertFillet(radius)



# --- opinionated path construction API extension ---

proc at*(this: Path2): Point2 = this.pointAtParam(1)
proc i*(this: Path2): int = this.curves.len

proc point*(this: Path2, i: int): Point2 =
  if i >= this.curves.len: this.pointAtParam(1)
  else: this.pointAtCurve(i, 0)


proc `x=`*(this: var Path2, v: Float) =
  this.add p2(v, this.pointAtParam(1).y)

proc `y=`*(this: var Path2, v: Float) =
  this.add p2(this.pointAtParam(1).x, v)


proc `x`*(this: var Path2): Path2_X = Path2_X this.addr
proc `y`*(this: var Path2): Path2_Y = Path2_Y this.addr

proc `+=`*(this: Path2_X, v: Float) =
  (ptr Path2)(this)[].add v2(v, 0)

proc `+=`*(this: Path2_Y, v: Float) =
  (ptr Path2)(this)[].add v2(0, v)


proc `-=`*(this: Path2_X, v: Float) =
  (ptr Path2)(this)[].add v2(-v, 0)

proc `-=`*(this: Path2_Y, v: Float) =
  (ptr Path2)(this)[].add v2(0, -v)



# --- opencascade utils ---

when sigeo_backend == SigeoOpencascade:
  proc addSigeoCurve(wire: var BRepBuilderAPI_MakeWire, curve: Curve2Concept) =
    let curve = curve.toOpencascadeShape
    if curve.shapeType == TopAbs_EDGE:
      wire.add curve.edge
    elif curve.shapeType == TopAbs_WIRE:
      let explorer = topExp_Explorer(curve.wire, TopAbs_EDGE)
      while more explorer:
        wire.add explorer.current.edge
        next explorer
    else:
      raise ValueError.newException("unexpected shape")
  

  proc toCurve2*(shape: TopoDS_Shape): OwnedCurve2 =
    let edge = shape.edge
    var first, last: cdouble
    let curve = BRep_Tool_curve(edge, first, last)

    
    if (let ent = curve.downcast(Geom_Line); not ent.isNull):
      var p1, p2: gp_Pnt
      ent.get[].d0(first, p1)
      ent.get[].d0(last, p2)
      return lineSection(point2(p1.x, p1.y), point2(p2.x, p2.y)).toOwnedCurve2

    if (let ent = curve.downcast(Geom_Circle); not ent.isNull):
      let circ = ent.get[].circ
      let center = circ.location
      return circleArc(
        point2(center.x, center.y), circ.radius,
        first, last
      ).toOwnedCurve2

    if (let ent = curve.downcast(Geom_Ellipse); not ent.isNull):
      let elips = ent.get[].elips
      let center = elips.location
      return ellipseArc(
        point2(center.x, center.y),
        v2(elips.majorRadius * 2, elips.minorRadius * 2),
        first, last
      ).toOwnedCurve2

    raise ValueError.newException("unsupported curve type")



  proc toOpencascadeShape*(this: Path2;): TopoDS_Shape =
    var wire: BRepBuilderAPI_MakeWire
    for curve in this.curves.view:
      wire.addSigeoCurve curve
    wire.shape


proc transform*(this: Path2, m: M4): Path2 {.aliases: [`*`].} =
  ## returns a curve with 4x4 transformation matrix applied.
  ## traversal order and the `reversed` flags are preserved
  result.curves = newSeq[OwnedCurve2](this.curves.len)
  for i in 0 ..< this.curves.len:
    result.curves[i] = this.curves.view[i].transform(m)
  result.reversed = this.reversed


Curve2.implementInterfaceFor(Path2, fwd = Implement)



# todo: boolean operations with a Path2


when isMainModule:
  import print

  proc numDer(c: Curve2, t: FloatParam, eps = 1e-6): V2 =
    (c.pointAtParam((t.Float + eps).FloatParam) - c.pointAtParam((t.Float - eps).FloatParam)) / (2 * eps)

  print "\n\n--- derAtParam matches finite differences ---"

  block:
    var curves: seq[OwnedCurve2]
    curves.add lineSection(point2(1, 2), point2(4, -1)).toOwnedCurve2
    curves.add circleArc(point2(0, 0), 2, Pi / 6, Pi).toOwnedCurve2

    for curve in curves.view:
      for t in [0.1, 0.4, 0.9]:
        assert (curve.derAtParam(t.FloatParam) - curve.numDer(t.FloatParam)).length < 1e-6

  print "\n\n--- cut through the Curve2 interface ---"

  block:
    let line = lineSection(point2(0, 0), point2(2, 2))
    let piece = line.toCurve2.cut(0.25.FloatParam, 0.75.FloatParam)
    assert piece.isOf(LineSection2)
    assert piece.pointAtParam(0).distanceTo(point2(0.5, 0.5)) < 1e-9
    assert piece.pointAtParam(1).distanceTo(point2(1.5, 1.5)) < 1e-9

  print "\n\n--- Contour: cut and derAtParam ---"

  block:
    # a triangle with the second side stored reversed
    var contour = Path2(curves: @[
      lineSection(point2(0, 0), point2(2, 0)).toOwnedCurve2,
      lineSection(point2(2, 2), point2(2, 0)).toOwnedCurve2,
      lineSection(point2(2, 2), point2(0, 0)).toOwnedCurve2,
    ])
    contour.reversed[1] = true

    # traversal is continuous
    for i in 0..<contour.curves.len:
      assert contour.pointAtCurve(i, 1).distanceTo(
        contour.pointAtCurve((i + 1) mod contour.curves.len, 0)) < 1e-9

    for t in [0.15, 0.5, 0.8]:  # inside smooth regions of the contour
      assert (contour.derAtParam(t.FloatParam) - contour.toCurve2.numDer(t.FloatParam)).length < 1e-5

    for (a, b) in [(0.2, 0.9), (0.9, 0.2), (0.5, 5/6)]:
      let piece = contour.cut(a.FloatParam, b.FloatParam)
      assert piece.pointAtParam(0).distanceTo(contour.pointAtParam(a.FloatParam)) < 1e-9
      assert piece.pointAtParam(1).distanceTo(contour.pointAtParam(b.FloatParam)) < 1e-9
      # pieces stay continuous
      assert piece.isOf(Path2)
      for i in 0..<piece.castTo(Path2).curves.len - 1:
        assert piece.castTo(Path2).pointAtCurve(i, 1).distanceTo(piece.castTo(Path2).pointAtCurve(i + 1, 0)) < 1e-9

    # a contour is itself a Curve2, so it can be cut through the interface
    let owned = contour.toCurve2.cut(0.2.FloatParam, 0.9.FloatParam)
    assert owned.isOf(Path2)
    assert owned.pointAtParam(0).distanceTo(contour.pointAtParam(0.2.FloatParam)) < 1e-9

  print "\n\n--- Path: cut spanning multiple sub-curves (no reversed) ---"

  block:
    # an open, non-reversed 3-curve path (line, arc, line) — the shape produced
    # by the construction API (e.g. a vertical wall, a fillet, a horizontal wall).
    # cuts spanning sub-curve boundaries (and reaching the very end, b == 1) must
    # keep every endpoint on the path and not collapse a spanned sub-curve.
    var path = Path2(curves: @[
      lineSection(point2(0, 0), point2(0, 3)).toOwnedCurve2,
      circleArc(point2(1, 3), 1, Pi, Pi / 2, clockwise).toOwnedCurve2,
      lineSection(point2(1, 4), point2(4, 4)).toOwnedCurve2,
    ])
    path.reversed.len = path.curves.len
    assert path.curves.len == 3
    assert path.isContinuous

    for (a, b) in [(0.0, 1.0), (0.0, 0.7), (0.4, 1.0), (0.2, 0.9), (0.9, 0.2)]:
      let piece = path.cut(a.FloatParam, b.FloatParam)
      assert piece.pointAtParam(0).distanceTo(path.pointAtParam(a.FloatParam)) < 1e-9
      assert piece.pointAtParam(1).distanceTo(path.pointAtParam(b.FloatParam)) < 1e-9
      assert piece.length > 1e-9  # spanning cuts are not degenerate
      if piece.isOf(Path2):
        for i in 0..<piece.castTo(Path2).curves.len - 1:
          assert piece.castTo(Path2).pointAtCurve(i, 1).distanceTo(piece.castTo(Path2).pointAtCurve(i + 1, 0)) < 1e-9

  echo "ok"


