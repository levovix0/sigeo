import std/math
import pkg/[chroma]
import rice
import sigeo/[core, curves2d]
import ./[drawutils]


proc draw(ctx: DrawContext, curve: Curve2, color: Color = color(1, 1, 1)) =
  ctx.drawPolyline(curve.points(), color, thickness = 0.1)


let app = newVisualTest(
  title = "sigeo contour creation test",
  size = ivec2(600, 600),
  contentCenter = vec2(1, 1),
  zoom = 0.5,
)


app.run proc(ctx: DrawContext) =
  let curves = @[
    lineSection(p2(0, 0), p2(2, 0)).toOwnedCurve2,
    lineSection(p2(2, 2), p2(2, 0)).toOwnedCurve2,
    lineSection(p2(0, 1), p2(0, 0)).toOwnedCurve2,

    lineSection(p2(0, 0), p2(1, 1)).toOwnedCurve2,
    lineSection(p2(2, 0), p2(1, 1)).toOwnedCurve2,
    lineSection(p2(1, 2), p2(1, 1)).toOwnedCurve2,

    lineSection(p2(1, 2), p2(2, 2)).toOwnedCurve2,
    lineSection(p2(0, 0), p2(0, 1)).toOwnedCurve2,
    circleArc(p2(0, 2), 1, 0.0, -Pi/2).toOwnedCurve2,
  ]

  for curve in curves:
    ctx.draw curve

  let contour = outerContour(curves)
  for x in contour.curves:
    ctx.draw x, color(1, 0.4, 0.4)
