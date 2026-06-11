## Visual test: displays CircleArc paths for all combinations of start/end angles
## (step = Pi/4). Spacebar toggles direction between CCW and CW for all arcs.
## Blue = CCW, orange = CW. Grey diagonal = full circles (start == end).
##
## Grid layout: rows = startAngle, columns = endAngle.
## Angles in order: 0, Pi/4, Pi/2, 3Pi/4, Pi, -3Pi/4, -Pi/2, -Pi/4.

import std/math
import pkg/[siwin, chroma]
import rice
import sigeo/[core, curves2d]
import ./drawutils

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
      let x = (margin + i.float32 * cellSize).Float
      let y = (margin + i.float32 * cellSize).Float
      ctx.drawSegment(point2(margin.Float, y), point2((margin + gridW).Float, y), color(0.2, 0.2, 0.2), thickness = 1)
      ctx.drawSegment(point2(x, margin.Float), point2(x, (margin + gridH).Float), color(0.2, 0.2, 0.2), thickness = 1)

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
        ctx.drawDot(point2(cx.Float, cy.Float), color(0.25, 0.25, 0.25), radius = 1.5)

        let arc = circleArc(
          point2(cx.float, cy.float),
          arcRadius,
          sa, ea,
          currentDir,
        )

        let cellColor =
          if arc.fullCircle: color(0.55, 0.55, 0.55)
          else: arcColor

        ctx.drawPolyline(arc.points(nPoints), cellColor, thickness = 1.5)

        # mark start point (green) and end point (red)
        ctx.drawDot(arc.pointAtParam(0), color(0.2, 1.0, 0.4), radius = 2.5)
        ctx.drawDot(arc.pointAtParam(1), color(1.0, 0.2, 0.3), radius = 2.0)


run win
