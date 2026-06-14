import ../[core]
import ../macros/[interfaces, cursors]
import ./[icurve2, lineSection, circleArc]

when sigeo_backend == SigeoOpencascade:
  import ./[lineSection, circleArc, ellipseArc]
  import pkg/opencascade

when sigeo_backend == SigeoC3d:
  import pkg/c3d, pkg/c3d/bindings


type
  Path2* = object
    ## continuous sequence of curves
    curves*: seq[OwnedCurve2]
    reversed*: Bitmask


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

  proc localParam(this: Path2, t: Float): FloatParam =
    if this.reversed[t.int]: (1 - (t - t.floor)).FloatParam else: (t - t.floor).FloatParam

  if ta.int == tb.int:
    return this[ta.int].cut(this.localParam(ta), this.localParam(tb))
  elif ta < tb:
    var res: Path2
    for i in countup(ta.int, tb.int):
      res.curves.add this[i].cut(
        this.localParam(ta.clamp(i.Float, (i + 1).float)),
        this.localParam(tb.clamp(i.Float, (i + 1).float)),
      )
    return res.toOwnedCurve2
  else:
    var res: Path2
    for i in countdown(ta.int, tb.int):
      res.curves.add this[i].cut(
        this.localParam(ta.clamp(i.Float, (i + 1).float)),
        this.localParam(tb.clamp(i.Float, (i + 1).float)),
      )
    return res.toOwnedCurve2



proc makeNotReversed*(this: var Path2, i: int) =
  if i notin 0..this.curves.high: return
  if this.reversed[i]:
    this.curves[i] = this.curves[i].cut(1, 0)
    this.reversed[i] = false



proc close*(this: var Path2) =
  if not this.isClosed:
    this.curves.add lineSection(this.pointAtParam(1), this.pointAtParam(0)).toOwnedCurve2
    this.reversed.len = this.curves.len


proc add*(this: var Path2, c: Curve2) =
  ## adds a curve to path. If curve does not start or end at path end, adds a line section to start of the added curve
  if this.curves.len == 0:
    this.curves.add c.toOwnedCurve2
    this.reversed.len = this.curves.len
    return
  
  let p =
    if this.curves.len == 1 and this.curves[0].isOf(LineSection2) and this.curves[0].castTo(LineSection2).length ~== 0:
      let p = this.curves[0].castTo(LineSection2).startPoint
      this.curves.setLen 0
      this.reversed.len = 0
      p
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


proc add*(this: var Path2, p: Point2) =
  this.curves.add lineSection(if this.curves.len == 0: p else: this.pointAtParam(1), p).toOwnedCurve2
  this.reversed.len = this.curves.len

# todo: proc addArc*(this: var Path2, p: Point2)


proc addBevel*(this: var Path2, radius: Float) =
  ## adds bevel between 2 last added curves
  assert this.curves.len >= 2

  if this.curves[^2].isOf(LineSection2) and this.curves[^1].isOf(LineSection2):
    let betweenI = this.curves.len - 1
    this.makeNotReversed this.curves.len-2
    this.makeNotReversed this.curves.len-1
    letCur c1: this.curves[^2].castTo(LineSection2)
    letCur c2: this.curves[^1].castTo(LineSection2)
    let p1 = c1.endPoint - c1.direction * radius
    let p2 = c2.startPoint + c2.direction * radius
    c1 = c1.cut(0, c1.paramAtPoint(p1))
    c2 = c2.cut(c2.paramAtPoint(p2), 1)
    this.curves.insert lineSection(p1, p2).toOwnedCurve2, betweenI
    this.reversed.insert false, betweenI
  
  else:
    raise ValueError.newException("not implemented")


proc addFillet*(this: var Path2, radius: Float) =
  ## adds circular arc fillet between 2 last added curves
  assert this.curves.len >= 2

  if this.curves[^2].isOf(LineSection2) and this.curves[^1].isOf(LineSection2):
    let betweenI = this.curves.len - 1
    this.makeNotReversed this.curves.len-2
    this.makeNotReversed this.curves.len-1
    letCur c1: this.curves[^2].castTo(LineSection2)
    letCur c2: this.curves[^1].castTo(LineSection2)
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



when sigeo_backend == SigeoOpencascade:
  proc add(wire: var BRepBuilderAPI_MakeWire, curve: Curve2Concept) =
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
      wire.add curve
    wire.shape


Curve2.implementInterfaceFor(Path2, fwd = Implement)



# todo: boolean operations with a Path2


when isMainModule:
  import print
  import ./[lineSection, circleArc]

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

  echo "ok"


