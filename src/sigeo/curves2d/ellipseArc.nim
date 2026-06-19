import ../core/[vectors, points, bounds, buildutils]
import ../macros/[genAliases]
import ./[icurve2]

when sigeo_backend == SigeoOpencascade:
  import pkg/opencascade except sin, cos, min, max


type
  EllipseArc2* = object
    ## a kind of 2d curve — an arc of an arbitrarily rotated ellipse
    center*: Point2
    size*: V2
      ## full extents along the ellipse's own axes: width = 2*rx, height = 2*ry
      ## (equal to the bounding box when rotation == 0)
    startAngle*, endAngle*: Float
      ## signed parametric angle of start/end point in radians,
      ## measured in the ellipse's own (rotated) coordinate system
      ## if equal, the ellipse is full
      ## positive is counterclockwise, negative is clockwise
    direction*: AngleDirection
    rotation*: Float
      ## signed angle from global +x to the ellipse's own x axis in radians
  
  EllipseArc* {.deprecated: "renamed to EllipseArc2".} = EllipseArc2


proc ellipseArc2*(
  center: Point2, size: V2,
  startAngle: Float = 0, endAngle: Float = 0,
  direction: AngleDirection = counterclockwise,
  rotation: Float = 0,
): EllipseArc2 {.aliases: [ellipseArc, ellipse].} =
  EllipseArc2(
    center: center, size: size,
    startAngle: startAngle, endAngle: endAngle,
    direction: direction,
    rotation: rotation,
  )


proc ellipseArc2*(
  center: Point2, size: V2, xAxis: V2,
  startAngle: Float = 0, endAngle: Float = 0,
  direction: AngleDirection = counterclockwise,
): EllipseArc2 {.aliases: [ellipseArc, ellipse].} =
  ## constructs an ellipse arc with its own x axis pointing along `xAxis`
  ellipseArc(center, size, startAngle, endAngle, direction, rotation = xAxis.signedAngleToPlusX)


proc xAxis*(arc: EllipseArc2): V2 =
  ## direction of the ellipse's own x axis
  v2(cos(arc.rotation), sin(arc.rotation))


proc fullEllipse*(arc: EllipseArc2): bool {.inline.} =
  arc.startAngle == arc.endAngle


proc angularLength*(arc: EllipseArc2): Float =
  ## returns signed angular sweep of the arc in radians, `Pi*2` for full ellipse
  if arc.fullEllipse:
    if (arc.direction == counterclockwise) == sigeo_axisY_up: 2 * Pi
    else: -2 * Pi
  else:
    let diff = arc.endAngle - arc.startAngle
    if (arc.direction == counterclockwise) == sigeo_axisY_up:
      if diff <= 0: diff + 2 * Pi else: diff
    else:
      if diff >= 0: diff - 2 * Pi else: diff


func gaussLegendreNodesWeights(n: static int): (array[n, float64], array[n, float64]) =
  ## computes Gauss-Legendre nodes (roots of P_n) and weights via Newton iteration
  ## roots are symmetric, so only n/2 are computed and then mirrored
  var nodes: array[n, float64]
  var weights: array[n, float64]
  for i in 0 ..< n div 2:
    # initial guess: interior Chebyshev node as approximation for the i-th GL root
    var x = cos(PI * (float64(i) + 0.75) / (float64(n) + 0.5))
    var p0, p1, dp: float64
    for _ in 0 ..< 50:  # Newton iterations; converges in ~4-5
      p0 = 1.0
      p1 = x
      for j in 1 ..< n:  # evaluate P_n(x) via three-term recurrence
        let p2 = (float64(2*j + 1) * x * p1 - float64(j) * p0) / float64(j + 1)
        p0 = p1
        p1 = p2
      dp = float64(n) * (x * p1 - p0) / (x * x - 1.0) # P'_n(x)
      let dx = p1 / dp
      x -= dx
      if abs(dx) < 1e-15: break
    nodes[i] = -x
    nodes[n - 1 - i] = x
    let w = 2.0 / ((1.0 - x * x) * dp * dp)
    weights[i] = w
    weights[n - 1 - i] = w
  (nodes, weights)

const gl16 = gaussLegendreNodesWeights(16)
const gl16Nodes   = gl16[0]
const gl16Weights = gl16[1]


