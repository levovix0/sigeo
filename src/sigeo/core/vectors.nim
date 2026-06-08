import std/[math]
from std/fenv import epsilon

import pkg/vmath except Vec2, Vec3, Mat2, Mat3, Mat4, vec2, vec3, mat2, mat3, mat4, `$`, angle, isNaN
export vmath except Vec2, Vec3, Mat2, Mat3, Mat4, vec2, vec3, mat2, mat3, mat4, `$`, angle, isNaN

import ../macros/[genAliases]

const sigeo_axisY_up* = defined(sigeo_axisY_up) or not defined(sigeo_axisY_down)
  ## when true (default), Y axis points up (CCW arcs go in positive angle direction)
  ## set to false (-d:sigeoYAxisUp=false) for screen/pixel coordinates where Y points down


when defined(sigeo_use_float32):
  type
    Float* = float32
    V1* = float32
    V2* = vmath.Vec2
    V3* = vmath.Vec3
    V4* = vmath.Vec4
    M2* = vmath.Mat2
    M3* = vmath.Mat3
    M4* = vmath.Mat4

elif true or defined(sigeo_use_float64):
  ## many computational geometry libraries use float64 by default, but vmath already uses float32,
  ## so to distinguish "geometry" vectors from "graphics" vectors they are named V2/V3, instead of Vec2/Vec3

  type
    Float* = float64
    V1* = float64
    V2* = vmath.DVec2
    V3* = vmath.DVec3
    V4* = vmath.DVec4
    M2* = vmath.DMat2
    M3* = vmath.DMat3
    M4* = vmath.DMat4

type
  FloatParam* = distinct Float
    ## A float guaranteed to be from 0 to 1.

  NormalVec2* = distinct V2
    ## A Vec2 guaranteed to be 1 unit long.

  NormalVec3* = distinct V3
    ## A Vec3 guaranteed to be 1 unit long.
  

  NV1* = FloatParam
    ## A float guaranteed to be from 0 to 1.

  NV2* = NormalVec2
    ## A Vec2 guaranteed to be 1 unit long.

  NV3* = NormalVec3
    ## A Vec3 guaranteed to be 1 unit long.


  AngleDirection* = enum
    counterclockwise
    clockwise


template genOnlyVecConstructors(lower, upper, typ: untyped) =
  ## Generate vector constructor for your own type.
  ## Theese are only diffirent from vmath ones that theese don't generate the `$` procs
  ## todo: propose to split `$` and constructor generation to vmath

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


template genOnlyMatConstructors(lower, upper, T: untyped) =
  ## Generate matrix constructor for your own type.
  ## Theese are only diffirent from vmath ones that theese don't generate the `$` procs

  proc `lower 2`*(
    m00, m01,
    m10, m11: T
  ): `upper 2` =
    result[0, 0] = m00; result[0, 1] = m01
    result[1, 0] = m10; result[1, 1] = m11

  proc `lower 3`*(
    m00, m01, m02,
    m10, m11, m12,
    m20, m21, m22: T
  ): `upper 3` =
    result[0, 0] = m00; result[0, 1] = m01; result[0, 2] = m02
    result[1, 0] = m10; result[1, 1] = m11; result[1, 2] = m12
    result[2, 0] = m20; result[2, 1] = m21; result[2, 2] = m22

  proc `lower 4`*(
    m00, m01, m02, m03,
    m10, m11, m12, m13,
    m20, m21, m22, m23,
    m30, m31, m32, m33: T
  ): `upper 4` =
    result[0, 0] = m00; result[0, 1] = m01
    result[0, 2] = m02; result[0, 3] = m03

    result[1, 0] = m10; result[1, 1] = m11
    result[1, 2] = m12; result[1, 3] = m13

    result[2, 0] = m20; result[2, 1] = m21
    result[2, 2] = m22; result[2, 3] = m23

    result[3, 0] = m30; result[3, 1] = m31
    result[3, 2] = m32; result[3, 3] = m33

  proc `lower 2`*(a, b: GVec2[T]): `upper 2` =
    gmat2[T](
      a.x, a.y,
      b.x, b.y
    )
  proc `lower 3`*(a, b, c: GVec3[T]): `upper 3` =
    gmat3[T](
      a.x, a.y, a.z,
      b.x, b.y, b.z,
      c.x, c.y, c.z,
    )
  proc `lower 4`*(a, b, c, d: GVec4[T]): `upper 4` =
    gmat4[T](
      a.x, a.y, a.z, a.w,
      b.x, b.y, b.z, b.w,
      c.x, c.y, c.z, c.w,
      d.x, d.y, d.z, d.w,
    )

  proc `lower 2`*(): `upper 2` =
    gmat2[T](
      1.T, 0.T,
      0.T, 1.T
    )
  proc `lower 3`*(): `upper 3` =
    gmat3[T](
      1.T, 0.T, 0.T,
      0.T, 1.T, 0.T,
      0.T, 0.T, 1.T
    )
  proc `lower 4`*(): `upper 4` =
    gmat4[T](
      1.T, 0.T, 0.T, 0.T,
      0.T, 1.T, 0.T, 0.T,
      0.T, 0.T, 1.T, 0.T,
      0.T, 0.T, 0.T, 1.T
    )


