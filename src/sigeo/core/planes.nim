import ./[points, vectors]


type
  Mat2* = GMat2[Float]
  Mat3* = GMat3[Float]
  Mat4* = GMat4[Float]


genMatConstructor(mat, Mat, Float)


type
  CoordinateSystem* = object
    pos*: Point3
    axisX*, axisY*, axisZ*: NormalVec3
  
  Plane* = distinct CoordinateSystem


proc transformBy*(x: Vec3, cs: CoordinateSystem): Vec3 =
  ## returns a vector with transformation matrix applied, ignores translation
  cs.axisX * x.x + cs.axisY * x.y + cs.axisZ * x.z


proc transformBy*(x: Point3, cs: CoordinateSystem): Point3 =
  ## returns a point with transformation matrix applied, including translation
  cs.pos + cs.axisX * x.x + cs.axisY * x.y + cs.axisZ * x.z


proc transformBy*(x: Vec2, cs: CoordinateSystem): Vec3 =
  vec3(x.x, x.y, 0).transformBy(cs)

proc transformBy*(x: Point2, cs: CoordinateSystem): Point3 =
  point3(x.x, x.y, 0).transformBy(cs)


proc toMatrix*(cs: CoordinateSystem): Mat4 =
  mat4(
    cs.axisX.x, cs.axisY.x, cs.axisZ.x, 0,
    cs.axisX.y, cs.axisY.y, cs.axisZ.y, 0,
    cs.axisX.z, cs.axisY.z, cs.axisZ.z, 0,
    cs.pos.x, cs.pos.y, cs.pos.z, 1
  )

proc toCoordinateSystem*(m: Mat4): CoordinateSystem =
  result.axisX = vec3(m[0, 0], m[0, 1], m[0, 2]).normal
  result.axisY = vec3(m[1, 0], m[1, 1], m[1, 2]).normal
  result.axisZ = vec3(m[2, 0], m[2, 1], m[2, 2]).normal
  result.pos = point3(m[3, 0], m[3, 1], m[3, 2])



proc transformBy*(a, b: CoordinateSystem): CoordinateSystem =
  ## if a is transformatrion from b and b is transformatrion from world, returns coordinate system from world to entity
  result.pos = Point3 a.pos.Vec3.transformBy(b) + b.pos.Vec3
  result.axisX = a.axisX.Vec3.transformBy(b).normal
  result.axisY = a.axisY.Vec3.transformBy(b).normal
  result.axisZ = a.axisZ.Vec3.transformBy(b).normal
  


proc inverse*(cs: CoordinateSystem): CoordinateSystem =
  ## returns a coordinate system that transforms points from world to `cs` coordinate system
  cs.toMatrix.inverse.toCoordinateSystem


proc distanceToPlane*(point: Point3, plane_normal: NormalVec3, plane_basePoint: Point3): Float =
  ## returns distance to plane, defined by `normal` and `basePoint`
  (plane_basePoint - point).lenOnAxis(plane_normal).abs  # length of projection of vector from basePoint to point onto normal

proc distanceToPlane*(point: Point3, cs: Plane): Float =
  ## returns distance to plane, defined by `cs`
  point.distanceToPlane(cs.CoordinateSystem.axisZ, cs.CoordinateSystem.pos)


proc signedDistanceToPlane*(point: Point3, plane_normal: NormalVec3, plane_basePoint: Point3): Float =
  ## returns distance to plane, defined by `normal` and `basePoint`
  ## negative if point is below plane (vector from plane to point is counter-directed to normal vector of the plane)
  (plane_basePoint - point).lenOnAxis(plane_normal)

proc signedDistanceToPlane*(point: Point3, cs: Plane): Float =
  ## returns distance to plane, defined by `cs`
  ## negative if point is below plane (vector from plane to point is counter-directed to normal vector of the plane)
  point.signedDistanceToPlane(cs.CoordinateSystem.axisZ, cs.CoordinateSystem.pos)


proc toWorld*(point: Point3, cs: CoordinateSystem): Point3 =
  ## returns a point in world coordinate system, from point in `cs` coordinate system
  #runnableExamples:
  #  doAssert point3(1, 2, 0).toWorld(plane(vec3(0, 1, 0), point3(1, 1, 1)).CoordinateSystem).almostEqual(point3(2, 1, -1))

  point.transformBy(cs)

proc fromWorld*(point: Point3, cs: CoordinateSystem): Point3 =
  ## returns a point in `cs` coordinate system, from point in world coordinate system
  point.transformBy(cs.inverse)


proc toWorld*(point: Point2, cs: CoordinateSystem): Point3 =
  ## returns a point in world coordinate system, from point in `cs` coordinate system
  point3(point.x, point.y, 0).toWorld(cs)


proc toWorld*(point: Point2, cs: Plane): Point3 =
  ## returns a point in world coordinate system, from point at plane
  point3(point.x, point.y, 0).toWorld(cs.CoordinateSystem)


