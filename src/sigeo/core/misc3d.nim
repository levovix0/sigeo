import ../macros/[genAliases]
import ./[vectors, points]

type
  Ray3* {.aliases: [Ray3d].} = object
    origin* #[{.aliases: [o, p].}]#: Point3
    dir* #[{.aliases: [d, direction].}]#: Vec3
  
  Triangle2* {.aliases: [Triangle2d].} = object
    p1*, p2*, p3*: Point2

  Triangle3* {.aliases: [Triangle3d].} = object
    p1*, p2*, p3*: Point3


proc length*(ray: Ray3): Float {.aliases: [len].} =
  ray.dir.length


proc normal*(triangle: Triangle3): NormalVec3 =
  normal((triangle.p2 - triangle.p1).normal, (triangle.p3 - triangle.p1).normal)


proc signedDistanceToPlane*(ray: Ray3, origin: Point3, normal: NormalVec3): Float =
  ## a distance to hit a point on a plane via `ray`
  let l = (ray.origin - origin).lenOnAxis(normal)
  if l ~== 0: return 0

  let dl = ray.dir.normal.lenOnAxis(normal)
  if dl ~== 0:
    when defined(sigeo_return_nan_when_parallel_raycast):
      return NaN

    elif true or defined(sigeo_raise_error_when_parallel_raycast):
      raise ValueError.newException("ray cannot hit the plane, they are parallel")

  l / dl


proc overlaps*(p: Point2, tri: Triangle2): bool =
  # from treeform/bumpy

  # get the area of the triangle
  let areaOrig = abs(
    (tri.p2.x - tri.p1.x) * (tri.p3.y - tri.p1.y) -
    (tri.p3.x - tri.p1.x) * (tri.p2.y - tri.p1.y)
  )

  # get the area of 3 triangles made between the point
  # and the corners of the triangle
  let
    area1 = abs((tri.p1.x - p.x) * (tri.p2.y - p.y) - (tri.p2.x - p.x) * (tri.p1.y - p.y))
    area2 = abs((tri.p2.x - p.x) * (tri.p3.y - p.y) - (tri.p3.x - p.x) * (tri.p2.y - p.y))
    area3 = abs((tri.p3.x - p.x) * (tri.p1.y - p.y) - (tri.p1.x - p.x) * (tri.p3.y - p.y))

  # If the sum of the three areas equals the original,
  # we're inside the triangle!
  area1 + area2 + area3 == areaOrig


proc overlapsAssumingInSamePlane*(pt: Point3, triangle: Triangle3): bool =
  let x = (triangle.p2 - triangle.p1).normal
  var y = (triangle.p3 - triangle.p1).normal
  y = (y - y.lenOnAxis(x)).normal

  let pt2d = point2((pt - triangle.p1).lenOnAxis(x), (pt - triangle.p1).lenOnAxis(y))
  let tri2d = Triangle2(
    p1: point2(0, 0),
    p2: point2((triangle.p2 - triangle.p1).lenOnAxis(x), (triangle.p2 - triangle.p1).lenOnAxis(y)),
    p3: point2((triangle.p3 - triangle.p1).lenOnAxis(x), (triangle.p3 - triangle.p1).lenOnAxis(y)),
  )

  overlaps(pt2d, tri2d)



proc raycast*(ray: Ray3, triangle: Triangle3): tuple[hit: bool, point: Point3, distance: Float] =
  ## todo: a nimony type plugin, that optimizes computation if only one of the outputs is used by caller
  var triNormal = triangle.normal

  try:
    result.distance = signedDistanceToPlane(ray, triangle.p1, triNormal)
    result.point = ray.origin + ray.dir * result.distance

  except ValueError:
    result.hit = false
    return
  
  result.hit = overlapsAssumingInSamePlane(result.point, triangle)
  
  # todo: handle non-default error handling

