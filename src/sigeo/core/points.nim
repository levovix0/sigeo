import ../macros/[genAliases]
import ./vectors

type
  Point2* = distinct V2

  Point3* = distinct V3

  P2* = Point2
  P3* = Point3


proc point2*(): Point2 {.aliases: [p2].} =
  v2().Point2

proc point3*(): Point3 {.aliases: [p3].} =
  v3().Point3


proc point2*(x, y: Float): Point2 {.aliases: [p2].} =
  v2(x, y).Point2

proc point3*(x, y, z: Float): Point3 {.aliases: [p3].} =
  v3(x, y, z).Point3


template x*(p: Point2): Float = p.V2.x
template y*(p: Point2): Float = p.V2.y

template x*(p: Point3): Float = p.V3.x
template y*(p: Point3): Float = p.V3.y
template z*(p: Point3): Float = p.V3.z


proc `x=`*(p: var Point2, v: Float) = p.V2.x = v
proc `y=`*(p: var Point2, v: Float) = p.V2.y = v

proc `x=`*(p: var Point3, v: Float) = p.V3.x = v
proc `y=`*(p: var Point3, v: Float) = p.V3.y = v
proc `z=`*(p: var Point3, v: Float) = p.V3.z = v


template toPoint*(v: V2): Point2 = v.Point2
template toPoint*(v: V3): Point3 = v.Point3

template toVec*(p: Point2): V2 = p.V2
template toVec*(p: Point3): V3 = p.V3


proc `$`*(v: Point2): string =
  "point2(" & $v.x & ", " & $v.y & ")"

proc `$`*(v: Point3): string =
  "point3(" & $v.x & ", " & $v.y & ", " & $v.z & ")"


proc `==`*(a, b: Point2): bool {.borrow.}
proc `==`*(a, b: Point3): bool {.borrow.}


proc xy*(p: Point3): Point2 =
  v2(p.x, p.y).Point2

proc xz*(p: Point3): Point2 =
  v2(p.x, p.z).Point2

proc yz*(p: Point3): Point2 =
  v2(p.y, p.z).Point2

proc yx*(p: Point3): Point2 =
  v2(p.y, p.x).Point2

proc zx*(p: Point3): Point2 =
  v2(p.z, p.x).Point2

proc zy*(p: Point3): Point2 =
  v2(p.z, p.y).Point2


proc `xy=`*(p: var Point3, v: Point2) =
  p.x = v.x; p.y = v.y

proc `xz=`*(p: var Point3, v: Point2) =
  p.x = v.x; p.z = v.y

proc `yz=`*(p: var Point3, v: Point2) =
  p.y = v.x; p.z = v.y

proc `yx=`*(p: var Point3, v: Point2) =
  p.y = v.x; p.x = v.y

proc `zx=`*(p: var Point3, v: Point2) =
  p.z = v.x; p.x = v.y

proc `zy=`*(p: var Point3, v: Point2) =
  p.z = v.x; p.y = v.y


proc `-`*(a, b: Point2): V2 {.borrow.}
proc `-`*(a, b: Point3): V3 {.borrow.}


proc distanceTo*(a, b: Point2): Float =
  (b - a).length

proc distanceTo*(a, b: Point3): Float =
  (b - a).length


proc vecTo*(a, b: Point2): V2 {.inline.} =
  b - a

proc vecTo*(a, b: Point3): V3 {.inline.} =
  b - a


proc `+`*(a: Point2, b: V2): Point2 =
  (a.V2 + b).Point2

proc `+`*(a: Point3, b: V3): Point3 =
  (a.V3 + b).Point3


proc `-`*(a: Point2, b: V2): Point2 =
  (a.V2 - b).Point2

proc `-`*(a: Point3, b: V3): Point3 =
  (a.V3 - b).Point3


proc `+`*(a: V2, b: Point2): Point2 {.inline.} =
  b + a

proc `+`*(a: V3, b: Point3): Point3 {.inline.} =
  b + a


proc `+=`*(a: var Point2, b: V2) {.inline.} =
  a = a + b

proc `+=`*(a: var Point3, b: V3) {.inline.} =
  a = a + b


proc `-=`*(a: var Point2, b: V2) {.inline.} =
  a = a - b

proc `-=`*(a: var Point3, b: V3) {.inline.} =
  a = a - b


proc almostEqual*(a, b: Point2, unitsInLastSpace: Natural = 4): bool {.borrow, aliases: [`~==`].}
proc almostEqual*(a, b: Point3, unitsInLastSpace: Natural = 4): bool {.borrow, aliases: [`~==`].}


proc almostEqual*(a, b: Point2, tolerance: Float): bool {.borrow.}
proc almostEqual*(a, b: Point3, tolerance: Float): bool {.borrow.}


template `~!=`*[T](a, b: T): bool = not(a ~== b)

