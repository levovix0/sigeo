import ../core/[vectors, points, bounds, buildutils]
import ../macros/[genAliases]
import ./[icurve2]

when sigeo_backend == SigeoOpencascade:
  import pkg/opencascade except cos, sin, min, max


type
  CircleArc2* = object
    ## a kind of 2d curve
    center*: Point2
    radius*: Float
    startAngle*, endAngle*: Float
      ## signed angle from +x to start/end point in radians
      ## if equal, circle is full
      ## positive is counterclockwise, negative is clockwise
    direction*: AngleDirection
      ## is arc counterclockwise or clockwise from start to end
  
  CircleArc* {.deprecated: "renamed to CircleArc2".} = CircleArc2


func adjustToPrecision*(circle: var CircleArc2) =
  if circle.startAngle.almostEqual(circle.endAngle):
    circle.startAngle = circle.endAngle


func circleArc2*(
  center: Point2, radius: Float,
  startAngle: Float = 0, endAngle: Float = 0,
  direction: AngleDirection = counterclockwise
): CircleArc2 {.aliases: [circleArc, circle, arc].} =
  result = CircleArc2(
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


func fullCircle*(circle: CircleArc2): bool {.aliases: [closed, isCircle, isFullCircle, isClosed].} =
  ## returns true if arc is full circle
  ## requires `circle` to be constructed via `circleArc` func or be adjusted via `adjustToPrecision` func
  circle.startAngle == circle.endAngle


func startPoint*(circle: CircleArc2): Point2 =
  circle.center + circle.radius * v2(cos(circle.startAngle), sin(circle.startAngle))

func endPoint*(circle: CircleArc2): Point2 =
  circle.center + circle.radius * v2(cos(circle.endAngle), sin(circle.endAngle))


func angularLength*(circle: CircleArc2): Float =
  ## returns signed angular sweep of the arc in radians, `Pi*2` for full circle
  if circle.fullCircle:
    if (circle.direction == counterclockwise) == sigeo_axisY_up: 2 * Pi
    else: -2 * Pi
  else:
    let diff = (circle.endAngle - circle.startAngle)
    if (circle.direction == counterclockwise) == sigeo_axisY_up:
      if diff <= 0: diff + 2 * Pi else: diff
    else:
      if diff >= 0: diff - 2 * Pi else: diff


func length*(circle: CircleArc2): Float {.inline.} =
  abs(circle.angularLength) * circle.radius


func pointAt*(curve: CircleArc2, t: FloatParam): Point2 {.aliases: [pointAtParam].} =
  let angle = curve.startAngle + t * curve.angularLength
  curve.center + curve.radius * v2(cos(angle), sin(angle))


func derAtParam*(curve: CircleArc2, t: FloatParam): V2 {.aliases: [derAt].} =
  let angLen = curve.angularLength
  let angle = curve.startAngle + t * angLen
  curve.radius * angLen * v2(-sin(angle), cos(angle))


func paramAt*(circle: CircleArc2, point: Point2): FloatParam {.aliases: [paramAtPoint].} =
  ## returns arbitrary number `t` such that circle.pointAt(`t`) returns `point`
  ## assumes that `point` is on circle arc
  let v = point - circle.center
  let angle = arctan2(v.y, v.x)
  FloatParam ((angle - circle.startAngle) mod (Pi*2)) / circle.angularLength



func cut*(curve: CircleArc2, a, b: FloatParam): CircleArc2 =
  ## returns the part of the arc between params `a` and `b`, such that
  ## `result.pointAt(t) == curve.pointAt(a + t * (b - a))`
  ## if `a > b`, the resulting arc goes backwards along the original arc
  let angLen = curve.angularLength
  let sweep = angLen * (b.Float - a.Float)
  CircleArc2(
    center: curve.center,
    radius: curve.radius,
    startAngle: normalizeAngle(curve.startAngle + a.Float * angLen),
    endAngle: normalizeAngle(curve.startAngle + b.Float * angLen),
    direction: (if (sweep > 0) == sigeo_axisY_up: counterclockwise else: clockwise),
  )


func invertDir*(curve: CircleArc2): CircleArc2 =
  result = curve
  result.direction = (if curve.direction == clockwise: counterclockwise else: clockwise)

func reverse*(curve: CircleArc2): CircleArc2 {.inline.} = curve.cut(1, 0)



func bounds*(curve: CircleArc2, a, b: FloatParam): Bounds2 =
  ## bounding box of the part of the arc between params `a` and `b`
  let angLen = curve.angularLength
  let ang0 = curve.startAngle + a.Float * angLen
  let ang1 = curve.startAngle + b.Float * angLen

  result = bounds2(
    curve.center + curve.radius * v2(cos(ang0), sin(ang0)),
    curve.center + curve.radius * v2(cos(ang1), sin(ang1)),
  )

  # extreme points of a circle are at angles that are multiples of Pi/2
  let lo = min(ang0, ang1)
  let hi = max(ang0, ang1)
  var k = ceil(lo / (Pi/2))
  while k * (Pi/2) <= hi:
    let ang = k * (Pi/2)
    result.add curve.center + curve.radius * v2(cos(ang), sin(ang))
    k += 1



func transform*(curve: CircleArc2, m: M4): CircleArc2 {.aliases: [`*`].} =
  ## returns a curve with 4x4 transformation matrix applied.
  ## assumes the matrix scales uniformly, so a circle stays a circle
  let scale = hypot(m[0, 0], m[0, 1])  # length of the transformed x axis
  let rotation = arctan2(m[0, 1], m[0, 0]) # angle of the transformed x axis
  let reflected = m[0, 0] * m[1, 1] - m[1, 0] * m[0, 1] < 0

  if not reflected:
    circleArc2(
      curve.center.transform(m), scale * curve.radius,
      curve.startAngle + rotation,
      curve.endAngle + rotation,
      curve.direction,
    )
  else:
    circleArc2(
      curve.center.transform(m), scale * curve.radius,
      rotation - curve.startAngle,
      rotation - curve.endAngle,
      (if curve.direction == counterclockwise: clockwise else: counterclockwise),
    )



when sigeo_backend == SigeoOpencascade:
  proc toOpencascadeShape*(this: CircleArc2;): TopoDS_Shape =
    bRepBuilderAPI_MakeEdge(
      gp_Circ(gp_Ax2(gp_Pnt(this.center.x, this.center.y, 0), gp_Dir(0, 0, 1)), this.radius),
      (if this.direction == counterclockwise: this.startAngle else: this.endAngle),
      (if this.direction == counterclockwise: this.endAngle else: this.startAngle),
    ).edge



Curve2.implementInterfaceFor(CircleArc2)


when isMainModule:
  import print

  print circleArc(point2(0, 0), 1, Pi/2, Pi).paramAt(point2(1, 0))
  print circleArc(point2(0, 0), 1, Pi/2, Pi).paramAt(point2(1, 1))
  print circleArc(point2(0, 0), 1, Pi/2, Pi).paramAt(point2(0, 1))
  print circleArc(point2(0, 0), 1, Pi/2, Pi).paramAt(point2(-1, 1))
  print circleArc(point2(0, 0), 1, Pi/2, Pi).paramAt(point2(1, -1))
  print circleArc(point2(0, 0), 1, Pi/2, Pi).paramAt(point2(-1, -1))

  block:
    # cut invariant: cut(a, b).pointAt(t) == original.pointAt(a + t * (b - a))
    for dir in [counterclockwise, clockwise]:
      for (sa, ea) in [(0.0, 0.0), (Pi/2, Pi), (Pi, Pi/2), (-3*Pi/4, Pi/4), (3*Pi/4, -3*Pi/4)]:
        let arc = circleArc(point2(1, 2), 2, sa, ea, dir)
        for (a, b) in [(0.0, 1.0), (0.25, 0.75), (0.75, 0.25), (0.0, 0.5), (0.9, 0.1), (1.0, 0.0)]:
          let c = arc.cut(a, b)
          for t in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]:
            let got = c.pointAt(t)
            let expected = arc.pointAt(a + t * (b - a))
            doAssert got.distanceTo(expected) < 1e-9,
              "cut mismatch: dir=" & $dir & " sa=" & $sa & " ea=" & $ea &
              " a=" & $a & " b=" & $b & " t=" & $t &
              " got=" & $got & " expected=" & $expected
    echo "cut invariant ok"
