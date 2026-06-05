## Visual test: displays CircleArc paths for all combinations of start/end angles
## (step = Pi/4). Spacebar toggles direction between CCW and CW for all arcs.
## Blue = CCW, orange = CW. Grey diagonal = full circles (start == end).
##
## Grid layout: rows = startAngle, columns = endAngle.
## Angles in order: 0, Pi/4, Pi/2, 3Pi/4, Pi, -3Pi/4, -Pi/2, -Pi/4.

import std/math
import pkg/[siwin, pixie]
import rice
import sigeo/[core, curves2d]

const
  nPoints   = 50
  nAngles   = 8
  cellSize  = 70'f32
  arcRadius = 26'f32
  margin    = 20'f32

let angles: array[nAngles, float] = [
  0.0, Pi/4, Pi/2, 3*Pi/4, Pi, -3*Pi/4, -Pi/2, -Pi/4,
]

let gridW = nAngles.float32 * cellSize
let gridH = nAngles.float32 * cellSize
let winW  = int32(margin*2 + gridW)
let winH  = int32(margin*2 + gridH)

let win = newOpenglWindow(
  title = "sigeo CircleArc — rows=startAngle cols=endAngle  [Space] toggle CCW/CW",
  size = ivec2(winW, winH),
)
opengl.loadExtensions()
let ctx = newDrawContext()
var aafb = ctx.newAntialiasedFramebuffer(win.size)

var currentDir = counterclockwise


proc arcToPath(arc: CircleArc): Path =
  let pts = arc.points(nPoints)
  result = newPath()
  if pts.len == 0: return
  result.moveTo(pts[0].x.float32, pts[0].y.float32)
  for i in 1..pts.high:
    result.lineTo(pts[i].x.float32, pts[i].y.float32)

  # todo: rice wrongly draws non-closed paths
  for i in countdown(pts.high - 1, 0):
    result.lineTo(pts[i].x.float32, pts[i].y.float32)


win.eventsHandler.onResize = proc(e: ResizeEvent) =
  glViewport 0, 0, e.size.x.GlInt, e.size.y.GlInt
  ctx.resize(aafb, e.size)
  ctx.updateDrawingAreaSize(e.size)


win.eventsHandler.onKey = proc(e: KeyEvent) =
  if e.pressed and e.key == Key.space:
    currentDir =
      if currentDir == counterclockwise: clockwise
      else: counterclockwise
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

    # grid separators
    for i in 0..nAngles:
      let x = margin + i.float32 * cellSize
      let y = margin + i.float32 * cellSize
      var lineH = newPath()
      lineH.moveTo(margin, y)
      lineH.lineTo(margin + gridW, y)
      ctx.strokePath(lineH, color(0.2, 0.2, 0.2), strokeWidth = 1)
      var lineV = newPath()
      lineV.moveTo(x, margin)
      lineV.lineTo(x, margin + gridH)
      ctx.strokePath(lineV, color(0.2, 0.2, 0.2), strokeWidth = 1)

    let arcColor =
      if currentDir == counterclockwise: color(0.35, 0.65, 1.0)
      else:                              color(1.0,  0.55, 0.25)

    for si in 0..<nAngles:
      let sa = angles[si]
      for ei in 0..<nAngles:
        let ea = angles[ei]
        let cx = margin + (ei.float32 + 0.5'f32) * cellSize
        let cy = margin + (si.float32 + 0.5'f32) * cellSize

        # center dot
        var dot = newPath()
        dot.circle(cx, cy, 1.5'f32)
        ctx.fillPath(dot, color(0.25, 0.25, 0.25))

        let arc = circleArc(
          point2(cx.float, cy.float),
          arcRadius,
          sa, ea,
          currentDir,
        )

        let cellColor =
          if arc.fullCircle: color(0.55, 0.55, 0.55)
          else: arcColor

        ctx.strokePath(arcToPath(arc), cellColor, strokeWidth = 1.5, lineCap = RoundCap, lineJoin = RoundJoin)

        # mark start point (green) and end point (red)
        let startPt = arc.pointAtParam(0)
        var startDot = newPath()
        startDot.circle(startPt.x.float32, startPt.y.float32, 2.5'f32)
        ctx.fillPath(startDot, color(0.2, 1.0, 0.4))

        let endPt = arc.pointAtParam(1)
        var endDot = newPath()
        endDot.circle(endPt.x.float32, endPt.y.float32, 2.0'f32)
        ctx.fillPath(endDot, color(1.0, 0.2, 0.3))


run win
