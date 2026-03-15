import std/[math]
from std/fenv import epsilon

when defined(sigeo_use_float32):
  import pkg/vmath except Mat2, Mat3, Mat4, mat2, mat3, mat4, `$`, angle, isNaN
  export vmath except Mat2, Mat3, Mat4, mat2, mat3, mat4, `$`, angle, isNaN

elif true or defined(sigeo_use_float64):
  import pkg/vmath except Vec2, Vec3, Mat2, Mat3, Mat4, vec2, vec3, mat2, mat3, mat4, `$`, angle, isNaN
  export vmath except Vec2, Vec3, Mat2, Mat3, Mat4, vec2, vec3, mat2, mat3, mat4, `$`, angle, isNaN

import ../macros/[genAliases]


type
  FVec2* = GVec2[float32]
  FVec3* = GVec3[float32]
  FVec4* = GVec4[float32]

when defined(sigeo_use_float32):
  type
    Float* = float32

elif true or defined(sigeo_use_float64):
  type
    Float* = float64
    Vec2* = GVec2[float64]
    Vec3* = GVec3[float64]
    Vec4* = GVec4[float64]

type
  FloatParam* = distinct Float
    ## A float guaranteed to be from 0 to 1.

  NormalVec3* = distinct Vec3
    ## A vector guaranteed to be 1 unit long.


template genVecConstructors(lower, upper, typ: untyped) =
  ## Generate vector constructor for your own type.

  proc `lower 2`*(): `upper 2` = gvec2[typ](typ(0), typ(0))
  proc `lower 3`*(): `upper 3` = gvec3[typ](typ(0), typ(0), typ(0))
  proc `lower 4`*(): `upper 4` = gvec4[typ](typ(0), typ(0), typ(0), typ(0))

  proc `lower 2`*(x, y: typ): `upper 2` = gvec2[typ](x, y)
  proc `lower 3`*(x, y, z: typ): `upper 3` = gvec3[typ](x, y, z)
  proc `lower 4`*(x, y, z, w: typ): `upper 4` = gvec4[typ](x, y, z, w)

  proc `lower 2`*(x: typ): `upper 2` = gvec2[typ](x, x)
  proc `lower 3`*(x: typ): `upper 3` = gvec3[typ](x, x, x)
  proc `lower 4`*(x: typ): `upper 4` = gvec4[typ](x, x, x, x)

  proc `lower 2`*[T](x: GVec2[T]): `upper 2` =
    gvec2[typ](typ(x[0]), typ(x[1]))
  proc `lower 3`*[T](x: GVec3[T]): `upper 3` =
    gvec3[typ](typ(x[0]), typ(x[1]), typ(x[2]))
  proc `lower 4`*[T](x: GVec4[T]): `upper 4` =
    gvec4[typ](typ(x[0]), typ(x[1]), typ(x[2]), typ(x[3]))

  proc `lower 3`*[T](x: GVec2[T], z: T = 0): `upper 3` =
    gvec3[typ](typ(x[0]), typ(x[1]), z)
  proc `lower 4`*[T](x: GVec3[T], w: T = 0): `upper 4` =
    gvec4[typ](typ(x[0]), typ(x[1]), typ(x[2]), w)

  proc `lower 4`*[T](a, b: GVec2[T]): `upper 4` =
    gvec4[typ](typ(a[0]), typ(a[1]), typ(b[0]), typ(b[1]))


genVecConstructors(fvec, FVec, float32)

proc fvec2*(xy: FVec3): FVec2 {.inline.} = vmath.vec2(xy.x, xy.y)
proc fvec3*(xy: FVec2): FVec3 {.inline.} = vmath.vec3(xy.x, xy.y, 0)

proc fvec3*(xy: FVec2, z: float32): FVec3 {.inline.} = vmath.vec3(xy.x, xy.y, z)
proc fvec3*(x: float32, yz: FVec2): FVec3 {.inline.} = vmath.vec3(x, yz.x, yz.y)

proc fvec2*(x, y: float32): FVec2 {.inline.} = vmath.vec2(x, y)
proc fvec3*(x, y, z: float32): FVec3 {.inline.} = vmath.vec3(x, y, z)


when defined(sigeo_use_float32):
  discard

elif true or defined(sigeo_use_float64):
  genVecConstructors(vec, Vec, float64)


proc vec2*(xy: Vec3): Vec2 {.inline.} = vec2(xy.x, xy.y)
proc vec3*(xy: Vec2): Vec3 {.inline.} = vec3(xy.x, xy.y, 0)

