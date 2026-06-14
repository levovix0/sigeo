import std/[options]
import ../core/[vectors, points]
import ./[lineSection, circleArc]
import ../macros/[genAnyOrder]


type
  FloatParam2* = tuple[curveA, curveB: FloatParam]
    ## parameter for two curves (representing the same point)
  
  FloatParamSegment* = tuple[a, b: FloatParam]
    ## parameter combination that represents a continuous curve segment from a to b

  FloatParamSegment2* = tuple[curveA, curveB: FloatParamSegment]
    ## parameter segments for two curves (representing the same segment)




template wrapIntersectionToReturnSeq(t1, t2) =
  proc intersectionPointsParams*(curveA: t1, curveB: t2): seq[FloatParam2] =
    when maxIntersectionPoints(curveA, curveB) > 0:
      result.setLen(maxIntersectionPoints(curveA, curveB))
      var pointsCount = 0
      cast[ptr array[maxIntersectionPoints(curveA, curveB), FloatParam2]](result[0].addr)[] =
        intersectionPointsParams(curveA, curveB, pointsCount)
      result.setLen(pointsCount)

  proc intersectionSegmentsParams*(curveA: t1, curveB: t2): seq[FloatParamSegment2] =
    when maxIntersectionSegments(curveA, curveB) > 0:
      result.setLen(maxIntersectionSegments(curveA, curveB))
      var pointsCount = 0
      cast[ptr array[maxIntersectionSegments(curveA, curveB), FloatParamSegment2]](result[0].addr)[] =
        intersectionSegmentsParams(curveA, curveB, pointsCount)
      result.setLen(pointsCount)



template maxIntersectionPoints*(a, b: LineSection2): int =
  1

template maxIntersectionPoints*(a, b: CircleArc2): int =
  2

template maxIntersectionPoints*(a: LineSection2, b: CircleArc2): int {.anyOrder.} =
  2


template maxIntersectionSegments*(a, b: LineSection2): int =
  1

template maxIntersectionSegments*(a, b: CircleArc2): int =
  2

template maxIntersectionSegments*(a: LineSection2, b: CircleArc2): int {.anyOrder.} =
  0



proc fastIntersectionPoint*(curveA: LineSection2, curveB: LineSection2): Point2 =
  ## returns position of intersection point, assuming there is one
  let
    curveA_dir = curveA.direction
    curveB_dir = curveB.direction

  # solves for either aP or bP:
  #  ( curveA.startPoint.x + curveA_dir.x * aP  =  curveB.startPoint.x + curveB_dir.x * bP ) and
  #  ( curveA.startPoint.y + curveA_dir.y * aP  =  curveB.startPoint.y + curveB_dir.y * bP )
  
  let m = [
    [curveA_dir.x, -curveB_dir.x, curveA.startPoint.x - curveB.startPoint.x],
    [curveA_dir.y, -curveB_dir.y, curveA.startPoint.y - curveB.startPoint.y],
  ]
  
  if   m[0][0] ~== 0:
    if m[0][1] ~!= 0: (let bP = m[0][2] / m[0][1]; curveB.startPoint + curveB_dir * bP)
    else:             curveA.startPoint
  elif m[0][1] ~== 0:
    if m[0][0] ~!= 0: (let aP = m[0][2] / m[0][0]; curveA.startPoint + curveA_dir * aP)
    else:             curveA.startPoint
  elif m[1][0] ~== 0:
    if m[1][1] ~!= 0: (let bP = m[1][2] / m[1][1]; curveB.startPoint + curveB_dir * bP)
    else:             curveA.startPoint
  elif m[1][1] ~== 0:
    if m[1][0] ~!= 0: (let aP = m[1][2] / m[1][0]; curveA.startPoint + curveA_dir * aP)
    else:             curveA.startPoint
  else:
    let k = m[1][1] / m[0][1]
    let m00 = m[0][0] - m[1][0] * k
    let m02 = m[0][2] - m[1][2] * k
    if m00 ~!= 0:
      let aP = m02 / m00
      curveA.startPoint + curveA_dir * aP
    else:
      curveA.startPoint



