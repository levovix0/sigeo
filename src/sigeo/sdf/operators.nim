import std/[math]
import ../macros/[genAliases]
import ./[common]


# SDF combination and space operators, based on Inigo Quilez's article
# "Distance functions" (https://iquilezles.org/articles/distfunctions/)


# region boolean operations


proc opUnion*(a, b: Sdf3): Sdf3 {.aliases: [union].} =
  ## union of two shapes (exact SDF in the exterior)
  sdf3(
    dist = proc(p: Point3): Float = min(a.dist(p), b.dist(p)),
    bounds = a.bounds3 + b.bounds3,
  )


proc opSubtraction*(a, b: Sdf3): Sdf3 {.aliases: [subtract].} =
  ## `a` with `b` subtracted (bound, not exact SDF)
  ## note: in the original article the operands are swapped (opSubtraction(a, b) subtracts `a` from `b`)
  sdf3(
    dist = proc(p: Point3): Float = max(a.dist(p), -b.dist(p)),
    bounds = a.bounds3,
  )


proc opIntersection*(a, b: Sdf3): Sdf3 {.aliases: [intersect].} =
  ## intersection of two shapes (bound, not exact SDF)
  sdf3(
    dist = proc(p: Point3): Float = max(a.dist(p), b.dist(p)),
    bounds = a.bounds3.intersect(b.bounds3),
  )


proc opXor*(a, b: Sdf3): Sdf3 =
  ## exclusive or of two shapes (true SDF in the exterior)
  sdf3(
    dist = proc(p: Point3): Float = max(min(a.dist(p), b.dist(p)), -max(a.dist(p), b.dist(p))),
    bounds = a.bounds3 + b.bounds3,
  )


proc opSmoothUnion*(a, b: Sdf3, k: Float): Sdf3 {.aliases: [smoothUnion].} =
  ## union of two shapes with a smooth transition of `k` size (bound, not exact SDF)
  sdf3(
    dist = proc(p: Point3): Float = smoothMin(a.dist(p), b.dist(p), k),
    bounds = (a.bounds3 + b.bounds3).expanded(k),
  )


proc opSmoothSubtraction*(a, b: Sdf3, k: Float): Sdf3 {.aliases: [smoothSubtract].} =
  ## `a` with `b` subtracted, with a smooth transition of `k` size (bound, not exact SDF)
  ## note: in the original article the operands are swapped (opSmoothSubtraction(a, b) subtracts `a` from `b`)
  sdf3(
    dist = proc(p: Point3): Float = -smoothMin(-a.dist(p), b.dist(p), k),
    bounds = a.bounds3.expanded(k),
  )


proc opSmoothIntersection*(a, b: Sdf3, k: Float): Sdf3 {.aliases: [smoothIntersect].} =
  ## intersection of two shapes with a smooth transition of `k` size (bound, not exact SDF)
  sdf3(
    dist = proc(p: Point3): Float = -smoothMin(-a.dist(p), -b.dist(p), k),
    bounds = a.bounds3.intersect(b.bounds3),
  )


# endregion


# region constructing new shapes from existing ones


proc opElongate*(sdf: Sdf3, halfSize: V3): Sdf3 {.aliases: [elongate].} =
  ## splits the shape in two (four or eight), moves the pieces apart and connects them
  ## the resulting distances are exact outside, but there is a small core of zero
  ## distances inside the volume
  let h = halfSize
  sdf3(
    dist = proc(p: Point3): Float =
      let q = p.V3 - p.V3.vclamp(-h, h)
      sdf.dist(q.toPoint)
    ,
    bounds = sdf.bounds3.expanded(halfSize),
  )


proc opElongateExact*(sdf: Sdf3, halfSize: V3): Sdf3 {.aliases: [elongateExact].} =
  ## elongation with exact interior distances (slightly more expensive than `opElongate`)
  let h = halfSize
  sdf3(
    dist = proc(p: Point3): Float =
      let q = p.V3.vabs - h
      sdf.dist(vmax(q, 0).toPoint) + min(max(q.x, max(q.y, q.z)), 0)
    ,
    bounds = sdf.bounds3.expanded(halfSize),
  )


proc opRound*(sdf: Sdf3, radius: Float): Sdf3 {.aliases: [round].} =
  ## rounds/inflates the shape by `radius`
  sdf3(
    dist = proc(p: Point3): Float = sdf.dist(p) - radius,
    bounds = sdf.bounds3.expanded(radius),
  )


proc opOnion*(sdf: Sdf3, thickness: Float): Sdf3 {.aliases: [onion].} =
  ## hollows the shape leaving a shell of `thickness` thickness
  sdf3(
    dist = proc(p: Point3): Float = sdf.dist(p).abs - thickness,
    bounds = sdf.bounds3,
  )