when defined(sigeo_use_float32):
  genOnlyVecConstructors(v, V, float32)
  genOnlyMatConstructors(m, M, float32)

elif true or defined(sigeo_use_float64):
  genOnlyVecConstructors(v, V, float64)
  genOnlyMatConstructors(m, M, float64)


proc v2*(xy: V3): V2 {.inline.} = v2(xy.x, xy.y)
proc v3*(xy: V2): V3 {.inline.} = v3(xy.x, xy.y, 0)

proc v3*(xy: V2, z: float64): V3 {.inline.} = v3(xy.x, xy.y, z)
proc v3*(x: float64, yz: V2): V3 {.inline.} = v3(x, yz.x, yz.y)


proc almostEqual*(a, b: V2, unitsInLastSpace: Natural = 4): bool {.aliases: [`~==`].} =
  a.x.almostEqual(b.x, unitsInLastSpace) and
  a.y.almostEqual(b.y, unitsInLastSpace)

proc almostEqual*(a, b: V3, unitsInLastSpace: Natural = 4): bool {.aliases: [`~==`].} =
  a.x.almostEqual(b.x, unitsInLastSpace) and
  a.y.almostEqual(b.y, unitsInLastSpace) and
  a.z.almostEqual(b.z, unitsInLastSpace)


proc almostEqual*(a, b: V2, tolerance: float32): bool =
  (a.x == b.x or abs(a.x - b.x) < tolerance) and
  (a.y == b.y or abs(a.y - b.y) < tolerance)

proc almostEqual*(a, b: V3, tolerance: float32): bool =
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



proc signedAngleToPlusX*(a: V2): Float {.aliases: [angleToPlusX, angleToX, planarAngle, theta].} =
  ## returns the (signed) angle between a and +X axis in radians
  ## positive if a is counterclockwise from +X, negative otherwise
  ## use only when it's really needed, as it may lead to unoptimal code
  arctan2(a.y, a.x)


proc skew*(a, b: V2): Float {.aliases: [skewProduct, pseudoScalarProduct].} =
  ## returns pseudo scalar product, equal to a.length * b.length * sin(a.signedAngleTo(b))
  a.x * b.y - a.y * b.x


proc angleTo*(a, b: V2): Float =
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


proc signedAngleTo*(a, b: V2): Float =
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


proc angleTo*(a, b: V3): Float =
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


proc toPolar*(v: V2): tuple[theta: Float, r: Float] =
  ## returns the polar coordinates of a 2D vector
  (v.signedAngleToPlusX, v.length)





proc param*(t: Float, min: Float = 0, max: Float = 1): FloatParam =
  t.clamp(min, max).FloatParam


converter toParam*(v: Float): FloatParam = v.param
converter toParam*(v: SomeNumber): FloatParam = v.Float.param
converter toUnspecified*(v: FloatParam): Float = v.Float



proc normal*(v: V2): NormalVec2 =
  when not defined(sigeo_assume_no_zeroLen_normal_vector):
    if v ~== v2(0, 0):
      when defined(sigeo_return_axisX_when_zeroLen_normal_vector):
        return v2(1, 0).NormalVec2

      elif true or defined(sigeo_raise_valueError_when_zeroLen_normal_vector):
        raise ValueError.newException("Zero length normal vector")

  normalize(v).NormalVec2


