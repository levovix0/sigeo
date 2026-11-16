import std/[math]
import ../macros/[genAliases]
import ./[common]


## 2D SDF operators, based on Inigo Quilez's articles
## "2D distance functions" and "Distance functions" (rigid deformations, domain
## repetition, boolean operations and smooth connections work just as well in 2D)


#region boolean operations


proc opUnion*(a, b: Sdf2): Sdf2 {.aliases: [union].} =
  ## union of two shapes (exact SDF in the exterior)
  sdf2(
    dist = proc(p: Point2): Float = min(a.dist(p), b.dist(p)),
    bounds = a.bounds2 + b.bounds2,
  )


proc opSubtraction*(a, b: Sdf2): Sdf2 {.aliases: [subtract].} =
  ## `a` with `b` subtracted (bound, not exact SDF)
  ## note: in the original article the operands are swapped (opSubtraction(a, b) subtracts `a` from `b`)
  sdf2(
    dist = proc(p: Point2): Float = max(a.dist(p), -b.dist(p)),
    bounds = a.bounds2,
  )


proc opIntersection*(a, b: Sdf2): Sdf2 {.aliases: [intersect].} =
  ## intersection of two shapes (bound, not exact SDF)
  sdf2(
    dist = proc(p: Point2): Float = max(a.dist(p), b.dist(p)),
    bounds = a.bounds2.intersect(b.bounds2),
  )


proc opXor*(a, b: Sdf2): Sdf2 =
  ## exclusive or of two shapes (true SDF in the exterior)
  sdf2(
    dist = proc(p: Point2): Float = max(min(a.dist(p), b.dist(p)), -max(a.dist(p), b.dist(p))),
    bounds = a.bounds2 + b.bounds2,
  )


proc opSmoothUnion*(a, b: Sdf2, k: Float): Sdf2 {.aliases: [smoothUnion].} =
  ## union of two shapes with a smooth transition of `k` size (bound, not exact SDF)
  sdf2(
    dist = proc(p: Point2): Float = smoothMin(a.dist(p), b.dist(p), k),
    bounds = (a.bounds2 + b.bounds2).expanded(k),
  )


proc opSmoothSubtraction*(a, b: Sdf2, k: Float): Sdf2 {.aliases: [smoothSubtract].} =
  ## `a` with `b` subtracted, with a smooth transition of `k` size (bound, not exact SDF)
  ## note: in the original article the operands are swapped (opSmoothSubtraction(a, b) subtracts `a` from `b`)
  sdf2(
    dist = proc(p: Point2): Float = -smoothMin(-a.dist(p), b.dist(p), k),
    bounds = a.bounds2.expanded(k),
  )


proc opSmoothIntersection*(a, b: Sdf2, k: Float): Sdf2 {.aliases: [smoothIntersect].} =
  ## intersection of two shapes with a smooth transition of `k` size (bound, not exact SDF)
  sdf2(
    dist = proc(p: Point2): Float = -smoothMin(-a.dist(p), -b.dist(p), k),
    bounds = a.bounds2.intersect(b.bounds2),
  )


#endregion


#region constructing new shapes from existing ones


proc opElongate*(sdf: Sdf2, halfSize: V2): Sdf2 {.aliases: [elongate].} =
  ## splits the shape in two (four), moves the pieces apart and connects them
  let h = halfSize
  sdf2(
    dist = proc(p: Point2): Float =
      let q = p.V2 - p.V2.vclamp(-h, h)
      sdf.dist(q.toPoint)
    ,
    bounds = sdf.bounds2.expanded(halfSize),
  )


proc opRound*(sdf: Sdf2, radius: Float): Sdf2 {.aliases: [round].} =
  ## rounds/inflates the shape by `radius`
  sdf2(
    dist = proc(p: Point2): Float = sdf.dist(p) - radius,
    bounds = sdf.bounds2.expanded(radius),
  )


