import std/[math, algorithm, tables]
import ../[core]
import ./[icurve2, lineSection, circleArc, ellipseArc, contours, intersectionGraph]


## Finding closed contours in a curve intersection graph.
##
## Parts of the graph that touch only at a single point, or are connected only by a single
## chain of edges, form separate contours. Such parts are exactly the non-trivial biconnected
## components of the graph: bridges and dead ends form trivial (single-edge) components,
## which can't be part of any loop and are dropped.
##
## Within a component, loops are found by tracing the faces of the planar subdivision:
## half-edges around every vert are sorted by departure angle, and every face is walked
## keeping it on the left. This makes inner faces counterclockwise (positive signed area)
## and the single outer face of every component clockwise.


# a half-edge is `edge * 2`, walked in the increasing param direction, or `edge * 2 + 1`, walked backwards

proc sourceVert(graph: CurveGraph, he: int): int =
  if (he and 1) == 0: graph.edges[he shr 1].startNode
  else: graph.edges[he shr 1].endNode

proc targetVert(graph: CurveGraph, he: int): int =
  if (he and 1) == 0: graph.edges[he shr 1].endNode
  else: graph.edges[he shr 1].startNode


proc departureAngle(graph: CurveGraph, he: int): Float =
  ## angle of the direction in which the half-edge leaves its source vert
  let base = graph.verts[graph.sourceVert(he)].position
  for eps in [1e-6, 1e-4, 1e-2, 0.1, 0.5]:
    let t = if (he and 1) == 0: eps else: 1 - eps
    let d = graph.pointOnEdge(he shr 1, t.FloatParam) - base
    if d.length > 1e-12: return d.signedAngleToPlusX
  0


proc biconnectedComponents(graph: CurveGraph): seq[seq[int]] =
  ## splits edges into biconnected components (iterative Tarjan with an edge stack).
  ## handles parallel edges; a self-loop edge forms its own component
  type DfsFrame = object
    vert: int
    nextEdge: int  # index into verts[vert].edges
    treeEdge: int  # edge we are currently descending through, -1 if none

  var disc = newSeq[int](graph.verts.len)
  var low = newSeq[int](graph.verts.len)
  for x in disc.mitems: x = -1
  var visitedEdge: Bitmask
  var edgeStack: seq[int]
  var time = 0

  for root in 0..<graph.verts.len:
    if disc[root] != -1: continue
    disc[root] = time; low[root] = time; inc time
    var frames = @[DfsFrame(vert: root, treeEdge: -1)]

    while frames.len > 0:
      let v = frames[^1].vert

      if frames[^1].treeEdge != -1:
        # just returned from a child
        let e = frames[^1].treeEdge
        frames[^1].treeEdge = -1
        let child = graph.edges[e].otherNode(v)
        low[v] = min(low[v], low[child])
        if low[child] >= disc[v]:
          # v is an articulation point (or the root): edges above e form a component
          var comp: seq[int]
          while true:
            let top = pop edgeStack
            comp.add top
            if top == e: break
          result.add comp

      var descended = false
      while frames[^1].nextEdge < graph.verts[v].edges.len:
        let e = graph.verts[v].edges[frames[^1].nextEdge]
        inc frames[^1].nextEdge
        if visitedEdge[e]: continue
        visitedEdge[e] = true
        if graph.edges[e].startNode == graph.edges[e].endNode:
          result.add @[e]  # self-loop
          continue
        let w = graph.edges[e].otherNode(v)
        edgeStack.add e
        if disc[w] == -1:
          disc[w] = time; low[w] = time; inc time
          frames[^1].treeEdge = e
          frames.add DfsFrame(vert: w, treeEdge: -1)
          descended = true
          break
        else:
          low[v] = min(low[v], disc[w])

      if not descended and frames[^1].treeEdge == -1:
        discard pop frames


