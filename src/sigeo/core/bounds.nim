import std/[fenv]
import ./[vectors, points]


type
  Bounds2* = object
    ## axis-aligned 2d bounding box
    empty*: bool = true
    min*, max*: Point2


proc bounds2*(p: Point2): Bounds2 =
  Bounds2(empty: false, min: p, max: p)

proc bounds2*(a, b: Point2): Bounds2 =
  Bounds2(
    empty: false,
    min: point2(min(a.x, b.x), min(a.y, b.y)),
    max: point2(max(a.x, b.x), max(a.y, b.y)),
  )


proc add*(box: var Bounds2, p: Point2) =
  if box.empty:
    box = bounds2(p)
    return
  box.min = point2(min(box.min.x, p.x), min(box.min.y, p.y))
  box.max = point2(max(box.max.x, p.x), max(box.max.y, p.y))

proc add*(box: var Bounds2, other: Bounds2) =
  if other.empty: return
  box.add other.min
  box.add other.max

proc `+`*(box: Bounds2, other: Bounds2): Bounds2 =
  result = box
  result.add other


proc size*(box: Bounds2): V2 =
  box.max - box.min

proc center*(box: Bounds2): Point2 =
  box.min + (box.max - box.min) / 2


proc expanded*(box: Bounds2, amount: Float): Bounds2 =
  if box.empty: return box
  Bounds2(empty: false, min: box.min - v2(amount, amount), max: box.max + v2(amount, amount))

proc expanded*(box: Bounds2, margin: V2): Bounds2 =
  if box.empty: return box
  Bounds2(empty: false, min: box.min - margin, max: box.max + margin)


proc overlaps*(a, b: Bounds2, tolerance: Float = epsilon(Float)): bool =
  a.min.x <= b.max.x + tolerance and b.min.x <= a.max.x + tolerance and
  a.min.y <= b.max.y + tolerance and b.min.y <= a.max.y + tolerance


proc contains*(box: Bounds2, p: Point2, tolerance: Float = epsilon(Float)): bool =
  p.x >= box.min.x - tolerance and p.x <= box.max.x + tolerance and
  p.y >= box.min.y - tolerance and p.y <= box.max.y + tolerance
