import std/[math]
import ../core/[vectors, points, bounds2, bounds3, placement]

export vectors, points, bounds2, bounds3, placement


type
  Sdf2Func* = proc(p: Point2): Float {.closure.}
    ## signed distance function in 2D space
    ## todo: use interfaces instead

  Sdf3Func* = proc(p: Point3): Float {.closure.}
    ## signed distance function in 3D space
    ## todo: use interfaces instead

  Sdf2* = object
    ## signed distance field in 2D
    ## negative distance - inside the shape, positive - outside
    dist*: Sdf2Func
    bounds2*: Bounds2
      ## conservative bounding box of the shape; empty if unknown

  Sdf3* = object
    ## signed distance field in 3D
    ## negative distance - inside the shape, positive - outside
    dist*: Sdf3Func
    bounds3*: Bounds3
      ## conservative bounding box of the shape; empty if unknown


proc infiniteBounds3*(): Bounds3 =
  ## bounding box of the whole space, used for unbounded shapes like planes
  Bounds3(min: point3(-Inf), max: point3(+Inf))

proc bounds3*(a, b: Point3): Bounds3 =
  ## bounding box defined by two corner points
  Bounds3(
    min: point3(min(a.x, b.x), min(a.y, b.y), min(a.z, b.z)),
    max: point3(max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)),
  )


proc sdf2*(dist: Sdf2Func, bounds: Bounds2 = Bounds2()): Sdf2 =
  Sdf2(dist: dist, bounds2: bounds)

proc sdf3*(dist: Sdf3Func, bounds: Bounds3 = infiniteBounds3()): Sdf3 =
  ## constructs an Sdf3 from a distance function
  ## by default the shape is considered unbounded (finite bounds should be provided for `polygonize` to auto-detect them)
  Sdf3(dist: dist, bounds3: bounds)

converter toSdf2*(f: Sdf2Func): Sdf2 = sdf2(f)
converter toSdf3*(f: Sdf3Func): Sdf3 = sdf3(f)


proc isKnown*(b: Bounds2): bool =
  ## returns true if the bounds are finite and known (not empty)
  not b.empty and b.min.x.abs != Inf and b.min.y.abs != Inf

proc shifted*(box: Bounds2, offset: V2): Bounds2 =
  if box.empty: return box
  bounds2(box.min + offset, box.max + offset)

proc scaled*(box: Bounds2, factor: Float): Bounds2 =
  if box.empty: return box
  bounds2(
    point2(box.min.x * factor, box.min.y * factor),
    point2(box.max.x * factor, box.max.y * factor),
  )

proc rotated*(box: Bounds2, around: Point2, angle: Float): Bounds2 =
  ## conservative bounds of a box rotated around a point
  if box.empty: return box
  for xi in 0..1:
    for yi in 0..1:
      let corner = point2(
        if xi == 0: box.min.x else: box.max.x,
        if yi == 0: box.min.y else: box.max.y,
      )
      result.add around + (corner - around).rotate(angle)

proc intersect*(a, b: Bounds2): Bounds2 =
  ## intersection of two bounding boxes; is empty if they don't overlap
  if a.empty: return a
  if b.empty: return b
  bounds2(
    point2(max(a.min.x, b.min.x), max(a.min.y, b.min.y)),
    point2(min(a.max.x, b.max.x), min(a.max.y, b.max.y)),
  )


proc smoothMin*(a, b, k: Float): Float =
  ## smooth minimum, `k` is the size of the transition (based on Inigo Quilez's article)
  let k = k * 4
  let h = max(k - (a - b).abs, 0)
  min(a, b) - h*h*0.25/k

proc tile*(v, spacing: Float): Float {.inline.} =
  ## coordinate for a single axis of domain repetition, no repetition along zero-spacing axes
  if spacing == 0: v
  else: v - spacing * (v / spacing).round

proc tileLimited*(v, spacing, limit: Float): Float {.inline.} =
  if spacing == 0: v
  else: v - spacing * (v / spacing).round.clamp(-limit.abs, limit.abs)

proc isKnown*(b: Bounds3): bool =
  ## returns true if the bounds are finite and known (not empty)
  not b.isEmpty and b.min.x.abs != Inf and b.min.y.abs != Inf and b.min.z.abs != Inf


proc expanded*(box: Bounds3, amount: Float): Bounds3 =
  if box.isEmpty: return box
  Bounds3(
    min: point3(box.min.x - amount, box.min.y - amount, box.min.z - amount),
    max: point3(box.max.x + amount, box.max.y + amount, box.max.z + amount),
  )

