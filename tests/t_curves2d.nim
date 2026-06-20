import std/[unittest]
import sigeo/[core, curves2d]


test "curves2d intersections":
  let line_a = LineSection2(startPoint: point2(0, 0), endPoint: point2(2, 2))
  let line_b = LineSection2(startPoint: point2(1, 0), endPoint: point2(0, 1))
  let line_c = LineSection2(startPoint: point2(1, 0), endPoint: point2(0.5, 0.5))
  let line_d = LineSection2(startPoint: point2(404, 404), endPoint: point2(404, 504))
  let line_e = LineSection2(startPoint: point2(404, 464), endPoint: point2(504, 504))
  
  block:
    var pointsN = 0
    let points = intersectionPointsParams(line_a, line_b, pointsN)
    check pointsN == 1
    check points[0].curveA.almostEqual(1 / 4)
    check points[0].curveB.almostEqual(1 / 2)

  block:
    var pointsN = 0
    let points = intersectionPointsParams(line_a, line_c, pointsN)
    check pointsN == 1
    check points[0].curveA.almostEqual(1 / 4)
    check points[0].curveB.almostEqual(1)

  block:
    var pointsN = 0
    let points = intersectionPointsParams(line_d, line_e, pointsN)
    check pointsN == 1
    check points[0].curveA.almostEqual(6 / 10)
    check points[0].curveB.almostEqual(0)


test "curves2d transform":
  # only uniform-scale transforms (rotation, uniform scale, reflection, translation),
  # built from the vmath matrix constructors
  let matrices = @[
    m4(),
    translate(v3(3, -2, 0)),
    translate(v3(1, 1, 0)) * scale(v3(2, 2, 1)),
    translate(v3(-1, 4, 0)) * rotateZ(0.7),
    translate(v3(5, -3, 0)) * rotateZ(2.1) * scale(v3(1.5, 1.5, 1)),
    scale(v3(-1, 1, 1)),
    rotateZ(0.4) * scale(v3(-2, 2, 1)),
  ]

  proc checkCommutes(c: Curve2, m: M4) =
    # the defining property: transforming the curve, then sampling,
    # equals sampling the original and then transforming the point
    let t = c.transform(m)
    for i in 0..20:
      let p = (i / 20).FloatParam
      check t.pointAt(p).distanceTo(c.pointAt(p).transform(m)) < 1e-9

  let curves = @[
    lineSection(point2(1, 2), point2(4, -1)).toOwnedCurve2,
    circleArc(point2(-1, 2), 3, Pi/6, -3*Pi/4).toOwnedCurve2,
    circleArc(point2(0, 0), 2, Pi/2, Pi, clockwise).toOwnedCurve2,
    circleArc(point2(1, 1), 1.5).toOwnedCurve2,  # full circle
    ellipseArc(point2(2, -1), v2(6, 2), Pi/5, 7*Pi/6).toOwnedCurve2,
    ellipseArc(point2(0, 0), v2(4, 2), -2*Pi/3, Pi/4, clockwise, rotation = Pi/3).toOwnedCurve2,
  ]

  for c in curves.view:
    for m in matrices:
      checkCommutes(c, m)

  # a path (kept continuous) transforms curve by curve
  block:
    var path: Path2
    path.add point2(0, 0)
    path.add point2(3, 0)
    path.add circleArc(point2(3, 2), 2, -Pi/2, 0).toCurve2
    path.add point2(6, 5)
    for m in matrices:
      checkCommutes(path.toCurve2, m)
      let tp = path.transform(m)
      check tp.curves.len == path.curves.len

  # a circle stays a circle, an ellipse keeps its aspect ratio under uniform scale
  block:
    let arc = circleArc(point2(1, 1), 2, Pi/6, Pi)
    check arc.transform(scale(v3(3, 3, 1))).radius ~== 6

    let el = ellipseArc(point2(0, 0), v2(4, 2), Pi/5, 7*Pi/6)
    check el.transform(scale(v3(3, 3, 1))).size ~== v2(12, 6)


test "OwnedCurve2 copy into fresh/empty/valid slots":
  let src = lineSection(point2(0, 0), point2(1, 1)).toOwnedCurve2

  block: # copy into a fresh var
    var dst: OwnedCurve2
    dst = src
    check dst.pointAt(1.FloatParam) ~== point2(1, 1)

  block: # copy into a fresh seq slot
    var s: seq[OwnedCurve2]
    s.setLen 1
    s[0] = src
    check s[0].pointAt(1.FloatParam) ~== point2(1, 1)

  block: # deep copy — mutating the source must not affect the copy
    var a = lineSection(point2(0, 0), point2(1, 1)).toOwnedCurve2
    let b = a
    a.castTo(LineSection2).endPoint = point2(9, 9)
    check b.pointAt(1.FloatParam) ~== point2(1, 1)

  block: # copy an empty source over a valid destination clears it
    var empty: OwnedCurve2
    var c = lineSection(point2(0, 0), point2(2, 2)).toOwnedCurve2
    c = empty
    check c.obj == nil
