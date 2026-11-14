import std/[unittest, tables, math, sequtils, sets]
import sigeo/[core, sdf]


proc meshVolume(grid: Grid3): Float =
  ## volume enclosed by a closed, outward-oriented mesh (origin can be anywhere)
  for i in countup(0, grid.indices.high - 2, 3):
    let
      a = grid.points[grid.indices[i]].V3
      b = grid.points[grid.indices[i + 1]].V3
      c = grid.points[grid.indices[i + 2]].V3
    result += a.dot(b.cross(c)) / 6

proc meshEdgeCounts(grid: Grid3): CountTable[(int32, int32)] =
  for i in 0..<grid.indices.len:
    let
      a = grid.indices[i]
      b = grid.indices[(i + 1) mod 3 + i div 3 * 3]
    result.inc (min(a, b), max(a, b))

proc isWatertight(grid: Grid3): bool =
  ## every mesh edge is shared by exactly two triangles
  for _, count in meshEdgeCounts(grid):
    if count != 2: return false
  true

proc eulerCharacteristic(grid: Grid3): int =
  ## V - E + F: 2 for a sphere-like surface, 0 for a torus-like surface
  var edges = 0
  for _, count in meshEdgeCounts(grid):
    doAssert count == 2
    inc edges
  grid.points.len - edges + grid.indices.len div 3


suite "sdf primitives":
  test "sphere":
    let s = sdSphere(p3(1, 2, 3), 2)
    check s.dist(p3(4, 6, 3)) == 3
    check s.dist(p3(1, 2, 3)) == -2
    check s.dist(p3(1, 2, 5)) == 0
    check s.bounds3.min == p3(-1, 0, 1)

  test "box":
    let b = sdBox(p3(0, 0, 0), v3(1, 2, 3))
    check b.dist(p3(3, 0, 0)) == 2
    check b.dist(p3(1, 2, 3)) == 0
    check b.dist(p3(0.5, 0.5, 0.5)) == -0.5  # distance to the nearest face
    check b.dist(p3(2, 3, 4)) == (v3(1, 1, 1)).length  # distance to the corner

  test "round box":
    let b = sdRoundBox(p3(0, 0, 0), v3(1, 1, 1), 0.5)
    check b.dist(p3(2, 0, 0)) == 1
    check b.dist(p3(0, 0, 0)) == -1
    check b.dist(p3(2, 2, 0)) == ((v3(1.5, 1.5, 0).length - 0.5).Float)  # distance to the rounded edge

  test "torus":
    let t = sdTorus(p3(0, 0, 0), 2, 0.5)
    check t.dist(p3(2.5, 0, 0)) == 0
    check t.dist(p3(2, 0.5, 0)) == 0
    check t.dist(p3(2, 0, 0)) == -0.5
    check t.dist(p3(0, 0, 0)) == 1.5

  test "capsule":
    let c = sdCapsule(p3(0, 0, 0), p3(4, 0, 0), 1)
    check c.dist(p3(2, 0, 0)) == -1
    check c.dist(p3(2, 3, 0)) == 2
    check c.dist(p3(-1, 0, 0)) == 0
    check c.dist(p3(0, 0, 0)) == -1

  test "capped cylinder":
    let c = sdCappedCylinder(p3(0, 0, 0), 1, 2)
    check c.dist(p3(1, 2, 0)) == 0
    check c.dist(p3(0, 0, 0)) == -1
    check c.dist(p3(2, 0, 0)) == 1
    check c.dist(p3(0, 3, 0)) == 1

  test "capped cone":
    let c = sdCappedCone(p3(0, 0, 0), 1, 1, 0.5)
    check c.dist(p3(0, -1, 0)) == 0
    check c.dist(p3(0, 1, 0)) == 0
    check c.dist(p3(0, 0, 0)) ~== Float(-1.5 / 4.25.sqrt)

  test "capped cone between points":
    let c = sdCappedCone(p3(0, 0, 0), p3(0, 4, 0), 2, 1)
    check c.dist(p3(2, 0, 0)) == 0
    check c.dist(p3(0, 4, 1)) == 0
    check c.dist(p3(0, 2, 0)) ~== Float(-6 / 17.0.sqrt)

  test "plane":
    let p = sdPlane(p3(0, 1, 0), v3(0, 1, 0).NormalVec3)
    check p.dist(p3(5, 3, -2)) == 2
    check p.dist(p3(5, -4, -2)) == -5
    check p.dist(p3(0, 1, 0)) == 0

  test "octahedron":
    let o = sdOctahedron(p3(0, 0, 0), 1)
    check o.dist(p3(0, 1, 0)) == 0
    check o.dist(p3(1, 0, 0)) == 0
    check o.dist(p3(0, 0.5, 0)) == Float(-0.5 * 0.57735027)

  test "hex prism":
    let h = sdHexPrism(p3(0, 0, 0), 1, 0.5)
    check h.dist(p3(0, 1, 0.5)) == 0
    check h.dist(p3(0, 0, 0)) == -0.5

  test "vertical capsule":
    let c = sdVerticalCapsule(p3(0, 0, 0), 1, 0.5)
    check c.dist(p3(0, 1.5, 0)) == 0
    check c.dist(p3(0.5, 0.5, 0)) == 0
    check c.dist(p3(0, 0, 0)) == -0.5

  test "pyramid":
    let p = sdPyramid(p3(0, 0, 0), 1)
    check p.dist(p3(0, 0.5, 0)) == Float(-0.5 / 5.0.sqrt)  # distance to a slant face
    check p.dist(p3(0, 0, 0.5)) == 0  # on the base edge? base half-size 0.5
    check p.dist(p3(0, 1, 0)) == 0

  test "triangle":
    let t = udTriangle(p3(0, 0, 0), p3(4, 0, 0), p3(0, 0, 4))
    check t.dist(p3(1, 2, 1)) == 2
    check t.dist(p3(1, 0, 1)) == 0
    check t.dist(p3(0.3, -0.4, 0.3)) ~== 0.4

  test "extrusion":
    let e = sdCircle(p2(0, 0), 1).opExtrusion(0.5)
    check e.dist(p3(2, 0, 0)) == 1
    check e.dist(p3(1.2, 0, 0.1)) ~== 0.2
    check e.dist(p3(0, 0, 0.6)) ~== 0.1
    check e.dist(p3(0, 0, 0)) == -0.5  # nearest surface is the cap

  test "revolution":
    let r = sdCircle(p2(1, 0), 0.5).opRevolution(0)
    check r.dist(p3(1.5, 0, 0)) == 0
    check r.dist(p3(1.5, 2, 0)) ~== Float(sqrt(0.25 + 4) - 0.5)
    check r.dist(p3(1, 0, 0)) == -0.5


