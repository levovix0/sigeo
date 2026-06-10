import ../core/[vectors, points, buildutils]
import ./icurve2d

when sigeo_backend == SigeoOpencascade:
  import pkg/opencascade


type
  EllipseArc* = object
    ## a kind of 2d curve — an arc of an axis-aligned ellipse
    center*: Point2
    size*: V2
      ## full bounding box: width = 2*rx, height = 2*ry
    startAngle*, endAngle*: Float
      ## signed angle from +x to start/end point in radians
      ## if equal, the ellipse is full
      ## positive is counterclockwise, negative is clockwise
    direction*: AngleDirection


proc ellipseArc*(
  center: Point2, size: V2,
  startAngle: Float = 0, endAngle: Float = 0,
  direction: AngleDirection = counterclockwise
): EllipseArc =
  EllipseArc(
    center: center, size: size,
    startAngle: startAngle, endAngle: endAngle,
    direction: direction
  )


proc fullEllipse*(arc: EllipseArc): bool {.inline.} =
  arc.startAngle == arc.endAngle


proc angularLength*(arc: EllipseArc): Float =
  ## returns signed angular sweep of the arc in radians, `Pi*2` for full ellipse
  if arc.fullEllipse:
    case arc.direction
    of counterclockwise:  2 * Pi
    of clockwise:        -2 * Pi
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


proc length*(arc: EllipseArc): Float =
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


proc pointAtParam*(arc: EllipseArc, t: FloatParam): Point2 =
  let angle = arc.startAngle + Float(t) * arc.angularLength
  arc.center + v2(arc.size.x / 2 * cos(angle), arc.size.y / 2 * sin(angle))



when sigeo_backend == SigeoOpencascade:
  proc toOpencascadeShape*(this: EllipseArc;): TopoDS_Shape =
    bRepBuilderAPI_MakeEdge(
      gp_Elips(gp_Ax2(gp_Pnt(this.center.x, this.center.y, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)), this.size.x, this.size.y),
      (if this.direction == counterclockwise: this.startAngle else: this.endAngle),
      (if this.direction == counterclockwise: this.endAngle else: this.startAngle),
    ).edge



Curve2d.implementInterfaceFor(EllipseArc)