proc length*(arc: EllipseArc2): Float =
  ## arc length via 16-point Gauss-Legendre quadrature
  ## integrand: ds/dθ = √(rx^2 * sin(θ)^2 + ry^2 * cos(θ)^2)
  let rx = arc.size.x / 2
  let ry = arc.size.y / 2

  if rx == ry:
    return abs(arc.angularLength) * rx

  let half = arc.angularLength / 2
  let mid  = arc.startAngle + half

  var sum = Float(0)
  for i in 0..<16:
    let theta = mid + Float(gl16Nodes[i]) * half
    let s = sin(theta)
    let c = cos(theta)
    sum += Float(gl16Weights[i]) * sqrt(rx * rx * s * s + ry * ry * c * c)

  abs(half) * sum


proc angleAtParam*(curve: EllipseArc2, t: FloatParam): Float {.inline.} =
  curve.startAngle + t * curve.angularLength

proc pointAtAngle(curve: EllipseArc2, angle: Float): Point2 {.inline.} =
  curve.center + v2(curve.size.x / 2 * cos(angle), curve.size.y / 2 * sin(angle)).rotate(curve.rotation)

proc pointAtParam*(curve: EllipseArc2, t: FloatParam): Point2 =
  curve.pointAtAngle(curve.angleAtParam(t))


proc derAtParam*(curve: EllipseArc2, t: FloatParam): V2 =
  let angLen = curve.angularLength
  let angle = curve.angleAtParam(t)
  (angLen * v2(-curve.size.x / 2 * sin(angle), curve.size.y / 2 * cos(angle))).rotate(curve.rotation)


proc cut*(curve: EllipseArc2, a, b: FloatParam): EllipseArc2 =
  ## returns the part of the arc between params `a` and `b`, such that
  ## `result.pointAtParam(t) == curve.pointAtParam(a + t * (b - a))`
  ## if `a > b`, the resulting arc goes backwards along the original arc
  let angLen = curve.angularLength
  let sweep = angLen * (b.Float - a.Float)
  EllipseArc2(
    center: curve.center,
    size: curve.size,
    startAngle: normalizeAngle(curve.startAngle + a.Float * angLen),
    endAngle: normalizeAngle(curve.startAngle + b.Float * angLen),
    direction: (if (sweep > 0) == sigeo_axisY_up: counterclockwise else: clockwise),
    rotation: curve.rotation,
  )


proc invertDir*(curve: EllipseArc2): EllipseArc2 =
  result = curve
  result.direction = (if curve.direction == clockwise: counterclockwise else: clockwise)

proc reverse*(curve: EllipseArc2): EllipseArc2 {.inline.} = curve.cut(1, 0)



proc bounds*(curve: EllipseArc2, a, b: FloatParam): Bounds2 =
  ## bounding box of the part of the arc between params `a` and `b`
  let rx = curve.size.x / 2
  let ry = curve.size.y / 2
  let ang0 = curve.angleAtParam(a)
  let ang1 = curve.angleAtParam(b)

  result = bounds2(curve.pointAtAngle(ang0), curve.pointAtAngle(ang1))

  # extreme points of a rotated ellipse:
  # x(θ) = rx·cosθ·cosφ - ry·sinθ·sinφ, dx/dθ = 0 at θ = atan2(-ry·sinφ, rx·cosφ) + kπ
  # y(θ) = rx·cosθ·sinφ + ry·sinθ·cosφ, dy/dθ = 0 at θ = atan2( ry·cosφ, rx·sinφ) + kπ
  let lo = min(ang0, ang1)
  let hi = max(ang0, ang1)
  for crit in [
    arctan2(-ry * sin(curve.rotation), rx * cos(curve.rotation)),
    arctan2( ry * cos(curve.rotation), rx * sin(curve.rotation)),
  ]:
    var k = ceil((lo - crit) / Pi)
    while crit + k * Pi <= hi:
      result.add curve.pointAtAngle(crit + k * Pi)
      k += 1


proc transform*(curve: EllipseArc2, m: M4): EllipseArc2 {.aliases: [`*`].} =
  ## returns a curve with 4x4 transformation matrix applied.
  ## assumes the matrix scales uniformly, so the ellipse keeps its aspect ratio
  let scale = hypot(m[0, 0], m[0, 1])  # length of the transformed x axis
  let rotation = arctan2(m[0, 1], m[0, 0])      # angle of the transformed x axis
  let reflected = m[0, 0] * m[1, 1] - m[1, 0] * m[0, 1] < 0

  result.center = curve.center.transform(m)
  result.size = scale * curve.size

  if not reflected:
    result.rotation = curve.rotation + rotation
    result.startAngle = curve.startAngle
    result.endAngle = curve.endAngle
    result.direction = curve.direction
  else:
    # a reflection flips the ellipse's own y axis: negate rotation/angles and the traversal direction
    result.rotation = rotation - curve.rotation
    result.startAngle = -curve.startAngle
    result.endAngle = -curve.endAngle
    result.direction = (if curve.direction == counterclockwise: clockwise else: counterclockwise)



