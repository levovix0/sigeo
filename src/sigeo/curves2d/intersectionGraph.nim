import std/[algorithm, tables, hashes, math]
import ../core/[vectors, points, bounds]
import ./[icurve2d, lineSection, circleArc, intersections]


## Efficient intersection finding for many curves of different kinds, with a given precision.
##
## The result is represented as a graph:
##  - nodes are points where curves intersect (or start/end), each node knows all (curve, param)
##    pairs that map to its position
##  - edges are pieces of curves between adjacent nodes, directed in the increasing param direction


type
  CurvePoint* = tuple[curve: int, param: FloatParam]
    ## a point on a curve, referenced by curve index and param

  GraphNode* = object
    position*: Point2
    curvePoints*: seq[CurvePoint]
      ## all (curve, param) pairs that map to this position
    edges*: seq[int]
      ## indexes of edges that start or end at this node

  GraphEdge* = object
    ## a piece of a curve between two adjacent nodes
    ## directed in the increasing param direction (from `startParam` to `endParam`, `startParam < endParam`)
    curve*: int
    startNode*, endNode*: int
    startParam*, endParam*: FloatParam

  CurveGraph* = object
    curves*: seq[OwnedCurve2d]
    nodes*: seq[GraphNode]
    edges*: seq[GraphEdge]

  CurveIntersection* = object
    curveA*, curveB*: int
      ## indexes of the intersecting curves, `curveA < curveB`
    params*: FloatParam2


proc genericIntersectionPointsParams*(
  curveA, curveB: Curve2d,
  tolerance: Float = 1e-6,
): seq[FloatParam2] =
  ## finds intersection points of two arbitrary curves with the given precision
  ## by recursive subdivision of param ranges with bounding box pruning.
  ## returned params give points within `tolerance` of the true intersection.
  ## note: if curves overlap along a segment, points of that segment are not reported
  ## (only transversal and tangential intersections are)
  var raw: seq[tuple[a, b: Float]]
  var stack: seq[tuple[a0, a1, b0, b1: Float]] = @[(0.Float, 1.Float, 0.Float, 1.Float)]

  const minParamSpan = 1e-12
  var steps = 0
  const maxSteps = 1_000  # safety limit for pathological cases (e.g. almost-overlapping curves)

  while stack.len > 0 and steps < maxSteps:
    inc steps
    let (a0, a1, b0, b1) = stack.pop()

    let boxA = curveA.bounds(a0.FloatParam, a1.FloatParam)
    let boxB = curveB.bounds(b0.FloatParam, b1.FloatParam)
    if not boxA.overlaps(boxB, tolerance): continue

    let sa = max(boxA.size.x, boxA.size.y)
    let sb = max(boxB.size.x, boxB.size.y)

    if (sa <= tolerance and sb <= tolerance) or
       (a1 - a0 <= minParamSpan and b1 - b0 <= minParamSpan):
      raw.add (a: (a0 + a1) / 2, b: (b0 + b1) / 2)
    elif (sa >= sb and a1 - a0 > minParamSpan) or b1 - b0 <= minParamSpan:
      let m = (a0 + a1) / 2
      stack.add (a0, m, b0, b1)
      stack.add (m, a1, b0, b1)
    else:
      let m = (b0 + b1) / 2
      stack.add (a0, a1, b0, m)
      stack.add (a0, a1, m, b1)

  if raw.len == 0: return

  # neighboring leaf cells report the same intersection multiple times,
  # cluster raw hits that are adjacent in param space and average them
  raw.sort
  let paramTolA = 4 * tolerance / max(curveA.length, tolerance)
  let paramTolB = 4 * tolerance / max(curveB.length, tolerance)

  proc wrapDist(x, y: Float): Float =
    # distance in param space of a possibly closed curve (param 0 and 1 may be the same point)
    let d = abs(x - y)
    min(d, 1 - d)

  var positions: seq[Point2]
  var i = 0
  while i < raw.len:
    var j = i
    while j + 1 < raw.len and
          raw[j + 1].a - raw[j].a <= paramTolA and
          wrapDist(raw[j + 1].b, raw[j].b) <= paramTolB:
      inc j
    let mid = raw[(i + j) div 2]
    i = j + 1

    # on closed curves params near 0 and near 1 map to the same point,
    # producing clusters that are far in param space but spatially identical — drop those
    let p: FloatParam2 = (curveA: mid.a.FloatParam, curveB: mid.b.FloatParam)
    let pos = curveA.pointAtParam(p.curveA)
    var isDuplicate = false
    for other in positions:
      if other.distanceTo(pos) <= 4 * tolerance:
        isDuplicate = true
        break
    if not isDuplicate:
      positions.add pos
      result.add p


const lineSectionTypenameHash = hash("LineSection")
const circleArcTypenameHash = hash("CircleArc")

