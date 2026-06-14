## Visual test: path construction with addBevel and addFillet.
##
## Both paths are drawn overlaid at the same position.
## Blue = addBevel: straight diagonal cuts at corners.
## Red  = addFillet: circular arc at corners.
##
## Corner dots mark where each sub-curve starts.
## Visual check: both paths must share the same straight segments;
## only the corner transitions should differ.

import std/math
import pkg/[chroma]
import rice
import sigeo/[core, curves2d]
import ./[drawutils]


const radius = 0.5


proc buildPath(fillet: bool): Path2 =
  template corner =
    if fillet: result.addFillet radius else: result.addBevel radius

  result.add lineSection(p2(0, 0), p2(6, 0))
  result.add lineSection(p2(6, 0), p2(6, 2)); corner()
  result.add lineSection(p2(6, 2), p2(4, 2)); corner()
  result.add lineSection(p2(4, 2), p2(4, 3)); corner()
  result.add lineSection(p2(4, 3), p2(6, 3)); corner()
  result.add lineSection(p2(6, 3), p2(6, 6)); corner()
  result.add lineSection(p2(6, 6), p2(0, 6)); corner()
  result.add lineSection(p2(0, 6), p2(0, 0)); corner()


let app = newVisualTest(
  title = "sigeo path construction — blue=addBevel  red=addFillet",
  size = ivec2(500, 500),
  contentCenter = vec2(3, 3),
  zoom = 0.12,
)


let bevelPath = buildPath(fillet = false)
let filletPath = buildPath(fillet = true)


app.run proc(ctx: DrawContext) =
  ctx.drawPolyline(bevelPath.toCurve2.points(256), color(0.35, 0.55, 1.0), thickness = 0.1)
  ctx.drawPolyline(filletPath.toCurve2.points(256), color(1.0, 0.35, 0.35), thickness = 0.05)

  for i in 0..<bevelPath.curves.len:
    ctx.drawDot(bevelPath.pointAtCurve(i, 0), color(0.35, 0.55, 1.0), radius = 0.2)
  for i in 0..<filletPath.curves.len:
    ctx.drawDot(filletPath.pointAtCurve(i, 0), color(1.0, 0.35, 0.35), radius = 0.1)
