import std/[math, tables]
import ../macros/[genAliases]
import ../core/[vectors, points, bounds3]
import ../surfaces/[grids]
export grids
import ./[common]


## Translating an SDF world into polygons, using marching tetrahedra.
##
## The space is split into a lattice of cubic cells; every cell is split into 6 tetrahedra around its main diagonal
## (this decomposition is face-consistent, so the resulting mesh is watertight);
## every tetrahedron crossing the isosurface is replaced with a triangle or a quad.
## Vertices on shared lattice edges are welded, triangles are oriented outwards using the SDF gradient.


const cellTetrahedras: array[6, array[4, int]] = [
  [0, 1, 3, 7],
  [0, 2, 3, 7],
  [0, 2, 6, 7],
  [0, 4, 6, 7],
  [0, 4, 5, 7],
  [0, 1, 5, 7],
]
  ## tetrahedral decomposition of a cell
  ## cell corner numbering: bit 0 - x, bit 1 - y, bit 2 - z
  ## (0=(0,0,0), 1=(1,0,0), 2=(0,1,0), 3=(1,1,0), 4=(0,0,1), 5=(1,0,1), 6=(0,1,1), 7=(1,1,1))


proc polygonize*(sdf: Sdf3, bounds: Bounds3, step: Float): Grid3 {.aliases: [toGrid].} =
  ## translates an SDF into a triangle mesh, sampling it on a lattice
  ## with an approximately `step` spacing inside `bounds`
  ##
  ## `bounds` should be slightly larger than the shape itself,
  ## otherwise the mesh will have holes at the bounds boundary

  assert step > 0

  if not bounds.isKnown:
    raise ValueError.newException(
      "cannot polygonize SDF: the provided bounds are empty or infinite; " &
      "provide finite bounds that slightly exceed the shape")

  let nx = max(1, ((bounds.max.x - bounds.min.x) / step).ceil.int)
  let ny = max(1, ((bounds.max.y - bounds.min.y) / step).ceil.int)
  let nz = max(1, ((bounds.max.z - bounds.min.z) / step).ceil.int)
  let
    hx = (bounds.max.x - bounds.min.x) / nx.Float
    hy = (bounds.max.y - bounds.min.y) / ny.Float
    hz = (bounds.max.z - bounds.min.z) / nz.Float

  var mesh = Grid3(kind: Triangles)

  # The sampling lattice is shifted by a fixed fractional part of the step in each axis.
  # Otherwise a surface plane or line coinciding with lattice planes
  # (an axis-aligned box face, the pole of a sphere at a lattice point, ...) would
  # produce lattice points with exactly zero distance, whose edges all get
  # coincident crossing vertices and pinch the mesh.
  const
    fracX = 0.31719
    fracY = 0.68932
    fracZ = 0.45127

  # lattice points are indexed -1..nx along each axis and offset by the fracs,
  # so the sampled region slightly exceeds `bounds` on every side
  let ny1 = ny + 2
  let nz1 = nz + 2
  template lid(i, j, k: int): int = ((i + 1) * ny1 + (j + 1)) * nz1 + (k + 1)
  template latticePos(i, j, k: int): Point3 = point3(
    bounds.min.x + (i.Float + fracX) * hx,
    bounds.min.y + (j.Float + fracY) * hy,
    bounds.min.z + (k.Float + fracZ) * hz,
  )

  # sample the distance field on the shifted lattice
  var values = newSeqUninit[Float]((nx + 2) * ny1 * nz1)
  for i in -1..nx:
    for j in -1..ny:
      for k in -1..nz:
        values[lid(i, j, k)] = sdf.dist(latticePos(i, j, k))

  # SDF gradient estimated from the lattice, used to orient triangles outwards
  template latticeGradient(i, j, k: int): V3 =
    let ip = min(i + 1, nx)
    let im = max(i - 1, -1)
    let jp = min(j + 1, ny)
    let jm = max(j - 1, -1)
    let kp = min(k + 1, nz)
    let km = max(k - 1, -1)
    v3(
      (values[lid(ip, j, k)] - values[lid(im, j, k)]) / (Float(ip - im) * hx),
      (values[lid(i, jp, k)] - values[lid(i, jm, k)]) / (Float(jp - jm) * hy),
      (values[lid(i, j, kp)] - values[lid(i, j, km)]) / (Float(kp - km) * hz),
    )

  var vertexIds = initTable[(int32, int32), int32]()
    ## welds vertices: every crossing of the same lattice edge produces one vertex

  proc getVertex(id0: int, v0: Float, p0: Point3, id1: int, v1: Float, p1: Point3): int32 =
    ## returns the index of the isosurface crossing point on the lattice edge id0-id1
    let (ia, va, pa, ib, vb, pb) =
      if id0 <= id1: (id0, v0, p0, id1, v1, p1)
      else: (id1, v1, p1, id0, v0, p0)
    let key = (ia.int32, ib.int32)
    if key in vertexIds:
      return vertexIds[key]

    let t = va / (va - vb)  # va and vb are on different sides of the isosurface
    result = mesh.points.len.int32
    mesh.points.add pa + (pb - pa) * t
    vertexIds[key] = result

  template gradientLatticePoint(centroid: Point3): (int, int, int) =
    (
      ((centroid.x - bounds.min.x) / hx - fracX).round.int.clamp(-1, nx),
      ((centroid.y - bounds.min.y) / hy - fracY).round.int.clamp(-1, ny),
      ((centroid.z - bounds.min.z) / hz - fracZ).round.int.clamp(-1, nz),
    )

  proc addTriangle(mesh: var Grid3, a, b, c: int32, centroid: Point3) =
    let (gi, gj, gk) = gradientLatticePoint(centroid)
    let n = (mesh.points[b] - mesh.points[a]).cross(mesh.points[c] - mesh.points[a])
    if n.dot(latticeGradient(gi, gj, gk)) >= 0:
      mesh.indices.add [a, b, c]
    else:
      mesh.indices.add [a, c, b]

  proc tetCentroid(pts: array[8, Point3], tet: array[4, int]): Point3 =
    var s = v3(0, 0, 0)
    for l in 0..3:
      s += pts[tet[l]].V3
    (s / 4).Point3

  for i in -1..<nx:
    for j in -1..<ny:
      for k in -1..<nz:
        var
          ids: array[8, int]
          vals: array[8, Float]
          pts: array[8, Point3]
        for c in 0..7:
          let
            ci = i + (c and 1)
            cj = j + ((c shr 1) and 1)
            ck = k + ((c shr 2) and 1)
          ids[c] = lid(ci, cj, ck)
          vals[c] = values[ids[c]]
          pts[c] = latticePos(ci, cj, ck)

        for tet in cellTetrahedras:
          let centroid = tetCentroid(pts, tet)
          var inIdx: array[4, int8]
          var outIdx: array[4, int8]
          var nIn, nOut = 0
          for l in 0..3:
            if vals[tet[l]] < 0:
              inIdx[nIn] = l.int8
              inc nIn
            else:
              outIdx[nOut] = l.int8
              inc nOut

          template crossing(edgeIn, edgeOut: int): int32 =
            getVertex(
              ids[tet[edgeIn]], vals[tet[edgeIn]], pts[tet[edgeIn]],
              ids[tet[edgeOut]], vals[tet[edgeOut]], pts[tet[edgeOut]],
            )

          case nIn
          of 1:
            # tetrahedron crossed by a single triangle
            addTriangle(
              mesh,
              crossing(inIdx[0].int, outIdx[0].int),
              crossing(inIdx[0].int, outIdx[1].int),
              crossing(inIdx[0].int, outIdx[2].int),
              centroid,
            )

          of 3:
            # tetrahedron crossed by a single triangle
            addTriangle(
              mesh,
              crossing(inIdx[0].int, outIdx[0].int),
              crossing(inIdx[1].int, outIdx[0].int),
              crossing(inIdx[2].int, outIdx[0].int),
              centroid,
            )

          of 2:
            # tetrahedron crossed by a quad, split into two triangles
            let q = [
              crossing(inIdx[0].int, outIdx[0].int),
              crossing(inIdx[1].int, outIdx[0].int),
              crossing(inIdx[1].int, outIdx[1].int),
              crossing(inIdx[0].int, outIdx[1].int),
            ]
            addTriangle(mesh, q[0], q[1], q[2], centroid)
            addTriangle(mesh, q[0], q[2], q[3], centroid)

          else:
            discard

  result = mesh


