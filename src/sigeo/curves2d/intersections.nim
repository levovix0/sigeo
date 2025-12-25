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



template maxIntersectionPoints*(a, b: LineSection): int =
  1

template maxIntersectionPoints*(a, b: CircleArc): int =
  2

template maxIntersectionPoints*(a: LineSection, b: CircleArc): int {.anyOrder.} =
  2


template maxIntersectionSegments*(a, b: LineSection): int =
  1

template maxIntersectionSegments*(a, b: CircleArc): int =
  2

template maxIntersectionSegments*(a: LineSection, b: CircleArc): int {.anyOrder.} =
  0



proc fastIntersectionPoint*(curveA: LineSection, curveB: LineSection): Point2 =
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



proc intersectionPoint*(curveA: LineSection, curveB: LineSection): Option[Point2] =
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
  curveA: LineSection,
  curveB: LineSection,
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
  curveA: LineSection,
  curveB: LineSection,
  segmentsCount: var int,
): array[maxIntersectionSegments(curveA, curveB), FloatParamSegment2] =
  let av = curveA.endPoint - curveA.startPoint
  let bv = curveB.endPoint - curveB.startPoint

  let avy = av.rotate_90deg_counterClockwise.normalize
    ## "yAxis" for curveA

  let bay = bv.dot(avy)

  if not(bay ~== 0): return

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



wrapIntersectionToReturnSeq(LineSection, LineSection)



when isMainModule:
  import print

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

