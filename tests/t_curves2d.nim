import std/[unittest]
import sigeo/[core, curves2d]


test "curves2d intersections":
  let line_a = LineSection(startPoint: point2(0, 0), endPoint: point2(2, 2))
  let line_b = LineSection(startPoint: point2(1, 0), endPoint: point2(0, 1))
  let line_c = LineSection(startPoint: point2(1, 0), endPoint: point2(0.5, 0.5))
  let line_d = LineSection(startPoint: point2(404, 404), endPoint: point2(404, 504))
  let line_e = LineSection(startPoint: point2(404, 464), endPoint: point2(504, 504))
  
  block:
    var pointsN = 0
    let points = intersectionPoints(line_a, line_b, pointsN)
    check pointsN == 1
    check points[0].curveA.almostEqual(1 / 4)
    check points[0].curveB.almostEqual(1 / 2)

  block:
    var pointsN = 0
    let points = intersectionPoints(line_a, line_c, pointsN)
    check pointsN == 1
    check points[0].curveA.almostEqual(1 / 4)
    check points[0].curveB.almostEqual(1)

  block:
    var pointsN = 0
    let points = intersectionPoints(line_d, line_e, pointsN)
    check pointsN == 1
    check points[0].curveA.almostEqual(6 / 10)
    check points[0].curveB.almostEqual(0)