suite "sdf operators":
  test "boolean":
    let
      a = sdSphere(p3(0, 0, 0), 1)
      b = sdSphere(p3(2, 0, 0), 1)
    check a.opUnion(b).dist(p3(1, 0, 0)) == 0
    check a.opUnion(b).dist(p3(3, 0, 0)) == 0
    check a.opUnion(b).dist(p3(0.5, 0, 0)) == -0.5
    check a.opSubtraction(b).dist(p3(-1, 0, 0)) == 0  # surface of the result
    check a.opSubtraction(b).dist(p3(0.5, 0, 0)) == -0.5  # inside `a`, outside `b`
    check a.opSubtraction(b).dist(p3(1.5, 0, 0)) == 0.5  # `b` only removes material where it is
    check a.opIntersection(b).dist(p3(1, 0, 0)) == 0
    check a.opIntersection(b).dist(p3(0.5, 0, 0)) == 0.5
    check a.opXor(b).dist(p3(0.5, 0, 0)) == -0.5
    check a.opXor(b).dist(p3(1.5, 0, 0)) == -0.5
    check a.opXor(b).dist(p3(1, 0, 0)) == 0

  test "smooth boolean":
    let
      a = sdSphere(p3(0, 0, 0), 1)
      b = sdSphere(p3(2, 0, 0), 1)
    let s = a.opSmoothUnion(b, 0.5)
    check s.dist(p3(0, 0, 0)) == -1
    check s.dist(p3(2, 0, 0)) == -1
    # smooth blend adds material between the shapes
    check s.dist(p3(1, 0, 0)) < 0
    # the blend adds material where the shapes meet
    check s.dist(p3(1, 0, 0)) < a.opUnion(b).dist(p3(1, 0, 0))

  test "translate bounds":
    let b = sdBox(p3(0, 0, 0), v3(1, 1, 1)).opTranslate(v3(5, 0, -2))
    check b.bounds3.min == p3(4, -1, -3)
    check b.bounds3.max == p3(6, 1, -1)

  test "round bounds":
    let b = sdBox(p3(0, 0, 0), v3(1, 1, 1)).opRound(0.5)
    check b.dist(p3(1.5, 0, 0)) == 0
    check b.bounds3.min == p3(-1.5, -1.5, -1.5)

  test "mirror bounds":
    let b = sdBox(p3(3, 0, 0), v3(1, 1, 1)).opSymX
    check b.bounds3.min == p3(-4, -1, -1)
    check b.bounds3.max == p3(4, 1, 1)
    check b.dist(p3(-3, 0, 0)) == -1  # inside the mirrored copy
    check b.dist(p3(-4, 0, 0)) == 0

  test "limited repetition":
    let b = sdSphere(p3(0, 0, 0), 0.5).opLimitedRepetition(v3(2, 0, 0), v3(2, 0, 0))
    check b.dist(p3(4, 0, 0)) == -0.5
    check b.dist(p3(6, 0, 0)) == 1.5
    check b.bounds3.min.x == -4.5

  test "elongate":
    let e = sdSphere(p3(0, 0, 0), 1).opElongate(v3(0, 2, 0))
    check e.dist(p3(0, 3, 0)) == 0  # on the surface of the elongated sphere
    check e.dist(p3(0, 0, 0)) == -1
    check e.dist(p3(2, 3, 0)) ~== Float(sqrt(5.0) - 1)

  test "onion":
    let o = sdSphere(p3(0, 0, 0), 1).opOnion(0.5)
    check o.dist(p3(1, 0, 0)) == -0.5
    check o.dist(p3(0.5, 0, 0)) == 0
    check o.dist(p3(0, 0, 0)) == 0.5

  test "custom function":
    let s = Sdf3Func(proc(p: Point3): Float = p.x.abs - 1)
    check s.toSdf3.opTranslate(v3(1, 0, 0)).dist(p3(2.5, 0, 0)) == 0.5