proc intersectionPointsParams*(
  curveA, curveB: Curve2d,
  tolerance: Float = 1e-6,
): seq[FloatParam2] =
  ## finds intersection points of two arbitrary curves with the given precision.
  ## dispatches to exact analytic intersections for known curve type pairs,
  ## falls back to `genericIntersectionPointsParams` otherwise
  let ha = curveA.vtable.typenameHash
  let hb = curveB.vtable.typenameHash

  if ha == lineSectionTypenameHash and hb == lineSectionTypenameHash:
    intersectionPointsParams(
      cast[ptr LineSection](curveA.obj)[],
      cast[ptr LineSection](curveB.obj)[],
    )
  elif ha == lineSectionTypenameHash and hb == circleArcTypenameHash:
    intersectionPointsParams(
      cast[ptr LineSection](curveA.obj)[],
      cast[ptr CircleArc](curveB.obj)[],
    )
  elif ha == circleArcTypenameHash and hb == lineSectionTypenameHash:
    var r: seq[FloatParam2]
    for p in intersectionPointsParams(
      cast[ptr LineSection](curveB.obj)[],
      cast[ptr CircleArc](curveA.obj)[],
    ):
      r.add (curveA: p.curveB, curveB: p.curveA)
    r
  else:
    genericIntersectionPointsParams(curveA, curveB, tolerance)


proc allIntersections*(
  curves: openArray[Curve2d],
  tolerance: Float = 1e-6,
): seq[CurveIntersection] =
  ## finds all pairwise intersection points of the given curves with the given precision.
  ## uses sweep-and-prune on bounding bounds to avoid checking every pair
  let n = curves.len
  var bounds = newSeq[Bounds2](n)
  for i in 0..<n:
    bounds[i] = curves[i].bounds

  var order = newSeq[int](n)
  for i in 0..<n: order[i] = i
  order.sort proc (a, b: int): int = cmp(bounds[a].min.x, bounds[b].min.x)

  var active: seq[int]
  for idx in order:
    var j = 0
    while j < active.len:
      if bounds[active[j]].max.x < bounds[idx].min.x - tolerance:
        active.del j  # unordered delete
      else:
        inc j

    for other in active:
      if bounds[idx].overlaps(bounds[other], tolerance):
        let (i1, i2) = (min(idx, other), max(idx, other))
        for p in intersectionPointsParams(curves[i1], curves[i2], tolerance):
          result.add CurveIntersection(curveA: i1, curveB: i2, params: p)

    active.add idx


proc buildIntersectionGraph*(
  curves: sink seq[OwnedCurve2d],
  tolerance: Float = 1e-6,
): CurveGraph =
  ## finds all intersections between the given curves and builds a graph of them.
  ## nodes are intersection points and curve endpoints; positions closer than
  ## `tolerance` are merged into a single node.
  ## edges are pieces of curves between adjacent nodes (see `GraphEdge`)
  result.curves = curves
  let n = result.curves.len

  var views = newSeq[Curve2d](n)
  for i in 0..<n:
    views[i] = result.curves[i].asPtr

  # collect params of interest for every curve: endpoints + intersections
  var params = newSeq[seq[Float]](n)
  for i in 0..<n:
    params[i] = @[0.Float, 1.Float]

  for inter in allIntersections(views, tolerance):
    params[inter.curveA].add inter.params.curveA.Float
    params[inter.curveB].add inter.params.curveB.Float

  # spatial hash for merging nodes closer than tolerance
  let cell = max(tolerance, 1e-12) * 2
  var grid: Table[(int64, int64), seq[int]]

  proc cellOf(p: Point2): (int64, int64) =
    (int64(floor(p.x / cell)), int64(floor(p.y / cell)))

  proc nodeAt(graph: var CurveGraph, p: Point2): int =
    let c = cellOf(p)
    for dx in -1'i64..1'i64:
      for dy in -1'i64..1'i64:
        for id in grid.getOrDefault((c[0] + dx, c[1] + dy)):
          if graph.nodes[id].position.distanceTo(p) <= tolerance:
            return id
    result = graph.nodes.len
    graph.nodes.add GraphNode(position: p)
    grid.mgetOrPut(c, @[]).add result

  for i in 0..<n:
    sort params[i]

    let paramTol = tolerance / max(views[i].length, tolerance)

    # deduplicate params that are closer than tolerance along the curve;
    # clusters containing an endpoint snap to it, others are averaged
    var merged: seq[Float]
    var j = 0
    while j < params[i].len:
      var k = j
      var sum = params[i][j]
      while k + 1 < params[i].len and params[i][k + 1] - params[i][k] <= paramTol:
        inc k
        sum += params[i][k]
      if params[i][j] <= 0: merged.add 0
      elif params[i][k] >= 1: merged.add 1
      else: merged.add sum / Float(k - j + 1)
      j = k + 1

    # create nodes and edges
    var nodeIds = newSeq[int](merged.len)
    for j, t in merged:
      nodeIds[j] = nodeAt(result, views[i].pointAtParam(t.FloatParam))
      result.nodes[nodeIds[j]].curvePoints.add (curve: i, param: t.FloatParam)

    for j in 0..<merged.len - 1:
      let e = result.edges.len
      result.edges.add GraphEdge(
        curve: i,
        startNode: nodeIds[j], endNode: nodeIds[j + 1],
        startParam: merged[j].FloatParam, endParam: merged[j + 1].FloatParam,
      )
      result.nodes[nodeIds[j]].edges.add e
      if nodeIds[j + 1] != nodeIds[j]:
        result.nodes[nodeIds[j + 1]].edges.add e


