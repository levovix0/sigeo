## helpers for visual tests: drawing curves and dots via rice capsule/circle primitives,
## which are faster than triangulating pixie Paths

import pkg/[vmath, chroma]
import rice
import sigeo/[core]


proc toVec3(p: Point2): Vec3 {.inline.} =
  vec3(p.x.float32, p.y.float32, 0)


proc drawSegment*(ctx: DrawContext, a, b: Point2, color: Color, thickness: float32 = 1.5) =
  if a.distanceTo(b) < 1e-9: return  # fillCapsule cannot draw zero-length capsules
  ctx.fillCapsule(color = color, a = a.toVec3, b = b.toVec3, radius = thickness / 2)


proc drawPolyline*(ctx: DrawContext, pts: openArray[Point2], color: Color, thickness: float32 = 1.5) =
  for i in 0 ..< pts.len - 1:
    ctx.drawSegment(pts[i], pts[i + 1], color, thickness)


proc drawDot*(ctx: DrawContext, p: Point2, color: Color, radius: float32) =
  ctx.fillCircle(color, radius, center = p.toVec3)


proc drawBoundsRect*(ctx: DrawContext, b: Bounds2, color: Color, thickness: float32 = 1) =
  let tr = point2(b.max.x, b.min.y)
  let bl = point2(b.min.x, b.max.y)
  ctx.drawSegment(b.min, tr, color, thickness)
  ctx.drawSegment(tr, b.max, color, thickness)
  ctx.drawSegment(b.max, bl, color, thickness)
  ctx.drawSegment(bl, b.min, color, thickness)
