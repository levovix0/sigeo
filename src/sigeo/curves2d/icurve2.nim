import ../core/[vectors, points, bounds, buildutils]
import ../macros/[interfaces]
export implementInterfaceFor

when sigeo_backend == SigeoOpencascade:
  import pkg/opencascade except string



makeInterface Curve2:
  # note that aliases are defined as a part of interface, to force that same aliases are defined for concrete curves (for consistency)
  proc length(this;): Float
  proc pointAt(this; param: FloatParam): Point2
  proc pointAtParam(this; param: FloatParam): Point2  # (alias for pointAt)
  proc derAt(this; param: FloatParam): V2
  proc derAtParam(this; param: FloatParam): V2  # (alias for derAt)

  proc bounds(this; a: FloatParam, b: FloatParam): Bounds2
  proc cut(this; a: FloatParam, b: FloatParam): OwnedCurve2

  proc transform(this; m: M4): OwnedCurve2
  proc `*`(this; m: M4): OwnedCurve2  # (alias for transform)

  proc `$`(this;): string

  when sigeo_backend == SigeoOpencascade:
    proc toOpencascadeShape(this;): TopoDS_Shape


proc bounds*(curve: Curve2): Bounds2 =
  ## bounding box of the whole curve
  curve.bounds(0.FloatParam, 1.FloatParam)


proc reverse*(this: Curve2): OwnedCurve2 =
  this.cut(1, 0)


proc points*(arc: Curve2, count: int = 32): seq[Point2] =
  for i in 0..count:
    result.add arc.pointAt(i / count)


proc view*(curves {.byref.}: seq[OwnedCurve2]): lent seq[Curve2] =
  ## yep, this is totaly safe, Curve2 is guarantied to have same binary representation as OwnedCurve2
  cast[ptr seq[Curve2]](curves.addr)[]


proc toOwnedCurve2*(c: Curve2): OwnedCurve2 =
  # todo: move to macros
  assert c.obj != nil
  result.vtable = c.vtable
  c.vtable.dup(c.obj, result.obj)


proc `$`*(c: OwnedCurve2): string =
  `$`(c.Curve2)

