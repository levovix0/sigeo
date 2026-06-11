## Visual test: generates many random curves (line sections, circle arcs, ellipse arcs),
## builds the intersection graph and displays it.
## Every graph edge (a piece of a curve between adjacent nodes) is drawn in its own color,
## so a single curve changes color at every intersection.
## Nodes: red = intersection of different curves, green = curve endpoint, white = both.
##
## [Space] — regenerate with new random curves.

import std/[math, random]
import pkg/[siwin, pixie]
import rice
import sigeo/[core, curves2d]

const
  nCurves   = 60
  margin    = 30'f32
  winSize   = 800
  tolerance = 1e-6

let win = newOpenglWindow(
  title = "sigeo intersection graph — [Space] regenerate",
  size = ivec2(winSize, winSize),
)
opengl.loadExtensions()
let ctx = newDrawContext()
var aafb = ctx.newAntialiasedFramebuffer(win.size)


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


proc edgeToPath(edgeIdx: int): Path =
  let nPoints = max(8, int(graph.edgeLength(edgeIdx) / 4))
  result = newPath()
  let p0 = graph.pointOnEdge(edgeIdx, 0)
  result.moveTo(p0.x.float32, p0.y.float32)
  for i in 1..nPoints:
    let p = graph.pointOnEdge(edgeIdx, i / nPoints)
    result.lineTo(p.x.float32, p.y.float32)

  # todo: rice wrongly draws non-closed paths
  for i in countdown(nPoints - 1, 0):
    let p = graph.pointOnEdge(edgeIdx, i / nPoints)
    result.lineTo(p.x.float32, p.y.float32)


win.eventsHandler.onResize = proc(e: ResizeEvent) =
  glViewport 0, 0, e.size.x.GlInt, e.size.y.GlInt
  ctx.resize(aafb, e.size)
  ctx.updateDrawingAreaSize(e.size)


win.eventsHandler.onKey = proc(e: KeyEvent) =
  if e.pressed and e.key == Key.space:
    regenerate()
    redraw e.window


win.eventsHandler.onRender = proc(e: RenderEvent) =
  let vw = e.window.size.x.float32
  let vh = e.window.size.y.float32

  glViewport 0, 0, e.window.size.x.GlInt, e.window.size.y.GlInt
  ctx.updateDrawingAreaSize(e.window.size)
  ctx.resize(aafb, e.window.size)

  ctx.drawInside aafb:
    glClearColor(0.12, 0.12, 0.12, 1)
    glClear(GL_COLOR_BUFFER_BIT)

    ctx.viewport = combine(
      scale(2'f32 / vw, -2'f32 / vh),
      translate(-1'f32, 1'f32),
    )

    for i in 0..<graph.edges.len:
      ctx.strokePath(
        edgeToPath(i), edgeColor(i),
        strokeWidth = 1.5, lineCap = RoundCap, lineJoin = RoundJoin,
      )

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

      var dot = newPath()
      dot.circle(node.position.x.float32, node.position.y.float32, if isIntersection: 3'f32 else: 2'f32)
      ctx.fillPath(dot, nodeColor)


randomize()
regenerate()
run win