suite "polygonize":
  test "sphere is watertight, correctly oriented and has correct volume":
    let grid = sdSphere(p3(0, 0, 0), 1).polygonize(step = 0.1)
    check grid.kind == Triangles
    check grid.isWatertight
    check grid.eulerCharacteristic == 2
    let volume = grid.meshVolume
    let expectedVolume: Float = 4/3*Pi
    check volume > 0  # triangles are oriented outwards
    check (volume - expectedVolume).abs < expectedVolume * 0.03
    for pt in grid.points:
      check pt.V3.length < Float(1.05)
      check pt.V3.length > Float(0.95)

  test "torus is watertight with genus 1":
    let grid = sdTorus(p3(0, 0, 0), 2, 0.5).polygonize(resolution = 40)
    check grid.isWatertight
    check grid.eulerCharacteristic == 0
    let volume = grid.meshVolume
    let expected: Float = 2 * Pi*Pi * 2 * 0.5*0.5  # 2*pi^2*R*r^2
    check volume > 0
    check (volume - expected).abs < expected * 0.05

  test "union of shapes is watertight":
    let shape = sdSphere(p3(0, 0, 0), 1)
      .opUnion(sdBox(p3(1.5, 0, 0), v3(1, 0.5, 0.5)))
      .opSubtraction(sdSphere(p3(1.5, 0, 0), 0.4))
    let grid = shape.polygonize(step = 0.08)
    check grid.isWatertight

  test "transformed shape":
    let shape = sdBox(p3(0, 0, 0), v3(1, 1, 1))
      .opRotate(p3(0, 0, 0), v3(0, 0, 1).NormalVec3, Pi/4)
      .opTranslate(v3(10, 0, 0))
    let rotatedHalf = Float(sqrt(2.0))
    check (shape.bounds3.min.x - (10 - rotatedHalf)).abs < 1e-5
    check (shape.bounds3.min.y - (-rotatedHalf)).abs < 1e-5
    let grid = shape.polygonize(resolution = 30)
    check grid.isWatertight
    check (grid.meshVolume - 8).abs < Float(8 * 0.05)

  test "twisted shape with explicit bounds":
    let shape = sdBox(p3(0, 0, 0), v3(1, 0.3, 0.3)).opTwist(1.5)
    let grid = shape.polygonize(
      bounds3(p3(-1.3, -0.5, -1.3), p3(1.3, 0.5, 1.3)), step = 0.05)
    check grid.isWatertight

  test "extruded 2d shape":
    let shape = sdBox(p2(0, 0), v2(1, 2)).opExtrusion(0.5).opRound(0.2)
    let grid = shape.polygonize(step = 0.08)
    check grid.isWatertight
    # box 2x4x1 inflated by 0.2: inner box + face slabs + edge cylinders + corners
    let expected: Float = 8 + 28*0.2 + 7*Pi*0.04 + 4/3*Pi*0.008
    check (grid.meshVolume - expected).abs < expected * 0.05

  test "unbounded shapes raise":
    expect ValueError:
      discard sdPlane(p3(0, 0, 0), v3(0, 1, 0).NormalVec3).polygonize(step = 0.5)
    expect ValueError:
      discard sdSphere(p3(0, 0, 0), 1).opTwist(1).polygonize(step = 0.5)
    expect ValueError:
      discard sdSphere(p3(0, 0, 0), 1).opRepetition(v3(3, 3, 3)).polygonize(step = 0.5)
