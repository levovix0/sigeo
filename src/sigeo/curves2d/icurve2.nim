import ../core/[vectors, points, bounds, buildutils]
import ../macros/[interfaces]
export implementInterfaceFor

when sigeo_backend == SigeoOpencascade:
  import pkg/opencascade



when sigeo_backend == SigeoOpencascade:
  makeInterface Curve2:
    proc length(this;): Float
    proc pointAtParam(this; param: FloatParam): Point2
    proc derAtParam(this; param: FloatParam): V2
    proc bounds(this; a: FloatParam, b: FloatParam): Bounds2
    proc cut(this; a: FloatParam, b: FloatParam): OwnedCurve2
    proc `$`(this;): string

    proc toOpencascadeShape(this;): TopoDS_Shape


else:
  makeInterface Curve2:
    proc length(this;): Float
    proc pointAtParam(this; param: FloatParam): Point2
    proc derAtParam(this; param: FloatParam): V2
    proc bounds(this; a: FloatParam, b: FloatParam): Bounds2
    proc cut(this; a: FloatParam, b: FloatParam): OwnedCurve2
    proc `$`(this;): string


proc bounds*(curve: Curve2): Bounds2 =
  ## bounding box of the whole curve
  curve.bounds(0.FloatParam, 1.FloatParam)


proc points*(arc: Curve2, count: int = 32): seq[Point2] =
  for i in 0..count:
    result.add arc.pointAtParam(i / count)


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

