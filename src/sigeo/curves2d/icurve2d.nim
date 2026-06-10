import ../core/[vectors, points, buildutils]
import ../macros/[interfaces]
export implementInterfaceFor

when sigeo_backend == SigeoOpencascade:
  import pkg/opencascade



when sigeo_backend == SigeoOpencascade:
  makeInterface Curve2d:
    proc length(this;): Float
    proc pointAtParam(this; param: FloatParam): Point2
    proc toOpencascadeShape(this;): TopoDS_Shape


else:
  makeInterface Curve2d:
    proc length(this;): Float
    proc pointAtParam(this; param: FloatParam): Point2


proc points*(arc: Curve2d, count: int = 32): seq[Point2] =
  for i in 0..count:
    result.add arc.pointAtParam(i / count)

