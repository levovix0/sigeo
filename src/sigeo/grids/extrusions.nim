## polygonal grid extrusions

import std/[sequtils]
import ../core/[vectors, points, placement]

type
  Sag* = Float
    ## the minimal distance of the curvature

  GridKind* = enum
    Triangles
    TriangleStrip
    TriangleFan
    Quads

  Grid3* = object
    ## interconnected discrete 3d shell
    kind*: GridKind
    points*: seq[Point3]
    indices*: seq[int32]
  

  Curve3d* = object
    ## todo: replace with proper interface-based Curve3d
    speedAtParam*: proc(param: FloatParam): Float
    pointAtParam*: proc(param: FloatParam): Point3
    derAtParam*: proc(param: FloatParam): NormalVec3
    xAxisAtParam*: proc(param: FloatParam): NormalVec3


const defaultSag = 0.1.Sag


proc placementAtParam*(curve: Curve3d, t: FloatParam): Placement =
  placement(curve.derAtParam(t), curve.pointAtParam(t), curve.xAxisAtParam(t))

proc closed*(curve: Curve3d): bool =
  curve.pointAtParam(0) ~== curve.pointAtParam(1)



iterator discretePoints*(curve: Curve3d, sag: Sag = defaultSag, startPoint = true, endPoint = true): Point3 =
  var t = 0.Float
  if not startPoint: t += curve.speedAtParam(0.FloatParam) * sag
  while t ~< 1.Float:
    yield curve.pointAtParam(t.FloatParam)
    t += curve.speedAtParam(t.FloatParam) * sag
  if endPoint: yield curve.pointAtParam(1.FloatParam)


iterator discretePlacements*(curve: Curve3d, sag: Sag = defaultSag, startPoint = true, endPoint = true): Placement =
  ## todo: implement sag-based curve discretisation
  var t = 0.Float
  if not startPoint: t += curve.speedAtParam(0.FloatParam) * sag
  while t ~< 1.Float:
    yield curve.placementAtParam(t.FloatParam)
    t += curve.speedAtParam(t.FloatParam) * sag
  if endPoint: yield curve.placementAtParam(1.FloatParam)



proc extrusionShellGrid*(
  contour: openArray[Point3],
  contourClosed: bool,
  spine: Curve3d,
  sag: Sag = defaultSag,
): Grid3 =
  result.kind = Quads

  let plane = spine.placementAtParam(0)
  let bastMat = plane.toMatrix.inverse
  result.points.add contour

  var idxStart = 0'i32
  let count = contour.len.int32
  
  for place in spine.discretePlacements(sag, startPoint = false, endPoint = spine.closed.not):
    let mat = place.toMatrix * bastMat
    
    for cpt in contour:
      result.points.add((mat * cpt.Vec3).Point3)

      if contourClosed:
        for idx in 0'i32 .. count - 1:
          result.indices.add [
            idxStart + idx,
            idxStart + (idx + 1) mod count,
            idxStart + (idx + 1) mod count + count,
            idxStart + idx + count,
          ]
      else:
        for idx in 0'i32 .. count - 2:
          result.indices.add [
            idxStart + idx,
            idxStart + idx + 1,
            idxStart + idx + 1 + count,
            idxStart + idx + count,
          ]
    
    idxStart += count




proc extrusionShellGrid*(
  contour: Curve3d,
  spine: Curve3d,
  sag: Sag = defaultSag,
): Grid3 =
  extrusionShellGrid(contour.discretePoints(sag, endPoint = contour.closed.not).toSeq, contour.closed, spine, sag)



proc triangulate*(grid: sink Grid3): Grid3 =
  result = move grid

  if result.kind == Quads:
    var indices = move result.indices
    for i in countup(0, indices.high, 4):
      result.indices.add [indices[i], indices[i+1], indices[i+2], indices[i], indices[i+2], indices[i+3]]
    result.kind = Triangles

