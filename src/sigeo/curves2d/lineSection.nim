import ../core/[vectors, points]
import ../macros/[genAliases]

type
  LineSection* = object
    ## a kind of 2d curve
    ## guarnteed to have non-zero length
    startPoint*, endPoint*: Point2


proc lineSection*(startPoint, endPoint: Point2): LineSection =
  if startPoint ~== endPoint:
    when defined(sigeo_return_small_curve_when_costructed_curve_has_zero_length):
      return LineSection(
        startPoint: startPoint,
        endPoint: startPoint + vec2(1e-6, 0)
      )
    
    elif true or defined(sigeo_raise_exception_when_costructed_curve_has_zero_length):
      raise ValueError.newException("Cannot construct curve with zero length")
  
  LineSection(
    startPoint: startPoint,
    endPoint: endPoint
  )
  

proc toVec*(line: LineSection): Vec2 =
  ## retruns vector from start point to end point
  line.endPoint - line.startPoint


proc pointAtParam*(line: LineSection, param: FloatParam): Point2 =
  line.startPoint + (line.endPoint - line.startPoint) * param


proc length*(line: LineSection): Float =
  (line.endPoint - line.startPoint).length


proc paramLength*(line: LineSection): Float {.deprecated: "always 1".} =
  1


proc paramAtPoint*(line: LineSection, point: Point2): FloatParam =
  ## returns arbitrary number `t` such that line.pointAtParam(`t`) returns `point`
  ## assumes that `point` is on line
  let v = (line.endPoint - line.startPoint)
  if abs(v.x) > abs(v.y):
    FloatParam (point.x - line.startPoint.x) / v.x
  else:
    FloatParam (point.y - line.startPoint.y) / v.y


proc direction*(line: LineSection): Vec2 =
  line.toVec.normalize


proc fastHasPoint*(line: LineSection, point: Point2): bool =
  ## returns true if `point` is on line section, assuming point is on line
  let p = line.paramAtPoint(point).Float
  p.almostEqualOrGreater(0) and p.almostEqualOrLess(1)

proc hasPoint*(line: LineSection, point: Point2): bool =
  ## returns true if `point` is on line section
  let avy = (line.endPoint - line.startPoint).rotate_90deg_counterClockwise
  if not((point - line.startPoint).dot(avy) ~== 0): return false
  line.fastHasPoint(point)


proc isParallel*(lineA, lineB: LineSection): bool =
  lineA.toVec.isParallel(lineB.toVec)

proc isPerpendicular*(lineA, lineB: LineSection): bool =
  lineA.toVec.isPerpendicular(lineB.toVec)

proc isCollinear*(lineA, lineB: LineSection): bool =
  let avy = lineA.toVec.rotate_90deg_counterClockwise
  (lineB.startPoint - lineA.startPoint).dot(avy) ~== 0 and
  (lineB.endPoint - lineA.startPoint).dot(avy) ~== 0


proc almostEqual*(lineA, lineB: LineSection): bool {.aliases: [`~==`].} =
  lineA.startPoint.almostEqual(lineB.startPoint) and lineA.endPoint.almostEqual(lineB.endPoint) or
  lineA.startPoint.almostEqual(lineB.endPoint) and lineA.endPoint.almostEqual(lineB.startPoint)

