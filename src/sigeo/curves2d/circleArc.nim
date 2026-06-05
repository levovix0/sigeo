import ../core/[vectors, points]
import ../macros/[genAliases]

type
  CircleArc* = object
    ## a kind of 2d curve
    center*: Point2
    radius*: Float
    startAngle*, endAngle*: Float
      ## signed angle from +x to start/end point in radians
      ## if equal, circle is full
      ## positive is counterclockwise, negative is clockwise
    direction*: AngleDirection
      ## is arc counterclockwise or clockwise from start to end


proc adjustToPrecision*(circle: var CircleArc) =
  if circle.startAngle.almostEqual(circle.endAngle):
    circle.startAngle = circle.endAngle


proc circleArc*(
  center: Point2, radius: Float,
  startAngle: Float = 0, endAngle: Float = 0,
  direction: AngleDirection = counterclockwise
): CircleArc =
  result = CircleArc(
    center: center,
    radius: radius,
    startAngle: startAngle,
    endAngle: endAngle,
    direction: direction
  )

  if radius ~== 0:
    when defined(sigeo_return_small_curve_when_costructed_curve_has_zero_length):
      result.radius = 1e-6
    
    elif true or defined(sigeo_raise_exception_when_costructed_curve_has_zero_length):
      raise ValueError.newException("Cannot construct curve with zero length")
  
  adjustToPrecision(result)


proc fullCircle*(circle: CircleArc): bool {.aliases: [closed, isCircle, isFullCircle, isClosed].} =
  ## returns true if arc is full circle
  ## requires `circle` to be constructed via `circleArc` proc or be adjusted via `adjustToPrecision` proc
  circle.startAngle == circle.endAngle


proc startPoint*(circle: CircleArc): Point2 =
  circle.center + circle.radius * vec2(cos(circle.startAngle), sin(circle.startAngle))

proc endPoint*(circle: CircleArc): Point2 =
  circle.center + circle.radius * vec2(cos(circle.endAngle), sin(circle.endAngle))


proc angularLength*(circle: CircleArc): Float =
  ## returns signed angular sweep of the arc in radians, `Pi*2` for full circle
  if circle.fullCircle:
    case circle.direction
    of counterclockwise:  2 * Pi
    of clockwise:        -2 * Pi
  else:
    let diff = (circle.endAngle - circle.startAngle)
    if (circle.direction == counterclockwise) == sigeo_axisY_up:
      if diff <= 0: diff + 2 * Pi else: diff
    else:
      if diff >= 0: diff - 2 * Pi else: diff


proc length*(circle: CircleArc): Float =
  abs(circle.angularLength) * circle.radius


proc paramLength*(circle: CircleArc, t: FloatParam): Float {.deprecated: "always 1".} =
  1


proc pointAtParam*(circle: CircleArc, t: FloatParam): Point2 =
  let angle = circle.startAngle + t * circle.angularLength
  circle.center + circle.radius * vec2(cos(angle), sin(angle))


proc paramAtPoint*(circle: CircleArc, point: Point2): FloatParam =
  ## returns arbitrary number `t` such that circle.pointAtParam(`t`) returns `point`
  ## assumes that `point` is on circle arc
  let v = point - circle.center
  let angle = arctan2(v.y, v.x)
  FloatParam ((angle - circle.startAngle) mod (Pi*2)) / circle.angularLength



when isMainModule:
  import print

  print circleArc(point2(0, 0), 1, Pi/2, Pi).paramAtPoint(point2(1, 0))
  print circleArc(point2(0, 0), 1, Pi/2, Pi).paramAtPoint(point2(1, 1))
  print circleArc(point2(0, 0), 1, Pi/2, Pi).paramAtPoint(point2(0, 1))
  print circleArc(point2(0, 0), 1, Pi/2, Pi).paramAtPoint(point2(-1, 1))
  print circleArc(point2(0, 0), 1, Pi/2, Pi).paramAtPoint(point2(1, -1))
  print circleArc(point2(0, 0), 1, Pi/2, Pi).paramAtPoint(point2(-1, -1))