proc polygonize*(sdf: Sdf3, bounds: Bounds3, resolution: int): Grid3 {.aliases: [toGrid].} =
  ## translates an SDF into a triangle mesh, splitting the largest side of `bounds`
  ## into `resolution` steps
  let size = bounds.max.V3 - bounds.min.V3
  let step = max(size.x, max(size.y, size.z)) / resolution.Float
  polygonize(sdf, bounds, step)


proc polygonize*(sdf: Sdf3, step: Float): Grid3 {.aliases: [toGrid].} =
  ## `polygonize` using the bounds of the SDF itself
  ## (works only if the SDF has known finite bounds)
  let b = sdf.bounds3
  if not b.isKnown:
    raise ValueError.newException(
      "cannot polygonize SDF: its bounds are unknown (the shape is unbounded, " &
      "or a deformation/repetition operator was used); pass `bounds` explicitly to `polygonize`"
    )
  polygonize(sdf, b, step)


proc polygonize*(sdf: Sdf3, resolution: int = 32): Grid3 {.aliases: [toGrid].} =
  ## `polygonize` using the bounds of the SDF itself
  ## (works only if the SDF has known finite bounds)
  let b = sdf.bounds3
  if not b.isKnown:
    raise ValueError.newException(
      "cannot polygonize SDF: its bounds are unknown (the shape is unbounded, " &
      "or a deformation/repetition operator was used); pass `bounds` explicitly to `polygonize`"
    )
  polygonize(sdf, b, resolution)
