import ../[core]
import ../macros/[interfaces]
import ./[icurve2]

when sigeo_backend == SigeoOpencascade:
  import ./[lineSection, circleArc, ellipseArc]
  import pkg/opencascade

when sigeo_backend == SigeoC3d:
  import pkg/c3d, pkg/c3d/bindings


type
  Contour* = object
    ## continuous closed loop of curves
    curves*: seq[OwnedCurve2]
    reversed*: Bitmask


proc length*(this: Contour): float =
  result = 0
  for x in this.curves:
    result += x.length


proc `[]`*(this: Contour, i: int|BackwardsIndex): Curve2 {.inline.} =
  this.curves.view[i]  # todo: without `.view` it tries to copy OwnedCurve


proc pointAtCurve*(this: Contour, curve: int|BackwardsIndex, param: FloatParam): Point2 {.inline.} =
  if this.reversed[curve]:
    this[curve].pointAtParam(1 - param)
  else:
    this[curve].pointAtParam(param)


proc pointAtParam*(this: Contour; param: FloatParam): Point2 =
  assert this.curves.len != 0, "empty contour"
  if classify(param) != fcNormal: return this.pointAtCurve(0, 0)
  if param <= 0: return this.pointAtCurve(0, 0)
  if param >= 1: return this.pointAtCurve(^1, 1)
  let t = param.Float * this.curves.len.Float
  this.pointAtCurve(t.int, t mod 1)


proc approxSignedArea*(this: Contour, samplesPerCurve = 32): Float =
  ## approximate signed area enclosed by the contour, computed from a polyline approximation.
  ## positive if the contour is counterclockwise in coordinate space
  for i in 0..<this.curves.len:
    var prev = this.pointAtCurve(i, 0)
    for j in 1..samplesPerCurve:
      let p = this.pointAtCurve(i, FloatParam(j / samplesPerCurve))
      result += prev.x * p.y - p.x * prev.y
      prev = p
  result /= 2


proc bounds*(this: Contour, a, b: FloatParam): Bounds2 =
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



  proc toOpencascadeShape*(this: Contour;): TopoDS_Shape =
    var wire: BRepBuilderAPI_MakeWire
    for curve in this.curves.view:
      wire.add curve
    wire.shape


Curve2.implementInterfaceFor(Contour)



# todo: boolean operations with a Contour


