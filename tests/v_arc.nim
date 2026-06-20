## Visual test: displays CircleArc2 paths for all combinations of start/end angles
## (step = Pi/4). Spacebar toggles direction between CCW and CW for all arcs.
## Blue = CCW, orange = CW. Grey diagonal = full circles (start == end).
##
## Grid layout: rows = startAngle, columns = endAngle.
## Angles in order: 0, Pi/4, Pi/2, 3Pi/4, Pi, -3Pi/4, -Pi/2, -Pi/4.

import std/math
import pkg/[siwin, chroma]
import rice
import sigeo/[core, curves2d]
import ./[drawutils]

const
  nPoints   = 50
  nAngles   = 8
  cellSize  = 70.0
  arcRadius = 26.0
  margin    = 20.0

let angles: array[nAngles, float] = [
  0.0, Pi/4, Pi/2, 3*Pi/4, Pi, -3*Pi/4, -Pi/2, -Pi/4,
]

let gridW = nAngles.Float * cellSize
let gridH = nAngles.Float * cellSize
let winW  = int32(margin*2 + gridW)
let winH  = int32(margin*2 + gridH)

let app = newVisualTest(
  title = "sigeo CircleArc2 — rows=startAngle cols=endAngle  [Space] toggle CCW/CW",
  size = ivec2(winW, winH),
  contentCenter = vec2(winW.float32 / 2, winH.float32 / 2),
)

var currentDir = counterclockwise

app.onKey proc(e: KeyEvent) =
  if e.pressed and e.key == Key.space:
    currentDir =
      if currentDir == counterclockwise: clockwise
      else: counterclockwise
    redraw e.window


app.run proc(ctx: DrawContext) =
  # grid separators
  for i in 0..nAngles:
    let x = margin + i.Float * cellSize
    let y = margin + i.Float * cellSize
    ctx.drawSegment(point2(margin, y), point2(margin + gridW, y), color(0.2, 0.2, 0.2), thickness = 1)
    ctx.drawSegment(point2(x, margin), point2(x, margin + gridH), color(0.2, 0.2, 0.2), thickness = 1)

  let arcColor =
    if currentDir == counterclockwise: color(0.35, 0.65, 1.0)
    else:                              color(1.0,  0.55, 0.25)

  for si in 0..<nAngles:
    let sa = angles[si]
    for ei in 0..<nAngles:
      let ea = angles[ei]
      let cx = margin + (ei.Float + 0.5) * cellSize
      let cy = margin + (si.Float + 0.5) * cellSize

      # center dot
      ctx.drawDot(point2(cx, cy), color(0.25, 0.25, 0.25), radius = 1.5)

      let arc = circleArc(
        point2(cx, cy),
        arcRadius,
        sa, ea,
        currentDir,
      )

      let cellColor =
        if arc.fullCircle: color(0.55, 0.55, 0.55)
        else: arcColor

      ctx.drawPolyline(arc.points(nPoints), cellColor, thickness = 1.5)

      # mark start point (green) and end point (red)
      ctx.drawDot(arc.pointAt(0), color(0.2, 1.0, 0.4), radius = 2.5)
      ctx.drawDot(arc.pointAt(1), color(1.0, 0.2, 0.3), radius = 2.0)
