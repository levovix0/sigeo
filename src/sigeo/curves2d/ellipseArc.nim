import ../core/[vectors, points]
import ./circleArc

type
  EllipseArc* = object
    ## a kind of 2d curve — an arc of an axis-aligned ellipse
    center*: Point2
    size*: Vec2
      ## full bounding box: width = 2*rx, height = 2*ry
    startAngle*, endAngle*: Float
      ## signed angle from +x to start/end point in radians
      ## if equal, the ellipse is full
      ## positive is counterclockwise, negative is clockwise
    direction*: CircleArcDirection


proc ellipseArc*(
  center: Point2, size: Vec2,
  startAngle: Float = 0, endAngle: Float = 0,
  direction: CircleArcDirection = counterclockwise
): EllipseArc =
  EllipseArc(
    center: center, size: size,
    startAngle: startAngle, endAngle: endAngle,
    direction: direction
  )


proc fullEllipse*(arc: EllipseArc): bool {.inline.} =
  arc.startAngle == arc.endAngle


proc angularLength*(arc: EllipseArc): Float =
  if arc.fullEllipse: 2 * Pi
  else: arc.endAngle - arc.startAngle


proc pointAtParam*(arc: EllipseArc, t: FloatParam): Point2 =
  let angle = arc.startAngle + Float(t) * arc.angularLength
  arc.center + vec2(arc.size.x / 2 * cos(angle), arc.size.y / 2 * sin(angle))


proc points*(arc: EllipseArc, count: int = 32): seq[Point2] =
  for i in 0..count:
    result.add arc.pointAtParam(i / count)