proc expanded*(box: Bounds3, amount: V3): Bounds3 =
  if box.isEmpty: return box
  Bounds3(
    min: point3(box.min.x - amount.x, box.min.y - amount.y, box.min.z - amount.z),
    max: point3(box.max.x + amount.x, box.max.y + amount.y, box.max.z + amount.z),
  )

proc shifted*(box: Bounds3, offset: V3): Bounds3 =
  if box.isEmpty: return box
  Bounds3(
    min: point3(box.min.x + offset.x, box.min.y + offset.y, box.min.z + offset.z),
    max: point3(box.max.x + offset.x, box.max.y + offset.y, box.max.z + offset.z),
  )

proc scaled*(box: Bounds3, factor: Float): Bounds3 =
  if box.isEmpty: return box
  Bounds3(
    min: point3(box.min.x * factor, box.min.y * factor, box.min.z * factor),
    max: point3(box.max.x * factor, box.max.y * factor, box.max.z * factor),
  )

proc intersect*(a, b: Bounds3): Bounds3 =
  ## intersection of two bounding boxes; is empty if they don't overlap
  Bounds3(
    min: point3(max(a.min.x, b.min.x), max(a.min.y, b.min.y), max(a.min.z, b.min.z)),
    max: point3(min(a.max.x, b.max.x), min(a.max.y, b.max.y), min(a.max.z, b.max.z)),
  )

proc transformed*(box: Bounds3, cs: Placement): Bounds3 =
  ## conservative bounds of a box transformed by a coordinate system (rotation + translation)
  if box.isEmpty: return box
  for xi in 0..1:
    for yi in 0..1:
      for zi in 0..1:
        let corner = point3(
          if xi == 0: box.min.x else: box.max.x,
          if yi == 0: box.min.y else: box.max.y,
          if zi == 0: box.min.z else: box.max.z,
        )
        result.add corner.transformBy(cs)

proc rotated*(box: Bounds3, around: Point3, axis: NormalVec3, angle: Float): Bounds3 =
  ## conservative bounds of a box rotated around a point
  if box.isEmpty: return box
  for xi in 0..1:
    for yi in 0..1:
      for zi in 0..1:
        let corner = point3(
          if xi == 0: box.min.x else: box.max.x,
          if yi == 0: box.min.y else: box.max.y,
          if zi == 0: box.min.z else: box.max.z,
        )
        result.add around + (corner - around).rotate(axis, angle)


proc dot2*(v: V2): Float {.inline.} =
  ## dot(v, v), shorthand used in SDF formulas
  v.x * v.x + v.y * v.y

proc dot2*(v: V3): Float {.inline.} =
  v.x * v.x + v.y * v.y + v.z * v.z


proc vabs*(v: V2): V2 {.inline.} = v2(v.x.abs, v.y.abs)
proc vabs*(v: V3): V3 {.inline.} = v3(v.x.abs, v.y.abs, v.z.abs)

proc vmax*(a, b: V2): V2 {.inline.} = v2(max(a.x, b.x), max(a.y, b.y))
proc vmax*(a, b: V3): V3 {.inline.} = v3(max(a.x, b.x), max(a.y, b.y), max(a.z, b.z))
proc vmin*(a, b: V2): V2 {.inline.} = v2(min(a.x, b.x), min(a.y, b.y))
proc vmin*(a, b: V3): V3 {.inline.} = v3(min(a.x, b.x), min(a.y, b.y), min(a.z, b.z))

proc vmax*(a: V2, b: Float): V2 {.inline.} = v2(max(a.x, b), max(a.y, b))
proc vmax*(a: V3, b: Float): V3 {.inline.} = v3(max(a.x, b), max(a.y, b), max(a.z, b))
proc vmin*(a: V2, b: Float): V2 {.inline.} = v2(min(a.x, b), min(a.y, b))
proc vmin*(a: V3, b: Float): V3 {.inline.} = v3(min(a.x, b), min(a.y, b), min(a.z, b))


proc vclamp*(v: V2, a, b: V2): V2 {.inline.} =
  v2(v.x.clamp(a.x, b.x), v.y.clamp(a.y, b.y))

proc vclamp*(v: V3, a, b: V3): V3 {.inline.} =
  v3(v.x.clamp(a.x, b.x), v.y.clamp(a.y, b.y), v.z.clamp(a.z, b.z))
