import ../core/[vectors, points, placement]
import ./[isurface3, basic]
import ../curves2d/[icurve2, lineSection]


proc intersectionCurves*(planeA, planeB: Plane3): seq[LineSection2] =
  ## yields intersection curves in coordinates of `planeA` surface
  ## empty if the planes are parallel or equal
  ## algorithm is described in ./intersections.typ

  let n = planeB.axisZ.V3

  let
    a = n.dot(planeA.axisX.V3)
    b = n.dot(planeA.axisY.V3)
    c = n.dot(planeA.pos - planeB.pos)

  if a ~== 0 and b ~== 0:  # planes are parallel or equal
    return

  if abs(a) > abs(b):
    result.add lineSection2(point2(-c / a, 0), point2(-(b + c) / a, 1))
  else:
    result.add lineSection2(point2(0, -c / b), point2(1, -(a + c) / b))


proc intersectionCurves*(a, b: Surface3): seq[OwnedCurve2] =
  if a.isOf(Plane3) and b.isOf(Plane3):
    for x in intersectionCurves(a.castTo(Plane3), b.castTo(Plane3)): result.add x.toOwnedCurve2
  else:
    raise ValueError.newException("Unimplemented intersection for this type combination")



when isMainModule:
  import std/[unittest]

  test "z = 0 plane <-> x = 1 plane":
    check intersectionCurves(
      placement(v3(0, 0, 1).NormalVec3),
      placement(v3(1, 0, 0).NormalVec3, point3(1, 0, 0)),
    ) ~== @[lineSection(p2(1, 0), p2(1, 1))]

  test "z = 0 plane <-> y + z = 0 plane":
    check intersectionCurves(
      placement(v3(0, 0, 1).NormalVec3),
      placement(v3(0, 1, 1).normal),
    ) ~== @[lineSection(p2(0, 0), p2(1, 0))]

  test "z = 0 plane <-> z = 5 plane":
    check intersectionCurves(
      placement(v3(0, 0, 1).NormalVec3),
      placement(v3(0, 0, 1).NormalVec3, point3(0, 0, 5)),
    ).len == 0

  test "z = 0 plane <-> z = 0 plane":
    check intersectionCurves(
      placement(v3(0, 0, 1).NormalVec3),
      placement(v3(0, 0, 1).NormalVec3),
    ).len == 0