proc faces(graph: CurveGraph, componentEdges: seq[int]): seq[seq[int]] =
  ## traces the faces of a planar component, returning every face as a closed
  ## sequence of half-edges that keeps the face on the left
  var rot: Table[int, seq[tuple[angle: Float, he: int]]]
    # half-edges leaving each vert, sorted counterclockwise
  var index: Table[int, int]
    # half-edge -> its position in the rotation around its source vert

  for e in componentEdges:
    for he in [e * 2, e * 2 + 1]:
      rot.mgetOrPut(graph.sourceVert(he), @[]).add (graph.departureAngle(he), he)
  for hes in rot.mvalues:
    sort hes
    for i, x in hes: index[x.he] = i

  var visited: Bitmask
  for e in componentEdges:
    for start in [e * 2, e * 2 + 1]:
      if visited[start]: continue
      var face: seq[int]
      var he = start
      while true:
        face.add he
        visited[he] = true
        # the next half-edge is the clockwise neighbour of the twin around the target vert
        let v = graph.targetVert(he)
        let i = index[he xor 1]
        let n = rot[v].len
        he = rot[v][(i + n - 1) mod n].he
        if he == start: break
      result.add face


proc approxFaceArea(graph: CurveGraph, face: seq[int], samples = 32): Float =
  ## approximate signed area of a face (positive if counterclockwise),
  ## computed from a polyline approximation
  var first, prev: Point2
  for k, he in face:
    for i in 0..<samples:
      let t = if (he and 1) == 0: i / samples else: 1 - i / samples
      let p = graph.pointOnEdge(he shr 1, t.FloatParam)
      if k == 0 and i == 0: first = p
      else: result += prev.x * p.y - p.x * prev.y
      prev = p
  result += prev.x * first.y - first.x * prev.y
  result /= 2


proc cutOwned(curve: Curve2, a, b: FloatParam): OwnedCurve2 =
  ## todo: move to interface
  if curve.isOf(LineSection): curve.castTo(LineSection).cut(a, b).toOwnedCurve2
  elif curve.isOf(CircleArc): curve.castTo(CircleArc).cut(a, b).toOwnedCurve2
  elif curve.isOf(EllipseArc): curve.castTo(EllipseArc).cut(a, b).toOwnedCurve2
  else: raise ValueError.newException("cutting this curve type is not supported")


proc toContour(graph: CurveGraph, face: seq[int]): Contour =
  ## cuts out the curve pieces the face passes through, in traversal direction
  for he in face:
    let edge = graph.edges[he shr 1]
    if (he and 1) == 0:
      result.curves.add cutOwned(graph.curves[edge.curve], edge.startParam, edge.endParam)
    else:
      result.curves.add cutOwned(graph.curves[edge.curve], edge.endParam, edge.startParam)


proc componentFaces(graph: CurveGraph): seq[tuple[faces: seq[seq[int]], outer: int]] =
  ## faces of every non-trivial biconnected component + index of its outer face
  for comp in graph.biconnectedComponents:
    if comp.len == 1 and graph.edges[comp[0]].startNode != graph.edges[comp[0]].endNode:
      continue  # a bridge, not part of any loop
    let fs = graph.faces(comp)
    var outer = 0
    var minArea = Inf
    for i, f in fs:
      let a = graph.approxFaceArea(f)
      if a < minArea: minArea = a; outer = i
    result.add (fs, outer)


proc outerContours*(graph: CurveGraph): seq[Contour] =
  ## finds the biggest closed loop of every independent part of the graph.
  ## parts that touch at a single point, or are connected only by a single chain
  ## of edges, are independent; bridges and dead ends are not part of any contour.
  ## returned contours are counterclockwise (positive signed area)
  for (fs, outer) in graph.componentFaces:
    var f = fs[outer]
    reverse f  # the outer face is clockwise, reverse it to match the inner ones
    for he in f.mitems: he = he xor 1
    result.add graph.toContour(f)


proc innerContours*(graph: CurveGraph): seq[Contour] =
  ## finds all smallest closed loops of the graph — the faces of its planar subdivision,
  ## not counting the outer face of every independent part (see `outerContours`).
  ## returned contours are counterclockwise (positive signed area)
  for (fs, outer) in graph.componentFaces:
    for i, f in fs:
      if i != outer:
        result.add graph.toContour(f)




