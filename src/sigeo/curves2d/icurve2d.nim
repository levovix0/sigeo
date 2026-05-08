import ../core/[vectors, points]
import ../macros/[interfaces]
import ./[lineSection, circleArc]


makeInterface Curve2d:
  proc length(this;): Float
  proc pointAtParam(this; param: FloatParam): Point2


Curve2d.implementInterfaceFor(LineSection, CircleArc)


when isMainModule:
  let line = lineSection(point2(0, 0), point2(2, 0))
  let circle = circleArc(point2(4, 0), 2)

  let arr = @[Curve2d line, circle]

  for x in arr:
    echo "[", x.vtable.typenameHash, "]"
    echo "length = ", x.length
    echo "pointAtParam(0) = ", x.pointAtParam(0)
    echo "pointAtParam(0.25) = ", x.pointAtParam(0.25)
    echo "pointAtParam(0.5) = ", x.pointAtParam(0.5)
    echo "pointAtParam(0.75) = ", x.pointAtParam(0.75)
    echo "pointAtParam(1) = ", x.pointAtParam(1)

