import ../core/[vectors, points, bounds, buildutils]
import ../macros/[genAliases]
import ./[icurve2]

when sigeo_backend == SigeoOpencascade:
  import pkg/opencascade


type
  LineSection2* = object
    ## a kind of 2d curve
    ## guarnteed to have non-zero length
    startPoint*, endPoint*: Point2
  
  LineSection* {.deprecated: "renamed to LineSection2".} = LineSection2


proc lineSection2*(startPoint, endPoint: Point2): LineSection2 {.aliases: [lineSection].} =
  if startPoint ~== endPoint:
    when defined(sigeo_return_small_curve_when_costructed_curve_has_zero_length):
      return LineSection2(
        startPoint: startPoint,
        endPoint: startPoint + v2(1e-6, 0)
      )
    
    elif true or defined(sigeo_raise_exception_when_costructed_curve_has_zero_length):
      raise ValueError.newException("Cannot construct curve with zero length")
  
  LineSection2(
    startPoint: startPoint,
    endPoint: endPoint
  )
  

proc a*(line: LineSection2): Point2 = line.startPoint
proc b*(line: LineSection2): Point2 = line.endPoint



proc toVec*(line: LineSection2): V2 =
  ## retruns vector from start point to end point
  line.endPoint - line.startPoint


proc pointAtParam*(line: LineSection2, param: FloatParam): Point2 =
  line.startPoint + (line.endPoint - line.startPoint) * param


proc derAtParam*(line: LineSection2, param: FloatParam): V2 {.inline.} =
  line.toVec


proc length*(line: LineSection2): Float =
  (line.endPoint - line.startPoint).length


proc paramLength*(line: LineSection2): Float {.deprecated: "always 1".} =
  1


proc paramAtPoint*(line: LineSection2, point: Point2): FloatParam =
  ## returns arbitrary number `t` such that line.pointAtParam(`t`) returns `point`
  ## assumes that `point` is on line
  let v = (line.endPoint - line.startPoint)
  if abs(v.x) > abs(v.y):
    FloatParam (point.x - line.startPoint.x) / v.x
  else:
    FloatParam (point.y - line.startPoint.y) / v.y


proc direction*(line: LineSection2): V2 =
  line.toVec.normalize

proc center*(line: LineSection2): Point2 =
  line.startPoint + (line.endPoint - line.startPoint) / 2


proc fastHasPoint*(line: LineSection2, point: Point2): bool =
  ## returns true if `point` is on line section, assuming point is on line
  let p = line.paramAtPoint(point).Float
  p.almostEqualOrGreater(0) and p.almostEqualOrLess(1)

proc hasPoint*(line: LineSection2, point: Point2): bool =
  ## returns true if `point` is on line section
  let avy = (line.endPoint - line.startPoint).rotate_90deg_counterClockwise
  if not((point - line.startPoint).dot(avy) ~== 0): return false
  line.fastHasPoint(point)


proc isParallel*(lineA, lineB: LineSection2): bool =
  lineA.toVec.isParallel(lineB.toVec)

proc isPerpendicular*(lineA, lineB: LineSection2): bool =
  lineA.toVec.isPerpendicular(lineB.toVec)

proc isCollinear*(lineA, lineB: LineSection2): bool =
  let avy = lineA.toVec.rotate_90deg_counterClockwise
  (lineB.startPoint - lineA.startPoint).dot(avy) ~== 0 and
  (lineB.endPoint - lineA.startPoint).dot(avy) ~== 0


proc almostEqual*(lineA, lineB: LineSection2): bool {.aliases: [`~==`].} =
  lineA.startPoint.almostEqual(lineB.startPoint) and lineA.endPoint.almostEqual(lineB.endPoint) or
  lineA.startPoint.almostEqual(lineB.endPoint) and lineA.endPoint.almostEqual(lineB.startPoint)



proc cut*(curve: LineSection2, a, b: FloatParam): LineSection2 =
  LineSection2(startPoint: curve.pointAtParam(a), endPoint: curve.pointAtParam(b))

proc reverse*(curve: LineSection2): LineSection2 {.inline.} = curve.cut(1, 0)


proc bounds*(line: LineSection2, a, b: FloatParam): Bounds2 =
  ## bounding box of the part of the line section between params `a` and `b`
  bounds2(line.pointAtParam(a), line.pointAtParam(b))



when sigeo_backend == SigeoOpencascade:
  proc toOpencascadeShape*(this: LineSection2;): TopoDS_Shape =
    bRepBuilderAPI_MakeEdge(
      gp_Pnt(this.startPoint.x, this.startPoint.y, 0),
      gp_Pnt(this.endPoint.x, this.endPoint.y, 0)
    ).edge



Curve2.implementInterfaceFor(LineSection2)
