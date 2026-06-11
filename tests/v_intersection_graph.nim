## Visual test: generates many random curves (line sections, circle arcs, ellipse arcs),
## builds the intersection graph and displays it.
## Every graph edge (a piece of a curve between adjacent nodes) is drawn in its own color,
## so a single curve changes color at every intersection.
## Nodes: red = intersection of different curves, green = curve endpoint, white = both.
##
## [Space] — regenerate with new random curves.

import std/[math, random]
import pkg/[siwin, chroma]
import rice
import sigeo/[core, curves2d]
import ./[drawutils]

const
  nCurves   = 60
  margin    = 30.0
  winSize   = 800
  tolerance = 1e-6

let app = newVisualTest(
  title = "sigeo intersection graph — [Space] regenerate",
  size = ivec2(winSize, winSize),
  contentCenter = vec2(winSize / 2, winSize / 2),
)


proc randomCurves(): seq[OwnedCurve2d] =
  let lo = margin.Float
  let hi = winSize.Float - margin.Float

  for i in 0..<nCurves:
    case rand(0..2)
    of 0:
      let a = point2(rand(lo..hi), rand(lo..hi))
      let angle = rand(0.0..2*Pi)
      let len = rand(120.0..420.0)
      result.add lineSection(a, a + len * v2(cos(angle), sin(angle))).toOwnedCurve2d
    of 1:
      result.add circleArc(
        point2(rand(lo..hi), rand(lo..hi)),
        rand(50.0..200.0),
        rand(-Pi..Pi), (if rand(1.0) < 0.3: 0.0 else: rand(-Pi..Pi)),
        (if rand(1.0) < 0.5: counterclockwise else: clockwise),
      ).toOwnedCurve2d
    else:
      result.add ellipseArc(
        point2(rand(lo..hi), rand(lo..hi)),
        v2(rand(40.0..180.0), rand(40.0..180.0)),
        rand(-Pi..Pi), (if rand(1.0) < 0.3: 0.0 else: rand(-Pi..Pi)),
        (if rand(1.0) < 0.5: counterclockwise else: clockwise),
      ).toOwnedCurve2d


var graph: CurveGraph

proc regenerate() =
  graph = buildIntersectionGraph(randomCurves(), tolerance)
  echo "curves: ", graph.curves.len, ", nodes: ", graph.nodes.len, ", edges: ", graph.edges.len


proc edgeColor(i: int): Color =
  let hue = (i.float * 360 * 1234567/7654) mod 360.0
  let value = 75 + 25 * ((i.float * 0.35) mod 1.0)
  hsv(hue, 75, value).color


proc edgePoints(edgeIdx: int): seq[Point2] =
  let nPoints = max(8, int(graph.edgeLength(edgeIdx) / 4))
  for i in 0..nPoints:
    result.add graph.pointOnEdge(edgeIdx, i / nPoints)


app.onKey proc(e: KeyEvent) =
  if e.pressed and e.key == Key.space:
    regenerate()
    redraw e.window


randomize()
regenerate()

app.run proc(ctx: DrawContext) =
  for i in 0..<graph.edges.len:
    ctx.drawPolyline(edgePoints(i), edgeColor(i), thickness = 1.5)

  for node in graph.nodes:
    var distinctCurves: seq[int]
    var hasEndpoint = false
    for cp in node.curvePoints:
      if cp.curve notin distinctCurves: distinctCurves.add cp.curve
      if cp.param.Float == 0 or cp.param.Float == 1: hasEndpoint = true
    let isIntersection = distinctCurves.len >= 2

    let nodeColor =
      if isIntersection and hasEndpoint: color(1.0, 1.0, 1.0)
      elif isIntersection:               color(1.0, 0.25, 0.3)
      else:                              color(0.2, 1.0, 0.4)

    ctx.drawDot(node.position, nodeColor, radius = (if isIntersection: 3'f32 else: 2'f32))
