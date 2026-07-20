import std/[sequtils, algorithm]
import ../core/[vectors, points, bounds2]
import ../curves2d/[icurve2]
import ./[isurface3]

type
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


proc triangulate*(grid: sink Grid3): Grid3 =
  result = move grid

  if result.kind == Quads:
    var indices = move result.indices
    result.indices = newSeqOfCap[int32]((indices.high div 4) * 6)
    for i in countup(0, indices.high, 4):
      result.indices.add [indices[i], indices[i+1], indices[i+2], indices[i], indices[i+2], indices[i+3]]
    result.kind = Triangles


proc computeVertexNormals*(vertices: openArray[Point3], indices: openArray[int]): seq[V3] =
  result = newSeq[V3](vertices.len)

  for i in countup(0, indices.high, 3):
    let a = vertices[indices[i]]
    let b = vertices[indices[i+1]]
    let c = vertices[indices[i+2]]
    var n = cross(b - a, c - a)
    result[indices[i]] += n
    result[indices[i+1]] += n
    result[indices[i+2]] += n

  for i, v in result.mpairs:
    v = v.normalize


proc brepContains(brep: openArray[Curve2], p: Point2): bool =
  var c = 0
  
  # todo: intersections at same endpoints of multiple curves
  
  for curve in brep:
    for param in curve.xAxisIntersection(p.y):
      let curvePt = curve.pointAt(param)
      if curvePt.x < p.x: inc c
  c mod 2 == 1



proc makeGrid*(surface: Surface3, brep: openArray[Curve2], minU, minV, maxU, maxV, stepU, stepV: Float): Grid3 =
  result.kind = Quads

  assert minU <= maxU
  assert minV <= maxV

  let uCount = ((maxU - minU) / stepU).ceil.int
  let vCount = ((maxV - minV) / stepV).ceil.int
  if uCount * vCount <= 0: return

  var grid = newSeqOfCap[int32]((uCount + 2) * (vCount + 2))  # (uI * vCount + vI) -> (-1 if not in grid, index of the point in grid otherwise)
  template `[]`(grid: seq[int32], uI, vI: int): int32 = grid[(uI + 1) * (vCount + 2) + vI + 1]
  template exists(i: int32): bool = i >= 0

  for _ in 0..<(uCount+2): grid.add -1

  for uI in 0..<uCount:
    let u = minU + stepU * uI.Float
    grid.add -1
    for vI in 0..<vCount:
      let v = minV + stepV * vI.Float
      let vert = point2(u, v)
      if brep.brepContains(vert):
        grid.add result.points.len.int32
        result.points.add surface.pointAt(vert)
      else:
        grid.add -1
    grid.add -1

  for _ in 0..<(uCount+2): grid.add -1

  for uI in 0..<uCount:
    let u = minU + stepU * uI.Float
    var pts: seq[Point2]
    for curve in brep:
      for param in curve.yAxisIntersection(u):
        pts.add curve.pointAt(param)
    sort pts, proc(a, b: Point2): int = cmp(a.y, b.y)
    for ptI, pt in pts:
      let vIf = (pt.y - minV) / stepV
      let vI = (if ptI mod 2 == 0: vIf.floor.int else: vIf.ceil.int)
      if not grid[uI, vI].exists:
        grid[uI, vI] = result.points.len.int32
        result.points.add surface.pointAt(pt)
      else:
        result.points[grid[uI, vI]] = surface.pointAt(pt)
  
  for vI in 0..<vCount:
    let v = minV + stepV * vI.Float
    var pts: seq[Point2]
    for curve in brep:
      for param in curve.xAxisIntersection(v):
        pts.add curve.pointAt(param)
    sort pts, proc(a, b: Point2): int = cmp(a.x, b.x)
    for ptI, pt in pts:
      let uIf = (pt.x - minU) / stepU
      let uI = (if ptI mod 2 == 0: uIf.floor.int else: uIf.ceil.int)
      if not grid[uI, vI].exists:
        grid[uI, vI] = result.points.len.int32
        result.points.add surface.pointAt(pt)
      else:
        result.points[grid[uI, vI]] = surface.pointAt(pt)

  # todo: fix "courner" borders
  
  for uI in -1..<uCount:
    for vI in -1..<vCount:
      if grid[uI, vI].exists and grid[uI + 1, vI].exists and grid[uI + 1, vI + 1].exists and grid[uI, vI + 1].exists:
        result.indices.add [grid[uI, vI], grid[uI + 1, vI], grid[uI + 1, vI + 1], grid[uI, vI + 1]]


proc makeGrid*(surface: Surface3, brep: openArray[Curve2], stepU, stepV: Float): Grid3 =
  let bounds = brep.mapIt(it.bounds).sum
  makeGrid(surface, brep, bounds.min.x, bounds.min.y, bounds.max.x, bounds.max.y, stepU, stepV)

proc makeGrid*(surface: Surface3, brep: openArray[Curve2], resolution = 16): Grid3 =
  let bounds = brep.mapIt(it.bounds).sum
  let stepU = bounds.size.x / resolution.Float
  let stepV = bounds.size.y / resolution.Float
  makeGrid(surface, brep, bounds.min.x, bounds.min.y, bounds.max.x, bounds.max.y, stepU, stepV)


