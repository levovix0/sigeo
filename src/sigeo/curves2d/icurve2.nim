import ../core/[vectors, points, bounds, buildutils]
import ../macros/[interfaces]
export implementInterfaceFor

when sigeo_backend == SigeoOpencascade:
  import pkg/opencascade



when sigeo_backend == SigeoOpencascade:
  makeInterface Curve2:
    proc length(this;): Float
    proc pointAtParam(this; param: FloatParam): Point2
    proc bounds(this; a: FloatParam, b: FloatParam): Bounds2
    proc toOpencascadeShape(this;): TopoDS_Shape


else:
  makeInterface Curve2:
    proc length(this;): Float
    proc pointAtParam(this; param: FloatParam): Point2
    proc bounds(this; a: FloatParam, b: FloatParam): Bounds2

    # todo: this gives an error:
    # proc cut(this; a: FloatParam, b: FloatParam): OwnedCurve2


proc bounds*(curve: Curve2): Bounds2 =
  ## bounding box of the whole curve
  curve.bounds(0.FloatParam, 1.FloatParam)


proc points*(arc: Curve2, count: int = 32): seq[Point2] =
  for i in 0..count:
    result.add arc.pointAtParam(i / count)


proc view*(curves {.byref.}: seq[OwnedCurve2]): lent seq[Curve2] =
  ## yep, this is totaly safe, Curve2 is guarantied to have same binary representation as OwnedCurve2
  cast[ptr seq[Curve2]](curves.addr)[]