when sigeo_backend == SigeoOpencascade:
  proc toOpencascadeShape*(this: EllipseArc2;): TopoDS_Shape =
    bRepBuilderAPI_MakeEdge(
      gp_Elips(gp_Ax2(gp_Pnt(this.center.x, this.center.y, 0), gp_Dir(0, 0, 1), gp_Dir(cos(this.rotation), sin(this.rotation), 0)), this.size.x, this.size.y),
      (if this.direction == counterclockwise: this.startAngle else: this.endAngle),
      (if this.direction == counterclockwise: this.endAngle else: this.startAngle),
    ).edge



Curve2.implementInterfaceFor(EllipseArc2)


when isMainModule:
  block:
    # rotation: point at parametric angle 0 is at center + rotated x semi-axis
    let arc = ellipseArc(point2(1, 1), v2(4, 2), rotation = Pi/2)
    doAssert arc.pointAtParam(0).distanceTo(point2(1, 1) + v2(0, 2)) < 1e-9
    let arc2 = ellipseArc(point2(0, 0), v2(4, 2), xAxis = v2(0, 3))
    doAssert arc2.pointAtParam(0).distanceTo(point2(0, 2)) < 1e-9
  echo "rotation ok"

  block:
    # cut invariant: cut(a, b).pointAtParam(t) == original.pointAtParam(a + t * (b - a))
    for dir in [counterclockwise, clockwise]:
      for rotation in [0.0, Pi/6, -2*Pi/3]:
        for (sa, ea) in [(0.0, 0.0), (Pi/2, Pi), (Pi, Pi/2), (-3*Pi/4, Pi/4)]:
          let arc = ellipseArc(point2(1, 2), v2(6, 2), sa, ea, dir, rotation)
          for (a, b) in [(0.0, 1.0), (0.25, 0.75), (0.75, 0.25), (0.9, 0.1), (1.0, 0.0)]:
            let c = arc.cut(a, b)
            for t in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]:
              let got = c.pointAtParam(t)
              let expected = arc.pointAtParam(a + t * (b - a))
              doAssert got.distanceTo(expected) < 1e-9,
                "cut mismatch: dir=" & $dir & " rotation=" & $rotation &
                " sa=" & $sa & " ea=" & $ea & " a=" & $a & " b=" & $b & " t=" & $t
  echo "cut invariant ok"

  block:
    # derAtParam matches finite differences
    for dir in [counterclockwise, clockwise]:
      for rotation in [0.0, Pi/6, -2*Pi/3]:
        for (sa, ea) in [(0.0, 0.0), (Pi/2, Pi), (-3*Pi/4, Pi/4)]:
          let arc = ellipseArc(point2(1, 2), v2(6, 2), sa, ea, dir, rotation)
          for t in [0.1, 0.4, 0.9]:
            const eps = 1e-6
            let numeric = (arc.pointAtParam(t + eps) - arc.pointAtParam(t - eps)) / (2 * eps)
            doAssert (arc.derAtParam(t) - numeric).length < 1e-5,
              "der mismatch: dir=" & $dir & " rotation=" & $rotation & " sa=" & $sa & " ea=" & $ea & " t=" & $t
  echo "derAtParam ok"

  block:
    # bounds of a rotated arc: contains all sampled points and is tight
    for rotation in [0.0, Pi/6, -2*Pi/3, Pi/2]:
      for (sa, ea) in [(0.0, 0.0), (Pi/2, Pi), (-3*Pi/4, Pi/4)]:
        for (a, b) in [(0.0, 1.0), (0.1, 0.7)]:
          let arc = ellipseArc(point2(1, 2), v2(6, 2), sa, ea, rotation = rotation)
          let bb = arc.bounds(a, b)
          var sampled = bounds2(arc.pointAtParam(a))
          const n = 2000
          for i in 0..n:
            let p = arc.pointAtParam(a + i / n * (b - a))
            doAssert bb.contains(p, 1e-9), "point outside bounds: rotation=" & $rotation
            sampled.add p
          doAssert sampled.min.distanceTo(bb.min) < 1e-3, "bounds not tight"
          doAssert sampled.max.distanceTo(bb.max) < 1e-3, "bounds not tight"
  echo "bounds ok"
