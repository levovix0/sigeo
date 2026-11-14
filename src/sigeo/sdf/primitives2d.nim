import std/[math]
import ./[common]


proc sdCircle*(center: Point2, radius: Float): Sdf2 =
  ## exact 2D circle
  let half = v2(radius, radius)
  sdf2(
    dist = proc(p: Point2): Float = (p - center).length - radius,
    bounds = bounds2(center - half, center + half),
  )


proc sdBox*(center: Point2, halfSize: V2): Sdf2 =
  ## exact 2D box
  sdf2(
    dist = proc(p: Point2): Float =
      let q = vabs(p.V2 - center.V2) - halfSize
      vmax(q, 0).length + min(max(q.x, q.y), 0)
    ,
    bounds = bounds2(center - halfSize, center + halfSize),
  )


proc sdSegment*(a, b: Point2): Sdf2 =
  ## exact 2D distance to a line segment (unsigned, distance to the 1D shape itself)
  let
    ba = b.V2 - a.V2
    dot2ba = ba.dot2
  sdf2(
    dist = proc(p: Point2): Float =
      let pa = p.V2 - a.V2
      let h = pa.dot(ba) / dot2ba
      (pa - ba * h).length
    ,
    bounds = bounds2(vmin(a.V2, b.V2).toPoint, vmax(a.V2, b.V2).toPoint),
  )


proc sdCapsule*(a, b: Point2, radius: Float): Sdf2 =
  ## exact 2D capsule (segment with round ends)
  let seg = sdSegment(a, b)
  sdf2(
    dist = proc(p: Point2): Float = seg.dist(p) - radius,
    bounds = seg.bounds2.expanded(radius),
  )