iterator adjacentEdges*(graph: CurveGraph, node: int): tuple[edge: int, forward: bool] =
  ## yields all edges incident to `node` with their direction
  ## (forward = true if the edge starts at `node` in the increasing param direction).
  ## an edge that is a loop (starts and ends at `node`) is yielded twice
  for e in graph.nodes[node].edges:
    if graph.edges[e].startNode == node: yield (e, true)
    if graph.edges[e].endNode == node: yield (e, false)


proc otherNode*(edge: GraphEdge, node: int): int =
  ## the node on the other end of the edge
  if edge.startNode == node: edge.endNode else: edge.startNode


proc pointOnEdge*(graph: CurveGraph, edge: int, t: FloatParam): Point2 =
  ## point on the edge's curve piece, t = 0 is the edge's start node, t = 1 is the end node
  let e = graph.edges[edge]
  graph.curves[e.curve].pointAtParam(
    (e.startParam.Float + t.Float * (e.endParam.Float - e.startParam.Float)).FloatParam
  )


proc edgeLength*(graph: CurveGraph, edge: int): Float =
  ## approximate length of the curve piece the edge represents
  let e = graph.edges[edge]
  graph.curves[e.curve].length * (e.endParam.Float - e.startParam.Float)


when isMainModule:
  import print
  import ./ellipseArc

  print "\n\ngeneric intersection: CircleArc <-> CircleArc"

  block:
    let a = circleArc(point2(0, 0), 1, 0, 0)
    let b = circleArc(point2(1, 0), 1, 0, 0)
    let pts = genericIntersectionPointsParams(a.toCurve2d, b.toCurve2d, 1e-9)
    print pts
    for p in pts:
      print a.pointAtParam(p.curveA)  # around (0.5, ±sqrt(3)/2)
      assert a.pointAtParam(p.curveA).distanceTo(b.pointAtParam(p.curveB)) < 1e-8

  print "\n\ngeneric intersection: LineSection <-> EllipseArc"

  block:
    let line = lineSection(point2(-2, 0.0), point2(2, 0.0))
    let ellipse = ellipseArc(point2(0, 0), v2(3, 1))
    let pts = genericIntersectionPointsParams(line.toCurve2d, ellipse.toCurve2d, 1e-9)
    print pts
    for p in pts:
      print line.pointAtParam(p.curveA)  # (±1.5, 0)
      assert line.pointAtParam(p.curveA).distanceTo(ellipse.pointAtParam(p.curveB)) < 1e-8

  print "\n\ndispatch to analytic intersection"

  block:
    let a = lineSection(point2(0, 0), point2(2, 2))
    let b = lineSection(point2(0, 2), point2(2, 0))
    print intersectionPointsParams(a.toCurve2d, b.toCurve2d)

  print "\n\nintersection graph"

  block:
    # a triangle of lines, a circle crossing it, and a far away line
    var curves: seq[OwnedCurve2d]
    curves.add lineSection(point2(0, 0), point2(4, 0)).toOwnedCurve2d
    curves.add lineSection(point2(4, 0), point2(2, 3)).toOwnedCurve2d
    curves.add lineSection(point2(2, 3), point2(0, 0)).toOwnedCurve2d
    curves.add circleArc(point2(2, 0), 1).toOwnedCurve2d
    curves.add lineSection(point2(100, 100), point2(101, 101)).toOwnedCurve2d

    let graph = buildIntersectionGraph(curves, 1e-9)

    print graph.nodes.len
    print graph.edges.len

    for i, node in graph.nodes:
      print i, node.position, node.curvePoints

    for i, edge in graph.edges:
      print i, edge

    # triangle corners merge endpoint nodes: each corner node has 2 curvePoints
    var cornerNodes = 0
    for node in graph.nodes:
      if node.curvePoints.len >= 2 and node.edges.len >= 2:
        inc cornerNodes
    assert cornerNodes >= 3

    # circle intersects the bottom line twice
    var circleLineIntersections = 0
    for node in graph.nodes:
      var hasCircle, hasBottom = false
      for cp in node.curvePoints:
        if cp.curve == 3: hasCircle = true
        if cp.curve == 0: hasBottom = true
      if hasCircle and hasBottom: inc circleLineIntersections
    assert circleLineIntersections == 2

    # walk the graph: every edge end must be consistent
    for i, edge in graph.edges:
      assert i in graph.nodes[edge.startNode].edges
      assert i in graph.nodes[edge.endNode].edges
      assert graph.pointOnEdge(i, 0.FloatParam).distanceTo(graph.nodes[edge.startNode].position) < 1e-6
      assert graph.pointOnEdge(i, 1.FloatParam).distanceTo(graph.nodes[edge.endNode].position) < 1e-6

  echo "ok"