# endregion


# region positioning


proc opTranslate*(sdf: Sdf3, offset: V3): Sdf3 {.aliases: [translate].} =
  ## moves the shape by `offset`
  sdf3(
    dist = proc(p: Point3): Float = sdf.dist(p - offset),
    bounds = sdf.bounds3.shifted(offset),
  )


proc opRotate*(sdf: Sdf3, around: Point3, axis: NormalVec3, angle: Float): Sdf3 {.aliases: [rotate].} =
  ## rotates the shape around the axis passing through `around`
  sdf3(
    dist = proc(p: Point3): Float =
      sdf.dist(around + (p - around).V3.rotate(axis, -angle))
    ,
    bounds = sdf.bounds3.rotated(around, axis, angle),
  )


proc opTransform*(sdf: Sdf3, cs: Placement): Sdf3 {.aliases: [transform].} =
  ## places the shape into the `cs` coordinate system (rotation + translation, no scaling)
  sdf3(
    dist = proc(p: Point3): Float = sdf.dist(p.fromWorld(cs)),
    bounds = sdf.bounds3.transformed(cs),
  )


proc opScale*(sdf: Sdf3, factor: Float): Sdf3 {.aliases: [scale].} =
  ## scales the shape by `factor` times around the origin (uniform scaling only)
  sdf3(
    dist = proc(p: Point3): Float = sdf.dist((p.V3 / factor).toPoint) * factor,
    bounds = sdf.bounds3.scaled(factor),
  )


# endregion


# region symmetry and repetition


proc opSymX*(sdf: Sdf3): Sdf3 {.aliases: [mirrorX].} =
  ## mirrors the shape across the YZ plane; exact only if the shape does not cross the plane
  sdf3(
    dist = proc(p: Point3): Float = sdf.dist(point3(p.x.abs, p.y, p.z)),
    bounds =
      if not sdf.bounds3.isKnown: sdf.bounds3
      elif sdf.bounds3.min.x < 0: sdf.bounds3
      else: Bounds3(
        min: point3(-sdf.bounds3.max.x, sdf.bounds3.min.y, sdf.bounds3.min.z),
        max: point3(sdf.bounds3.max.x, sdf.bounds3.max.y, sdf.bounds3.max.z),
      )
    ,
  )


proc opSymY*(sdf: Sdf3): Sdf3 {.aliases: [mirrorY].} =
  ## mirrors the shape across the XZ plane; exact only if the shape does not cross the plane
  sdf3(
    dist = proc(p: Point3): Float = sdf.dist(point3(p.x, p.y.abs, p.z)),
    bounds =
      if not sdf.bounds3.isKnown: sdf.bounds3
      elif sdf.bounds3.min.y < 0: sdf.bounds3
      else: Bounds3(
        min: point3(sdf.bounds3.min.x, -sdf.bounds3.max.y, sdf.bounds3.min.z),
        max: point3(sdf.bounds3.max.x, sdf.bounds3.max.y, sdf.bounds3.max.z),
      )
    ,
  )


proc opSymZ*(sdf: Sdf3): Sdf3 {.aliases: [mirrorZ].} =
  ## mirrors the shape across the XY plane; exact only if the shape does not cross the plane
  sdf3(
    dist = proc(p: Point3): Float = sdf.dist(point3(p.x, p.y, p.z.abs)),
    bounds =
      if not sdf.bounds3.isKnown: sdf.bounds3
      elif sdf.bounds3.min.z < 0: sdf.bounds3
      else: Bounds3(
        min: point3(sdf.bounds3.min.x, sdf.bounds3.min.y, -sdf.bounds3.max.z),
        max: point3(sdf.bounds3.max.x, sdf.bounds3.max.y, sdf.bounds3.max.z),
      )
    ,
  )


proc opSymXZ*(sdf: Sdf3): Sdf3 {.aliases: [mirrorXZ].} =
  ## mirrors the shape across the Y axis; exact only if the shape does not cross the planes
  sdf3(
    dist = proc(p: Point3): Float = sdf.dist(point3(p.x.abs, p.y, p.z.abs)),
    bounds =
      if not sdf.bounds3.isKnown: sdf.bounds3
      elif sdf.bounds3.min.x < 0 or sdf.bounds3.min.z < 0: sdf.bounds3
      else: Bounds3(
        min: point3(-sdf.bounds3.max.x, sdf.bounds3.min.y, -sdf.bounds3.max.z),
        max: point3(sdf.bounds3.max.x, sdf.bounds3.max.y, sdf.bounds3.max.z),
      )
    ,
  )