proc toWorld*(point: Point3, cs: Plane): Point3 =
  ## returns a point in world coordinate system, from point at plane
  ## where point.z treated as "height" over plane (can be negative)
  point.toWorld(cs.CoordinateSystem)


proc toPlanar*(point: Point3, cs: Plane): Point2 =
  ## returns a point in `cs` coordinate system, closest to `point`
  var p = point.fromWorld(cs.CoordinateSystem)
  point2(p.x, p.y)


proc toPlanar*(v: Vec3, axisX, axisY: NormalVec3): Vec2 =
  ## returns a 2d vector in `cs` coordinate system
  vec2(v.lenOnAxis(axisX), v.lenOnAxis(axisY))

proc toPlanar*(v: Vec3, cs: Plane): Vec2 =
  ## returns a 2d vector in `cs` coordinate system
  v.toPlanar(cs.CoordinateSystem.axisX, cs.CoordinateSystem.axisY)


proc ortoProjectToPlane*(point: Point3, cs: Plane): Point3 =
  ## returns a point on plane in world coordinates, closest to `point`
  point - cs.CoordinateSystem.axisZ * point.signedDistanceToPlane(cs.CoordinateSystem.axisZ, cs.CoordinateSystem.pos)


proc ortoProjectToPlane*(v: Vec3, axisZ: NormalVec3): Vec3 =
  ## returns a vector on plane in world coordinates, closest to `v`
  v - axisZ * v.lenOnAxis(axisZ)

proc ortoProjectToPlane*(v: Vec3, cs: Plane): Vec3 =
  ## returns a vector on plane in world coordinates, closest to `v`
  v - cs.CoordinateSystem.axisZ * v.lenOnAxis(cs.CoordinateSystem.axisZ)



proc plane*(normal: NormalVec3, basePoint: Point3, xAxis: NormalVec3): Plane =
  ## returns a matrix, representing a coordinate system, perpendicular to the `normal` vector
  CoordinateSystem(
    pos: basePoint,
    axisX: xAxis,
    axisY: normal(normal, xAxis),
    axisZ: normal
  ).Plane


proc plane*(normal: NormalVec3, basePoint: Point3 = point3(0, 0, 0)): Plane =
  ## return a matrix, representing a coordinate system, perpendicular to the `normal` vector
  ## tries to pick reasonable x and y axis
  result.CoordinateSystem.pos = basePoint
  
  if normal.Vec3 ~== vec3(0, 0, 1):
    result.CoordinateSystem.axisX = vec3(1, 0, 0).NormalVec3
  elif normal.Vec3 ~== vec3(0, 0, -1):
    result.CoordinateSystem.axisX = vec3(-1, 0, 0).NormalVec3
  else:
    result.CoordinateSystem.axisX = normal.Vec3.ortoProject(vec3(0, 0, 1).NormalVec3).rotateZ(-PI / 2).normal
  
  result.CoordinateSystem.axisY = normal.Vec3.cross(result.CoordinateSystem.axisX.Vec3).normal
  result.CoordinateSystem.axisZ = normal


proc plane*(point1, point2, point3: Point3): Plane =
  ## returns a plane defined by 3 points
  ## x axis is defined by vector from point1 to point2
  plane((point2 - point1).cross(point3 - point1).normal, point1, (point2 - point1).normal)



when isMainModule:
  import print
  
  print vec3(1, 0, 0).cross(vec3(0, 1, 0))
  let p = plane(vec3(0, 1, 0).NormalVec3, point3(1, 1, 1), vec3(1, 0, 0).NormalVec3).CoordinateSystem
  print point3(1, 1, 1).distanceToPlane(vec3(0, 0, 1).NormalVec3, point3(-1, 0, -1))
  print point3(1, 2, 0).toWorld(p)
  print point3(1, 2, 0).toWorld(p).fromWorld(p)

  print vec3(9 / 15 + 1e-16, 1, 7 / 13) == vec3(3 / 5, 1, 7 / 13)
  print vec3(9 / 15 + 1e-16, 1, 7 / 13) ~== vec3(3 / 5, 1, 7 / 13)

  print plane(vec3(1, 1, 1).normal)
  print plane(-vec3(1, 1, 1).normal)

  print vec2(1, 1).angleTo(vec2(0, 1)).toDegrees.round
  print vec2(1, 1).angleTo(vec2(1, 0)).toDegrees.round
  print vec2(1, 1).angleTo(vec2(-1, -1)).toDegrees.round
  print vec2(1, 1).angleTo(vec2(1, -2)).toDegrees.round

  print vec2(1, 1).signedAngleTo(vec2(0, 1)).toDegrees.round
  print vec2(1, 1).signedAngleTo(vec2(1, 0)).toDegrees.round
  print vec2(1, 1).signedAngleTo(vec2(-1, -1)).toDegrees.round
  print vec2(1, 1).signedAngleTo(vec2(1, -2)).toDegrees.round