proc intersectionPoint*(curveA: LineSection2, curveB: LineSection2): Option[Point2] =
  if isParallel(curveA.toVec, curveB.toVec):
    if curveB.hasPoint(curveA.startPoint): some curveA.startPoint
    elif curveB.hasPoint(curveA.endPoint): some curveA.endPoint
    elif curveA.hasPoint(curveB.startPoint): some curveB.startPoint
    else: none Point2
  else:
    let p = fastIntersectionPoint(curveA, curveB)
    if curveA.fastHasPoint(p) and curveB.fastHasPoint(p):
      some p
    else:
      none Point2




proc intersectionPointsParams*(
  curveA: LineSection2,
  curveB: LineSection2,
  pointsCount: var int,
): array[maxIntersectionPoints(curveA, curveB), FloatParam2] =
  ## returns all parameters for each curve at which the curves intersects
  let av = curveA.endPoint - curveA.startPoint
  let bv = curveB.endPoint - curveB.startPoint

  let avy = av.rotate_90deg_counterClockwise.normalize
    ## "yAxis" for curveA

  let bay = bv.dot(avy)

  if bay ~== 0:
    if curveA.startPoint ~== curveB.startPoint:
      if av.dot(bv) < 0:
        inc pointsCount
        result[0] = (curveA: 0.FloatParam, curveB: 0.FloatParam)
    
    elif curveA.startPoint ~== curveB.endPoint:
      if av.dot(bv) > 0:
        inc pointsCount
        result[0] = (curveA: 0.FloatParam, curveB: 1.FloatParam)
    
    elif curveA.endPoint ~== curveB.startPoint:
      if av.dot(bv) > 0:
        inc pointsCount
        result[0] = (curveA: 1.FloatParam, curveB: 0.FloatParam)
    
    elif curveA.endPoint ~== curveB.endPoint:
      if av.dot(bv) < 0:
        inc pointsCount
        result[0] = (curveA: 1.FloatParam, curveB: 1.FloatParam)
    
    return

  let bspld = (curveA.startPoint - curveB.startPoint).dot(avy)
    ## signed distance from curveB.startPoint to line of curveA (distance on y-axis)
  
  if (
    (bspld.sureLess(0) and bay > 0) or
    (bspld.sureGreater(0) and bay < 0) or
    (abs(bspld).sureGreater(abs(bay)))
  ):
    return  ## lines intersect, but not line segments

  let avx = av.normalize
    ## "xAxis" for curveA

  let bip = curveB.startPoint + bv * (bspld / bay)

  let bipx = (bip - curveA.startPoint).dot(avx)
  let bipex = (bip - curveA.endPoint).dot(avx)

  if bipx.sureLess(0) or bipex.sureGreater(0):
    return  ## point of intersection is not on curveA

  inc pointsCount
  result[0] = (curveA: (bipx / av.length).FloatParam, curveB: (bspld / bay).FloatParam)



proc intersectionSegmentsParams*(
  curveA: LineSection2,
  curveB: LineSection2,
  segmentsCount: var int,
): array[maxIntersectionSegments(curveA, curveB), FloatParamSegment2] =
  let av = curveA.endPoint - curveA.startPoint
  let bv = curveB.endPoint - curveB.startPoint

  let avy = av.rotate_90deg_counterClockwise.normalize
    ## "yAxis" for curveA

  let bay = bv.dot(avy)
  if not(bay ~== 0): return  # not parallel

  let bspld = (curveA.startPoint - curveB.startPoint).dot(avy)
  if not(bspld ~== 0): return  # parallel but not collinear

  result[0] = (
    curveA: (
      curveA.paramAtPoint(curveB.startPoint).Float.clamp(0.Float..1.Float).FloatParam,
      curveA.paramAtPoint(curveB.endPoint).Float.clamp(0.Float..1.Float).FloatParam,
    ),
    curveB: (
      curveB.paramAtPoint(curveA.startPoint).Float.clamp(0.Float..1.Float).FloatParam,
      curveB.paramAtPoint(curveA.endPoint).Float.clamp(0.Float..1.Float).FloatParam,
    )
  )
  
  if result[0].curveA.a ~== result[0].curveA.b or result[0].curveB.a ~== result[0].curveB.b:
    return

  inc segmentsCount



proc hasIntersectedSegments*(a, b: LineSection2): bool =
  var segmentsCount = 0
  discard intersectionSegmentsParams(a, b, segmentsCount)
  segmentsCount > 0


wrapIntersectionToReturnSeq(LineSection2, LineSection2)