proc opOnion*(sdf: Sdf2, thickness: Float): Sdf2 {.aliases: [onion].} =
  ## hollows the shape leaving a shell of `thickness` thickness
  sdf2(
    dist = proc(p: Point2): Float = sdf.dist(p).abs - thickness,
    bounds = sdf.bounds2,
  )


#endregion


#region positioning


proc opTranslate*(sdf: Sdf2, offset: V2): Sdf2 {.aliases: [translate].} =
  ## moves the shape by `offset`
  sdf2(
    dist = proc(p: Point2): Float = sdf.dist(p - offset),
    bounds = sdf.bounds2.shifted(offset),
  )


proc opRotate*(sdf: Sdf2, around: Point2, angle: Float): Sdf2 {.aliases: [rotate].} =
  ## rotates the shape around the `around` point
  sdf2(
    dist = proc(p: Point2): Float = sdf.dist(around + (p - around).rotate(-angle)),
    bounds = sdf.bounds2.rotated(around, angle),
  )


proc opScale*(sdf: Sdf2, factor: Float): Sdf2 {.aliases: [scale].} =
  ## scales the shape by `factor` times around the origin (uniform scaling only)
  sdf2(
    dist = proc(p: Point2): Float = sdf.dist((p.V2 / factor).toPoint) * factor,
    bounds = sdf.bounds2.scaled(factor),
  )


#endregion


#region symmetry and repetition


proc opSymX*(sdf: Sdf2): Sdf2 {.aliases: [mirrorX].} =
  ## mirrors the shape across the Y axis; exact only if the shape does not cross the axis
  sdf2(
    dist = proc(p: Point2): Float = sdf.dist(point2(p.x.abs, p.y)),
    bounds =
      if not sdf.bounds2.isKnown: sdf.bounds2
      elif sdf.bounds2.min.x < 0: sdf.bounds2
      else: bounds2(
        point2(-sdf.bounds2.max.x, sdf.bounds2.min.y),
        point2(sdf.bounds2.max.x, sdf.bounds2.max.y),
      )
    ,
  )


proc opSymY*(sdf: Sdf2): Sdf2 {.aliases: [mirrorY].} =
  ## mirrors the shape across the X axis; exact only if the shape does not cross the axis
  sdf2(
    dist = proc(p: Point2): Float = sdf.dist(point2(p.x, p.y.abs)),
    bounds =
      if not sdf.bounds2.isKnown: sdf.bounds2
      elif sdf.bounds2.min.y < 0: sdf.bounds2
      else: bounds2(
        point2(sdf.bounds2.min.x, -sdf.bounds2.max.y),
        point2(sdf.bounds2.max.x, sdf.bounds2.max.y),
      )
    ,
  )


proc opRepetition*(sdf: Sdf2, spacing: V2): Sdf2 {.aliases: [repeat].} =
  ## infinitely repeats the shape with the specified spacing; works exactly
  ## only for shapes symmetric with respect to the tile boundaries
  let s = spacing
  sdf2(
    dist = proc(p: Point2): Float =
      sdf.dist(point2(tile(p.x, s.x), tile(p.y, s.y)))
    ,
    bounds = Bounds2(),
  )


proc opLimitedRepetition*(sdf: Sdf2, spacing: V2, limit: V2): Sdf2 {.aliases: [limitedRepeat].} =
  ## repeats the shape with the specified spacing, at most `limit` tiles in each direction
  let s = spacing
  let l = limit
  sdf2(
    dist = proc(p: Point2): Float =
      sdf.dist(point2(
        tileLimited(p.x, s.x, l.x),
        tileLimited(p.y, s.y, l.y),
      ))
    ,
    bounds = sdf.bounds2.expanded(v2(
      if s.x == 0: Float(0) else: l.x.abs * s.x,
      if s.y == 0: Float(0) else: l.y.abs * s.y,
    )),
  )


#endregion