when isMainModule:
  import print

  proc isClosed(c: Contour): bool =
    if c.curves.len == 0: return false
    for i in 0..<c.curves.len:
      let prev = c.pointAtCurve(i, 1)
      let next = c.pointAtCurve((i + 1) mod c.curves.len, 0)
      if prev.distanceTo(next) > 1e-6: return false
    true

  print "\n\n--- square with a diagonal ---"

  block:
    var curves: seq[OwnedCurve2]
    curves.add lineSection(point2(0, 0), point2(2, 0)).toOwnedCurve2
    curves.add lineSection(point2(2, 0), point2(2, 2)).toOwnedCurve2
    curves.add lineSection(point2(2, 2), point2(0, 2)).toOwnedCurve2
    curves.add lineSection(point2(0, 2), point2(0, 0)).toOwnedCurve2
    curves.add lineSection(point2(0, 0), point2(2, 2)).toOwnedCurve2

    let graph = buildIntersectionGraph(curves, 1e-9)

    let outer = graph.outerContours
    print outer.len
    assert outer.len == 1
    assert outer[0].curves.len == 4
    assert outer[0].isClosed
    assert abs(outer[0].approxSignedArea - 4) < 1e-6

    let inner = graph.innerContours
    print inner.len
    assert inner.len == 2
    for c in inner:
      assert c.curves.len == 3
      assert c.isClosed
      assert abs(c.approxSignedArea - 2) < 1e-6

  print "\n\n--- separated parts: shared vert, bridge, dead end, isolated curve, standalone circle ---"

  block:
    var curves: seq[OwnedCurve2]
    # two triangles sharing the vert (4, 0)
    curves.add lineSection(point2(0, 0), point2(4, 0)).toOwnedCurve2
    curves.add lineSection(point2(4, 0), point2(2, 3)).toOwnedCurve2
    curves.add lineSection(point2(2, 3), point2(0, 0)).toOwnedCurve2
    curves.add lineSection(point2(4, 0), point2(8, 0)).toOwnedCurve2
    curves.add lineSection(point2(8, 0), point2(6, 3)).toOwnedCurve2
    curves.add lineSection(point2(6, 3), point2(4, 0)).toOwnedCurve2
    # third triangle connected by a bridge
    curves.add lineSection(point2(8, 0), point2(10, 0)).toOwnedCurve2
    curves.add lineSection(point2(10, 0), point2(14, 0)).toOwnedCurve2
    curves.add lineSection(point2(14, 0), point2(12, 3)).toOwnedCurve2
    curves.add lineSection(point2(12, 3), point2(10, 0)).toOwnedCurve2
    # dead end and isolated curve
    curves.add lineSection(point2(2, 3), point2(2, 6)).toOwnedCurve2
    curves.add lineSection(point2(100, 100), point2(101, 101)).toOwnedCurve2
    # standalone circle (a self-loop in the graph)
    curves.add circleArc(point2(20, 0), 1).toOwnedCurve2

    let graph = buildIntersectionGraph(curves, 1e-9)

    let outer = graph.outerContours
    print outer.len
    assert outer.len == 4

    var triangles, circles = 0
    for c in outer:
      assert c.isClosed
      assert c.approxSignedArea > 0
      if abs(c.approxSignedArea - 6) < 1e-6: inc triangles      # triangle area
      if abs(c.approxSignedArea - Pi) < 0.05: inc circles       # circle area (polyline approximation)
    assert triangles == 3
    assert circles == 1

    let inner = graph.innerContours
    print inner.len
    assert inner.len == 4

  print "\n\n--- circle touching a square corner at a single point ---"

  block:
    var curves: seq[OwnedCurve2]
    curves.add lineSection(point2(0, 0), point2(2, 0)).toOwnedCurve2
    curves.add lineSection(point2(2, 0), point2(2, 2)).toOwnedCurve2
    curves.add lineSection(point2(2, 2), point2(0, 2)).toOwnedCurve2
    curves.add lineSection(point2(0, 2), point2(0, 0)).toOwnedCurve2
    curves.add circleArc(point2(-1, 2), 1).toOwnedCurve2  # starts (and ends) at the corner (0, 2)

    let graph = buildIntersectionGraph(curves, 1e-9)

    let outer = graph.outerContours
    print outer.len
    assert outer.len == 2

    let inner = graph.innerContours
    print inner.len
    assert inner.len == 2

    for c in outer & inner:
      assert c.isClosed
      assert c.approxSignedArea > 0

  echo "ok"
