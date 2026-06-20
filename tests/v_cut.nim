## Visual test: displays curve.cut(a, b) for different kinds of curves and cut params.
##
## Grid layout: rows = curves, columns = (a, b) cut param pairs.
## Rows: full circle CCW, full circle CW, half arc CCW, half arc CW,
##       full rotated ellipse, rotated ellipse arc CW, line section.
##
## In every cell:
##  - grey      = the original curve
##  - orange    = the cut piece (slightly thicker, drawn over the original)
##  - yellow dots = original.pointAt(a + t*(b-a)) samples — must lie exactly on the orange path
##  - green/red dot = start/end of the cut piece — must be at original params a/b
##  - teal rect = bounds of the cut piece — must tightly wrap the orange path

import std/math
import pkg/[chroma]
import rice
import sigeo/[core, curves2d]
import ./[drawutils]

const
  nRows    = 7
  cellSize = 130.0
  margin   = 24.0

let cutParams = [
  (0.0, 1.0),
  (0.25, 0.75),
  (0.75, 0.25),  # reversed
  (0.1, 0.6),
  (0.95, 0.4),   # reversed
  (0.5, 1.0),
]

let gridW = cutParams.len.Float * cellSize
let gridH = nRows.Float * cellSize
let winW  = int32(margin*2 + gridW)
let winH  = int32(margin*2 + gridH)

let app = newVisualTest(
  title = "sigeo cut — rows=curves cols=(a,b); yellow dots must lie on orange",
  size = ivec2(winW, winH),
  contentCenter = vec2(winW.float32 / 2, winH.float32 / 2),
)


type Cell = object
  origPts, cutPts: seq[Point2]
  samplePts: seq[Point2]
  cutStart, cutEnd: Point2
  cutBounds: Bounds2


proc makeCell[C](curve: C, a, b: Float): Cell =
  const nPoints = 64
  let cutCurve = curve.cut(a, b)

  for i in 0..nPoints:
    result.origPts.add curve.pointAt(i / nPoints)
    result.cutPts.add cutCurve.pointAt(i / nPoints)

  for i in 0..16:
    result.samplePts.add curve.pointAt(a + i / 16 * (b - a))

  result.cutStart = cutCurve.pointAt(0)
  result.cutEnd = cutCurve.pointAt(1)
  result.cutBounds = cutCurve.bounds(0, 1)


proc cellAt(row: int, center: Point2, a, b: Float): Cell =
  const r = cellSize * 0.32
  case row
  of 0: makeCell(circleArc(center, r), a, b)
  of 1: makeCell(circleArc(center, r, 0, 0, clockwise), a, b)
  of 2: makeCell(circleArc(center, r, Pi/2, -Pi/2), a, b)
  of 3: makeCell(circleArc(center, r, Pi/2, -Pi/2, clockwise), a, b)
  of 4: makeCell(ellipseArc(center, v2(2.4*r, 1.2*r), rotation = Pi/6), a, b)
  of 5: makeCell(ellipseArc(center, v2(2.4*r, 1.2*r), Pi/4, -3*Pi/4, clockwise, rotation = -Pi/3), a, b)
  else: makeCell(lineSection(center + v2(-r, r*0.6), center + v2(r, -r*0.6)), a, b)


var cells: seq[tuple[cell: Cell, ok: bool]]
for row in 0..<nRows:
  for col, (a, b) in cutParams:
    let center = point2(
      margin + (col.Float + 0.5) * cellSize,
      margin + (row.Float + 0.5) * cellSize,
    )
    let cell = cellAt(row, center, a, b)

    # automatic check, in addition to visual: samples must lie on the cut path
    var ok = true
    for i, p in cell.samplePts:
      if p.distanceTo(cell.cutPts[i * (cell.cutPts.len - 1) div (cell.samplePts.len - 1)]) > 1e-6:
        ok = false
    if not ok:
      echo "MISMATCH: row=", row, " col=", col, " (a, b)=", (a, b)

    cells.add (cell, ok)


app.run proc(ctx: DrawContext) =
  # grid separators
  for i in 0..max(nRows, cutParams.len):
    if i <= cutParams.len:
      let x = margin + i.Float * cellSize
      ctx.drawSegment(point2(x, margin), point2(x, margin + gridH), color(0.2, 0.2, 0.2), thickness = 1)
    if i <= nRows:
      let y = margin + i.Float * cellSize
      ctx.drawSegment(point2(margin, y), point2(margin + gridW, y), color(0.2, 0.2, 0.2), thickness = 1)

  for (cell, ok) in cells:
    ctx.drawBoundsRect(cell.cutBounds, color(0.1, 0.45, 0.45), thickness = 1)

    ctx.drawPolyline(cell.origPts, color(0.45, 0.45, 0.45), thickness = 1.5)

    let cutColor = if ok: color(1.0, 0.55, 0.25) else: color(1.0, 0.1, 0.1)
    ctx.drawPolyline(cell.cutPts, cutColor, thickness = 2.5)

    for p in cell.samplePts:
      ctx.drawDot(p, color(1.0, 0.9, 0.2), radius = 1.5)

    ctx.drawDot(cell.cutStart, color(0.2, 1.0, 0.4), radius = 3)
    ctx.drawDot(cell.cutEnd, color(1.0, 0.2, 0.3), radius = 2.5)