proc vec3*(xy: Vec2, z: float64): Vec3 {.inline.} = vec3(xy.x, xy.y, z)
proc vec3*(x: float64, yz: Vec2): Vec3 {.inline.} = vec3(x, yz.x, yz.y)


proc almostEqual*(a, b: Vec2, unitsInLastSpace: Natural = 4): bool {.aliases: [`~==`].} =
  a.x.almostEqual(b.x, unitsInLastSpace) and
  a.y.almostEqual(b.y, unitsInLastSpace)

proc almostEqual*(a, b: Vec3, unitsInLastSpace: Natural = 4): bool {.aliases: [`~==`].} =
  a.x.almostEqual(b.x, unitsInLastSpace) and
  a.y.almostEqual(b.y, unitsInLastSpace) and
  a.z.almostEqual(b.z, unitsInLastSpace)


proc almostEqual*(a, b: Vec2, tolerance: float32): bool =
  (a.x == b.x or abs(a.x - b.x) < tolerance) and
  (a.y == b.y or abs(a.y - b.y) < tolerance)

proc almostEqual*(a, b: Vec3, tolerance: float32): bool =
  (a.x == b.x or abs(a.x - b.x) < tolerance) and
  (a.y == b.y or abs(a.y - b.y) < tolerance) and
  (a.z == b.z or abs(a.z - b.z) < tolerance)


template `~==`*(a, b: Float): bool =
  a.almostEqual(b)


proc almostEqualOrLess*(a, b: Float; unitsInLastPlace: Natural = 4): bool {.aliases: [`~<`].} =
  ## return true if a is less than b or almost equal to it
  a < b + epsilon(Float) * Float(unitsInLastPlace)

template almostEqualOrGreater*(a, b: Float; unitsInLastPlace: Natural = 4): bool {.aliases: [`~>`].} =
  almostEqualOrLess(b, a, unitsInLastPlace)


proc sureLess*(a, b: Float, unitsInLastPlace: Natural = 4): bool {.aliases: [`~!<`].} =
  ## return true if a is less than b and not almost equal to it
  a < b - epsilon(Float) * Float(unitsInLastPlace)

template sureGreater*(a, b: Float, unitsInLastPlace: Natural = 4): bool {.aliases: [`~!>`].} =
  sureLess(b, a, unitsInLastPlace)



proc signedAngleToPlusX*(a: Vec2): Float {.aliases: [angleToPlusX, angleToX, planarAngle, theta].} =
  ## returns the (signed) angle between a and +X axis in radians
  ## positive if a is counterclockwise from +X, negative otherwise
  ## use only when it's really needed, as it may lead to unoptimal code
  arctan2(a.y, a.x)


proc skew*(a, b: Vec2): Float {.aliases: [skewProduct, pseudoScalarProduct].} =
  ## returns pseudo scalar product, equal to a.length * b.length * sin(a.signedAngleTo(b))
  a.x * b.y - a.y * b.x


proc angleTo*(a, b: Vec2): Float =
  ## returns the (unsigned) angle between two vectors in radians
  let cosAngle = a.dot(b) / (a.length * b.length)
  if cosAngle > 1: return 0
  if cosAngle < -1: return PI

  when defined(sigeo_return_zero_when_angle_between_zeroLen_vectors):
    if cosAngle.isNaN:
      return 0

  elif defined(sigeo_return_nan_when_angle_between_zeroLen_vectors):
    discard

  elif true or defined(sigeo_raise_exception_when_angle_between_zeroLen_vectors):
    if cosAngle.isNaN:
      raise ValueError.newException("Cannot compute angle between zero-length vectors")

  arccos(cosAngle)


proc signedAngleTo*(a, b: Vec2): Float =
  ## returns the signed angle between two vectors in radians
  ## positive if b is counterclockwise from a, negative otherwise
  let cosAngle = a.dot(b) / (a.length * b.length)
  if cosAngle > 1: return 0
  if cosAngle < -1: return PI

  when defined(sigeo_return_zero_when_angle_between_zeroLen_vectors):
    if cosAngle.isNaN:
      return 0

  elif defined(sigeo_return_nan_when_angle_between_zeroLen_vectors):
    discard

  elif true or defined(sigeo_raise_exception_when_angle_between_zeroLen_vectors):
    if cosAngle.isNaN:
      raise ValueError.newException("Cannot compute angle between zero-length vectors")

  if a.skew(b) < 0:
    -arccos(cosAngle)
  else:
    arccos(cosAngle)


