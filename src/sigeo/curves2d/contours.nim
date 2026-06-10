import ../[core]
import ../macros/[interfaces]
import ./[icurve2d, lineSection, circleArc, ellipseArc]

when sigeo_backend == SigeoOpencascade:
  import pkg/opencascade

when sigeo_backend == SigeoC3d:
  import pkg/c3d, pkg/c3d/bindings


type
  # todo: ContourGraph

  Contour* = object
    ## continuous closed loop of curves
    curves*: seq[OwnedCurve2d]
    reversed*: Bitmask


proc length*(this: Contour): float =
  result = 0
  for x in this.curves:
    result += x.length


proc pointAtCurve*(this: Contour, curve: int|BackwardsIndex, param: FloatParam): Point2 {.inline.} =
  if this.reversed[curve]:
    this.curves[curve].pointAtParam(1 - param)
  else:
    this.curves[curve].pointAtParam(param)


proc pointAtParam*(this: Contour; param: FloatParam): Point2 =
  assert this.curves.len != 0, "empty contour"
  if param <= 0: return this.pointAtCurve(0, 0)
  if param >= 1: return this.pointAtCurve(^1, 1)
  let t = param.Float * this.curves.len.Float
  this.pointAtCurve(t.int, t mod 1)


when sigeo_backend == SigeoOpencascade:
  proc add(wire: var BRepBuilderAPI_MakeWire, curve: Curve2dConcept) =
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
  

  proc toCurve2d*(shape: TopoDS_Shape): OwnedCurve2d =
    let edge = shape.edge
    var first, last: cdouble
    let curve = BRep_Tool_curve(edge, first, last)

    
    if (let ent = curve.downcast(Geom_Line); not ent.isNull):
      var p1, p2: gp_Pnt
      ent.get[].d0(first, p1)
      ent.get[].d0(last, p2)
      return lineSection(point2(p1.x, p1.y), point2(p2.x, p2.y)).toOwnedCurve2d

    if (let ent = curve.downcast(Geom_Circle); not ent.isNull):
      let circ = ent.get[].circ
      let center = circ.location
      return circleArc(
        point2(center.x, center.y), circ.radius,
        first, last
      ).toOwnedCurve2d

    if (let ent = curve.downcast(Geom_Ellipse); not ent.isNull):
      let elips = ent.get[].elips
      let center = elips.location
      return ellipseArc(
        point2(center.x, center.y),
        v2(elips.majorRadius * 2, elips.minorRadius * 2),
        first, last
      ).toOwnedCurve2d

    raise ValueError.newException("unsupported curve type")



  proc toOpencascadeShape*(this: Contour;): TopoDS_Shape =
    var wire: BRepBuilderAPI_MakeWire
    for curve in this.curves:
      wire.add curve
    wire.shape


Curve2d.implementInterfaceFor(Contour)



# todo: finding area of a Contour
# todo: boolean operations with a Contour


proc outerContour*(curves: openArray[Curve2dConcept]): Contour =
  ## find outer contour
  
  when sigeo_backend == SigeoOpencascade:
    # todo: this does not work!
    var wire: BRepBuilderAPI_MakeWire
    for curve in curves:
      wire.add curve
    
    let outer = bRepBuilderAPI_MakeFace(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), wire.wire).face.BRepTools_outerWire

    var explorer = bRepTools_WireExplorer(outer)
    while more explorer:
      result.curves.add toCurve2d explorer.current
      next explorer
  
  elif sigeo_backend == SigeoC3d:
    assert false, "not implemented"
  
  else:
    assert false, "not implemented"


