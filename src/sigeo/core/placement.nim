import ./[points, vectors]
import ../macros/[genAliases]


type
  Placement* = object
    pos*: Point3
    axisX*, axisY*, axisZ*: NormalVec3


proc origin*(plane: Placement): Point3 {.aliases: [center].} =
  plane.pos

proc xAxis*(plane: Placement): NormalVec3 =
  plane.axisX

proc yAxis*(plane: Placement): NormalVec3 =
  plane.axisY

proc zAxis*(plane: Placement): NormalVec3 =
  plane.axisZ


proc transformBy*(x: V3, cs: Placement): V3 =
  ## returns a vector with transformation matrix applied, ignores translation
  cs.axisX * x.x + cs.axisY * x.y + cs.axisZ * x.z


proc transformBy*(x: Point3, cs: Placement): Point3 =
  ## returns a point with transformation matrix applied, including translation
  cs.pos + cs.axisX * x.x + cs.axisY * x.y + cs.axisZ * x.z


proc transformBy*(x: V2, cs: Placement): V3 =
  v3(x.x, x.y, 0).transformBy(cs)

proc transformBy*(x: Point2, cs: Placement): Point3 =
  point3(x.x, x.y, 0).transformBy(cs)


proc toMatrix*(cs: Placement): M4 =
  m4(
    cs.axisX.x, cs.axisX.y, cs.axisX.z, 0,
    cs.axisY.x, cs.axisY.y, cs.axisY.z, 0,
    cs.axisZ.x, cs.axisZ.y, cs.axisZ.z, 0,
    cs.pos.x, cs.pos.y, cs.pos.z, 1
  )

proc toPlacement*(m: M4): Placement =
  result.axisX = v3(m[0, 0], m[0, 1], m[0, 2]).normal
  result.axisY = v3(m[1, 0], m[1, 1], m[1, 2]).normal
  result.axisZ = v3(m[2, 0], m[2, 1], m[2, 2]).normal
  result.pos = point3(m[3, 0], m[3, 1], m[3, 2])



proc transformBy*(a, b: Placement): Placement =
  ## if a is transformatrion from b and b is transformatrion from world, returns coordinate system from world to entity
  result.pos = Point3 a.pos.V3.transformBy(b) + b.pos.V3
  result.axisX = a.axisX.V3.transformBy(b).normal
  result.axisY = a.axisY.V3.transformBy(b).normal
  result.axisZ = a.axisZ.V3.transformBy(b).normal
  


proc inverse*(cs: Placement): Placement =
  ## returns a coordinate system that transforms points from world to `cs` coordinate system
  cs.toMatrix.inverse.toPlacement


proc distanceToPlane*(point: Point3, plane_normal: NormalVec3, plane_basePoint: Point3): Float =
  ## returns distance to plane, defined by `normal` and `basePoint`
  (plane_basePoint - point).lenOnAxis(plane_normal).abs  # length of projection of vector from basePoint to point onto normal

proc distanceToPlane*(point: Point3, plane: Placement): Float =
  ## returns distance to plane, defined by `cs`
  point.distanceToPlane(plane.axisZ, plane.pos)


proc signedDistanceToPlane*(point: Point3, plane_normal: NormalVec3, plane_basePoint: Point3): Float =
  ## returns distance to plane, defined by `normal` and `basePoint`
  ## negative if point is below plane (vector from plane to point is counter-directed to normal vector of the plane)
  (plane_basePoint - point).lenOnAxis(plane_normal)

proc signedDistanceToPlane*(point: Point3, plane: Placement): Float =
  ## returns distance to plane, defined by `cs`
  ## negative if point is below plane (vector from plane to point is counter-directed to normal vector of the plane)
  point.signedDistanceToPlane(plane.axisZ, plane.pos)


proc toWorld*(point: Point3, cs: Placement): Point3 =
  ## returns a point in world coordinate system, from point in `cs` coordinate system
  #runnableExamples:
  #  doAssert point3(1, 2, 0).toWorld(plane(vec3(0, 1, 0), point3(1, 1, 1)).Placement).almostEqual(point3(2, 1, -1))

  point.transformBy(cs)

proc fromWorld*(point: Point3, cs: Placement): Point3 =
  ## returns a point in `cs` coordinate system, from point in world coordinate system
  point.transformBy(cs.inverse)