proc intersectionPointsParams*(
  curveA: LineSection2,
  curveB: CircleArc2,
  pointsCount: var int,
): array[maxIntersectionPoints(curveA, curveB), FloatParam2] =
  let d = curveA.endPoint - curveA.startPoint
  let f = curveA.startPoint - curveB.center

  let qa = d.dot(d)
  let qb = 2 * f.dot(d)
  let qc = f.dot(f) - curveB.radius * curveB.radius

  let discriminant = qb * qb - 4 * qa * qc
  if discriminant.sureLess(0): return

  let sqrtDisc = sqrt(max(0.Float, discriminant))
  let angLen = curveB.angularLength

  template checkPoint(lineT: Float) {.dirty.} =
    block checkPointBlock:
      if lineT.sureLess(0) or lineT.sureGreater(1): break checkPointBlock

      let pv = curveA.startPoint + d * lineT
      let angle = arctan2((pv - curveB.center).y, (pv - curveB.center).x)

      var arcParam: Float
      if angLen > 0:
        let dist = ((angle - curveB.startAngle) mod (2 * PI) + 2 * PI) mod (2 * PI)
        if not curveB.fullCircle and dist.sureGreater(angLen): break checkPointBlock
        arcParam = dist / angLen
      else:
        let dist = -(((curveB.startAngle - angle) mod (2 * PI) + 2 * PI) mod (2 * PI))
        if not curveB.fullCircle and dist.sureLess(angLen): break checkPointBlock
        arcParam = dist / angLen

      result[pointsCount] = (curveA: lineT.FloatParam, curveB: arcParam.FloatParam)
      inc pointsCount

  if discriminant ~== 0:
    checkPoint((-qb) / (2 * qa))
  else:
    checkPoint((-qb - sqrtDisc) / (2 * qa))
    checkPoint((-qb + sqrtDisc) / (2 * qa))


wrapIntersectionToReturnSeq(LineSection2, CircleArc2)



when isMainModule:
  import print

  print "\n\nLineSection2 <-> LineSection2"

  block:
    print intersectionPointsParams(
      lineSection(point2(0, 0), point2(2, 2)),
      lineSection(point2(0, 1), point2(1, 0)),
    )

  block:
    print intersectionPointsParams(
      lineSection(point2(0, 0), point2(-2, -2)),
      lineSection(point2(0, -1), point2(-2, 0)),
    )

  block:
    let curveA = lineSection(point2(1, 1), point2(3, 3))

    let points = intersectionPointsParams(
      curveA,
      lineSection(point2(2, 2), point2(1, 3)),
    )
    print points
    print curveA.pointAtParam(points[0].curveA) ~== (curveA.startPoint + (curveA.endPoint - curveA.startPoint) / 2)

  block:
    print intersectionPointsParams(
      lineSection(point2(1, 1), point2(3, 3)),
      lineSection(point2(2 - 1e-6, 2 + 1e-6), point2(1, 3)),
    )

  block:
    print intersectionPointsParams(
      lineSection(point2(1, 2), point2(3, 6)),
      lineSection(point2(2, 4), point2(10, 20)),
    )
    print intersectionSegmentsParams(
      lineSection(point2(1, 2), point2(3, 6)),
      lineSection(point2(2, 4), point2(10, 20)),
    )
    print intersectionSegmentsParams(
      lineSection(point2(2, 4), point2(2.5, 5)),
      lineSection(point2(1, 2), point2(3, 6)),
    )
    print intersectionSegmentsParams(
      lineSection(point2(1, 2), point2(0, 0)),
      lineSection(point2(1, 2), point2(3, 6)),
    )
  
  block:
    print fastIntersectionPoint(
      lineSection(point2(0, 0), point2(2, 2)),
      lineSection(point2(0, 1), point2(1, 0)),
    )

  print "\n\nLineSection2 <-> CircleArc2"

  block:
    let arc = circleArc(point2(0, 0), 1, 0, PI)
    let pts = intersectionPointsParams(
      lineSection(point2(-2, 0.5), point2(2, 0.5)),
      arc,
    )
    print pts
    print arc.pointAtParam(pts[0].curveB)  # aroud (-sqrt(0.75), 0.5)
    print arc.pointAtParam(pts[1].curveB)  # aroud ( sqrt(0.75), 0.5)

  block:
    let arc = circleArc(point2(0, 0), 1, 0, PI / 2)
    print intersectionPointsParams(
      lineSection(point2(-2, -0.5), point2(2, -0.5)),
      arc,
    )  # should be empty