proc opRepetition*(sdf: Sdf3, spacing: V3): Sdf3 {.aliases: [repeat].} =
  ## infinitely repeats the shape with the specified spacing; works exactly
  ## only for shapes symmetric with respect to the tile boundaries
  let s = spacing
  sdf3(
    dist = proc(p: Point3): Float =
      sdf.dist(point3(tile(p.x, s.x), tile(p.y, s.y), tile(p.z, s.z)))
    ,
    bounds = infiniteBounds3(),
  )


proc opLimitedRepetition*(sdf: Sdf3, spacing: V3, limit: V3): Sdf3 {.aliases: [limitedRepeat].} =
  ## repeats the shape with the specified spacing, at most `limit` tiles in each direction
  let s = spacing
  let l = limit
  sdf3(
    dist = proc(p: Point3): Float =
      sdf.dist(point3(
        tileLimited(p.x, s.x, l.x),
        tileLimited(p.y, s.y, l.y),
        tileLimited(p.z, s.z, l.z),
      ))
    ,
    bounds = sdf.bounds3.expanded(v3(
      if s.x == 0: Float(0) else: l.x.abs * s.x,
      if s.y == 0: Float(0) else: l.y.abs * s.y,
      if s.z == 0: Float(0) else: l.z.abs * s.z,
    )),
  )


# endregion


# region deformations


proc opDisplace*(sdf: Sdf3, displacement: Sdf3): Sdf3 {.aliases: [displace].} =
  ## displaces the shape surface by the `displacement` field value
  ## breaks the distance field, `polygonize` will require explicit bounds
  sdf3(
    dist = proc(p: Point3): Float = sdf.dist(p) + displacement.dist(p),
    bounds = Bounds3(),
  )


proc opDisplace*(sdf: Sdf3, displacement: Sdf3Func): Sdf3 =
  ## see `opDisplace(sdf, displacement: Sdf3)`
  opDisplace(sdf, displacement.toSdf3)


proc opTwist*(sdf: Sdf3, k: Float): Sdf3 {.aliases: [twist].} =
  ## twists the shape around the Y axis; `k` is the amount of rotation per unit of Y
  ## breaks the distance field, `polygonize` will require explicit bounds
  sdf3(
    dist = proc(p: Point3): Float =
      let c = (k*p.y).cos
      let s = (k*p.y).sin
      sdf.dist(point3(c*p.x + s*p.z, p.y, -s*p.x + c*p.z))
    ,
    bounds = Bounds3(),
  )


proc opCheapBend*(sdf: Sdf3, k: Float): Sdf3 {.aliases: [bend].} =
  ## bends the shape around the Z axis; `k` is the amount of rotation per unit of X
  ## breaks the distance field, `polygonize` will require explicit bounds
  sdf3(
    dist = proc(p: Point3): Float =
      let c = (k*p.x).cos
      let s = (k*p.x).sin
      sdf.dist(point3(c*p.x + s*p.y, -s*p.x + c*p.y, p.z))
    ,
    bounds = Bounds3(),
  )


# endregion


# region creating 3D SDFs from 2D SDFs


proc opExtrusion*(sdf: Sdf2, halfHeight: Float): Sdf3 {.aliases: [extrude].} =
  ## extrudes a 2D shape along Z by `halfHeight` in each direction
  let h = halfHeight
  sdf3(
    dist = proc(p: Point3): Float =
      let d = sdf.dist(p.xy)
      let w = v2(d, p.z.abs - h)
      min(max(w.x, w.y), 0) + vmax(w, 0).length
    ,
    bounds =
      if not sdf.bounds2.isKnown: Bounds3()
      else: Bounds3(
        min: point3(sdf.bounds2.min.x, sdf.bounds2.min.y, -h),
        max: point3(sdf.bounds2.max.x, sdf.bounds2.max.y, +h),
      )
    ,
  )


proc opRevolution*(sdf: Sdf2, offset: Float): Sdf3 {.aliases: [revolve].} =
  ## revolves a 2D shape around the Y axis, shifting it radially by `offset`
  let o = offset
  sdf3(
    dist = proc(p: Point3): Float =
      sdf.dist(point2(v2(p.x, p.z).length - o, p.y))
    ,
    bounds =
      if not sdf.bounds2.isKnown: Bounds3()
      else:
        let r = max((sdf.bounds2.min.x + o).abs, (sdf.bounds2.max.x + o).abs)
        Bounds3(
          min: point3(-r, sdf.bounds2.min.y, -r),
          max: point3(+r, sdf.bounds2.max.y, +r),
        )
    ,
  )


# endregion