proc normal*(v: V3): NormalVec3 =
  when not defined(sigeo_assume_no_zeroLen_normal_vector):
    if v ~== v3(0, 0, 0):
      when defined(sigeo_return_axisX_when_zeroLen_normal_vector):
        return v3(1, 0, 0).NormalVec3

      elif true or defined(sigeo_raise_valueError_when_zeroLen_normal_vector):
        raise ValueError.newException("Zero length normal vector")

  normalize(v).NormalVec3


converter toNormal*(v: V2): NormalVec2 = v.normal
converter toUnspecified*(v: NormalVec2): V2 = v.V2


converter toNormal*(v: V3): NormalVec3 = v.normal
converter toUnspecified*(v: NormalVec3): V3 = v.V3


# todo: make procs generic (use GVec2)

proc lenOnAxis*(v: V2, axis: NormalVec2): Float {.inline, aliases: [lengthOnAxis].} =
  v.dot(axis.V2)

proc projectToAxis*(v: V2, axis: NormalVec2): V2 {.inline.} =
  axis.V2 * v.lenOnAxis(axis)

proc ortoProject*(v: V2, normal: NormalVec2): V2 {.inline.} =
  v - v.projectToAxis(normal)



proc lenOnAxis*(v: V3, axis: NormalVec3): Float {.inline, aliases: [lengthOnAxis].} =
  v.dot(axis.V3)

proc projectToAxis*(v: V3, axis: NormalVec3): V3 {.inline.} =
  axis.V3 * v.lenOnAxis(axis)

proc ortoProject*(v: V3, normal: NormalVec3): V3 {.inline.} =
  v - v.projectToAxis(normal)


proc normal*(xAxis, yAxis: NormalVec3): NormalVec3 =
  ## returns a vector, perpendicular to `xAxis` and `yAxis`,
  ## and such that the smallest rotation around it from xAxis to yAxis is counter-clockwise
  result = xAxis.V3.cross(yAxis.V3).NormalVec3
  
  if result ~== v3(0, 0, 0):
    when defined(sigeo_return_axisX_when_zeroLen_normal_vector):
      return v3(1, 0, 0).NormalVec3

    elif true or defined(sigeo_raise_valueError_when_zeroLen_normal_vector):
      raise ValueError.newException("Zero length normal vector from collinear x and y axises")


proc rotate*(v: V2, angle_rad: Float): V2 =
  v * cos(angle_rad) + v2(-v.y, v.x) * sin(angle_rad)


proc rotate_90deg_counterClockwise*(v: V2): V2 {.aliases: [rotate_90deg_left, rot90l, rot90cc].} =
  v2(v.y, -v.x)

proc rotate_90deg_clockwise*(v: V2): V2 {.aliases: [rotate_90deg_right, rot90r, rot90c].} =
  v2(-v.y, v.x)


proc rotate*(v: V3, axis: NormalVec3, angle: Float): V3 =
  v * cos(angle) + cross(v, axis.V3) * sin(angle) + axis.V3 * v.lenOnAxis(axis) * (1 - cos(angle))


proc rotateX*(v: V3, angle: Float): V3 =
  v.rotate(v3(1, 0, 0).NormalVec3, angle)

proc rotateY*(v: V3, angle: Float): V3 =
  v.rotate(v3(0, 1, 0).NormalVec3, angle)

proc rotateZ*(v: V3, angle: Float): V3 =
  v.rotate(v3(0, 0, 1).NormalVec3, angle)


proc isParallel*(a, b: V2): bool =
  a.dot(b.rotate_90deg_counterClockwise) ~== 0

proc isPerpendicular*(a, b: V2): bool =
  a.dot(b) ~== 0

proc isCodirectional*(a, b: V2): bool =
  a / a.length ~== b / b.length


proc isParallel*(a, b: V3): bool =
  a.cross(b) ~== v3()

proc isPerpendicular*(a, b: V3): bool =
  a.dot(b) ~== 0

proc isCodirectional*(a, b: V3): bool =
  a / a.length ~== b / b.length