proc angleTo*(a, b: Vec3): Float =
  ## returns the (unsigned) angle between two 3D vectors in radians
  let cosAngle = a.dot(b) / (a.length * b.length)

  when defined(sigeo_return_zero_when_angle_between_zeroLen_vectors):
    if cosAngle.isNaN:
      return 0

  elif defined(sigeo_return_nan_when_angle_between_zeroLen_vectors):
    discard

  elif true or defined(sigeo_raise_exception_when_angle_between_zeroLen_vectors):
    if cosAngle.isNaN:
      raise ValueError.newException("Cannot compute angle between zero-length vectors")

  arccos(cosAngle)


proc toPolar*(v: Vec2): tuple[theta: Float, r: Float] =
  ## returns the polar coordinates of a 2D vector
  (v.signedAngleToPlusX, v.length)





proc param*(t: Float, min: Float = 0, max: Float = 1): FloatParam =
  t.clamp(min, max).FloatParam


converter toParam*(v: Float): FloatParam = v.param
converter toParam*(v: SomeNumber): FloatParam = v.Float.param
converter toUnspecified*(v: FloatParam): Float = v.Float



proc normal*(v: Vec3): NormalVec3 =
  when not defined(sigeo_assume_no_zeroLen_normal_vector):
    if v ~== vec3(0, 0, 0):
      when defined(sigeo_return_axisX_when_zeroLen_normal_vector):
        return vec3(1, 0, 0).NormalVec3

      elif true or defined(sigeo_raise_valueError_when_zeroLen_normal_vector):
        raise ValueError.newException("Zero length normal vector")

  normalize(v).NormalVec3


converter toNormal*(v: Vec3): NormalVec3 = v.normal
converter toUnspecified*(v: NormalVec3): Vec3 = v.Vec3



proc lenOnAxis*(v: Vec3, axis: NormalVec3): Float {.inline, aliases: [lengthOnAxis].} =
  v.dot(axis.Vec3)

proc projectToAxis*(v: Vec3, axis: NormalVec3): Vec3 {.inline.} =
  axis.Vec3 * v.lenOnAxis(axis)

proc ortoProject*(v: Vec3, normal: NormalVec3): Vec3 {.inline.} =
  v - v.projectToAxis(normal)


proc normal*(xAxis, yAxis: NormalVec3): NormalVec3 =
  ## returns a vector, perpendicular to `xAxis` and `yAxis`,
  ## and such that the smallest rotation around it from xAxis to yAxis is counter-clockwise
  result = xAxis.Vec3.cross(yAxis.Vec3).NormalVec3
  
  if result ~== vec3(0, 0, 0):
    when defined(sigeo_return_axisX_when_zeroLen_normal_vector):
      return vec3(1, 0, 0).NormalVec3

    elif true or defined(sigeo_raise_valueError_when_zeroLen_normal_vector):
      raise ValueError.newException("Zero length normal vector from collinear x and y axises")


proc rotate*(v: Vec2, angle_rad: Float): Vec2 =
  v * cos(angle_rad) + vec2(-v.y, v.x) * sin(angle_rad)


proc rotate_90deg_counterClockwise*(v: Vec2): Vec2 {.aliases: [rotate_90deg_left, rot90l, rot90cc].} =
  vec2(v.y, -v.x)

proc rotate_90deg_clockwise*(v: Vec2): Vec2 {.aliases: [rotate_90deg_right, rot90r, rot90c].} =
  vec2(-v.y, v.x)


proc rotate*(v: Vec3, axis: NormalVec3, angle: Float): Vec3 =
  v * cos(angle) + cross(v, axis.Vec3) * sin(angle) + axis.Vec3 * v.lenOnAxis(axis) * (1 - cos(angle))


proc rotateX*(v: Vec3, angle: Float): Vec3 =
  v.rotate(vec3(1, 0, 0).NormalVec3, angle)

proc rotateY*(v: Vec3, angle: Float): Vec3 =
  v.rotate(vec3(0, 1, 0).NormalVec3, angle)

proc rotateZ*(v: Vec3, angle: Float): Vec3 =
  v.rotate(vec3(0, 0, 1).NormalVec3, angle)


proc isParallel*(a, b: Vec2): bool =
  a.dot(b.rotate_90deg_counterClockwise) ~== 0

proc isPerpendicular*(a, b: Vec2): bool =
  a.dot(b) ~== 0

proc isCodirectional*(a, b: Vec2): bool =
  a / a.length ~== b / b.length


proc isParallel*(a, b: Vec3): bool =
  a.cross(b) ~== vec3()

proc isPerpendicular*(a, b: Vec3): bool =
  a.dot(b) ~== 0

proc isCodirectional*(a, b: Vec3): bool =
  a / a.length ~== b / b.length