proc toWorld*(point: Point2, cs: Placement): Point3 =
  ## returns a point in world coordinate system, from point in `cs` coordinate system
  point3(point.x, point.y, 0).toWorld(cs)


proc toPlanar*(point: Point3, plane: Placement): Point2 =
  ## returns a point in `plane` coordinate system, closest to `point`
  var p = point.fromWorld(plane)
  point2(p.x, p.y)


proc toPlanar*(v: V3, axisX, axisY: NormalVec3): V2 =
  ## returns a 2d vector in `cs` coordinate system
  v2(v.lenOnAxis(axisX), v.lenOnAxis(axisY))

proc toPlanar*(v: V3, plane: Placement): V2 =
  ## returns a 2d vector in `plane` coordinate system
  v.toPlanar(plane.axisX, plane.axisY)


proc ortoProjectToPlane*(point: Point3, plane: Placement): Point3 =
  ## returns a point on plane in world coordinates, closest to `point`
  point - plane.axisZ * point.signedDistanceToPlane(plane.axisZ, plane.pos)


proc ortoProjectToPlane*(v: V3, axisZ: NormalVec3): V3 =
  ## returns a vector on plane in world coordinates, closest to `v`
  v - axisZ * v.lenOnAxis(axisZ)

proc ortoProjectToPlane*(v: V3, plane: Placement): V3 =
  ## returns a vector on plane in world coordinates, closest to `v`
  v - plane.axisZ * v.lenOnAxis(plane.axisZ)



proc placement*(normal: NormalVec3, basePoint: Point3, xAxis: NormalVec3): Placement {.aliases: [plane].} =
  ## returns a matrix, representing a coordinate system, perpendicular to the `normal` vector
  Placement(
    pos: basePoint,
    axisX: xAxis,
    axisY: normal(normal, xAxis),
    axisZ: normal
  )


proc placement*(normal: NormalVec3, basePoint: Point3 = point3(0, 0, 0)): Placement {.aliases: [plane].}  =
  ## return a matrix, representing a coordinate system, perpendicular to the `normal` vector
  ## tries to pick reasonable x and y axis
  result.pos = basePoint
  
  if normal.V3 ~== v3(0, 0, 1):
    result.axisX = v3(1, 0, 0).NormalVec3
  elif normal.V3 ~== v3(0, 0, -1):
    result.axisX = v3(-1, 0, 0).NormalVec3
  else:
    result.axisX = normal.V3.ortoProject(v3(0, 0, 1).NormalVec3).rotateZ(-PI / 2).normal
  
  result.axisY = normal.V3.cross(result.axisX.V3).normal
  result.axisZ = normal


proc placement*(point1, point2, point3: Point3): Placement {.aliases: [plane].} =
  ## returns a plane defined by 3 points
  ## x axis is defined by vector from point1 to point2
  placement((point2 - point1).cross(point3 - point1).normal, point1, (point2 - point1).normal)


when isMainModule:
  import print
  
  print v3(1, 0, 0).cross(v3(0, 1, 0))
  let p = placement(v3(0, 1, 0).NormalVec3, point3(1, 1, 1), v3(1, 0, 0).NormalVec3)
  print point3(1, 1, 1).distanceToPlane(v3(0, 0, 1).NormalVec3, point3(-1, 0, -1))
  print point3(1, 2, 0).toWorld(p)
  print point3(1, 2, 0).toWorld(p).fromWorld(p)

  print v3(9 / 15 + 1e-16, 1, 7 / 13) == v3(3 / 5, 1, 7 / 13)
  print v3(9 / 15 + 1e-16, 1, 7 / 13) ~== v3(3 / 5, 1, 7 / 13)

  print placement(v3(1, 1, 1).normal)
  print placement(-v3(1, 1, 1).normal)

  print v2(1, 1).angleTo(v2(0, 1)).toDegrees.round
  print v2(1, 1).angleTo(v2(1, 0)).toDegrees.round
  print v2(1, 1).angleTo(v2(-1, -1)).toDegrees.round
  print v2(1, 1).angleTo(v2(1, -2)).toDegrees.round

  print v2(1, 1).signedAngleTo(v2(0, 1)).toDegrees.round
  print v2(1, 1).signedAngleTo(v2(1, 0)).toDegrees.round
  print v2(1, 1).signedAngleTo(v2(-1, -1)).toDegrees.round
  print v2(1, 1).signedAngleTo(v2(1, -2)).toDegrees.round

