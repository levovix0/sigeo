import std/[math]
import ./[common]


# Exact and true SDF primitives, based on Inigo Quilez's article
# "Distance functions" (https://iquilezles.org/articles/distfunctions/)


proc sdSphere*(center: Point3, radius: Float): Sdf3 =
  ## exact sphere
  let half = v3(radius)
  sdf3(
    dist = proc(p: Point3): Float = (p - center).length - radius,
    bounds = Bounds3(min: center - half, max: center + half),
  )


proc sdBox*(center: Point3, halfSize: V3): Sdf3 =
  ## exact box
  sdf3(
    dist = proc(p: Point3): Float =
      let q = vabs(p.V3 - center.V3) - halfSize
      vmax(q, 0).length + min(max(q.x, max(q.y, q.z)), 0)
    ,
    bounds = Bounds3(min: center - halfSize, max: center + halfSize),
  )


proc sdRoundBox*(center: Point3, halfSize: V3, radius: Float): Sdf3 =
  ## exact box with rounded edges, overall half-size is `halfSize`
  sdf3(
    dist = proc(p: Point3): Float =
      let q = vabs(p.V3 - center.V3) - halfSize + radius
      vmax(q, 0).length + min(max(q.x, max(q.y, q.z)), 0) - radius
    ,
    bounds = Bounds3(min: center - halfSize, max: center + halfSize),
  )


proc sdBoxFrame*(center: Point3, halfSize: V3, thickness: Float): Sdf3 =
  ## exact wireframe of a box: box edges of `thickness` thickness
  let b = halfSize
  let e = thickness
  sdf3(
    dist = proc(p: Point3): Float =
      let pp = vabs(p.V3 - center.V3) - b
      let q = vabs(pp + e) - e
      min(
        min(
          vmax(v3(pp.x, q.y, q.z), 0).length + min(max(pp.x, max(q.y, q.z)), 0),
          vmax(v3(q.x, pp.y, q.z), 0).length + min(max(q.x, max(pp.y, q.z)), 0),
        ),
        vmax(v3(q.x, q.y, pp.z), 0).length + min(max(q.x, max(q.y, pp.z)), 0),
      )
    ,
    bounds = Bounds3(min: center - b, max: center + b),
  )


proc sdTorus*(center: Point3, ringRadius, tubeRadius: Float): Sdf3 =
  ## exact torus, ring lies in the XZ plane, axis is Y
  let extents = v3(ringRadius + tubeRadius, tubeRadius, ringRadius + tubeRadius)
  sdf3(
    dist = proc(p: Point3): Float =
      let q = p.V3 - center.V3
      v2(v2(q.x, q.z).length - ringRadius, q.y).length - tubeRadius
    ,
    bounds = Bounds3(min: center - extents, max: center + extents),
  )


proc sdCappedTorus*(center: Point3, angleSinCos: V2, ringRadius, tubeRadius: Float): Sdf3 =
  ## exact torus arc, lies in the XY plane around the Z axis
  ## `angleSinCos` is (sin, cos) of the arc angle, the arc starts at +Y and goes towards +X
  let sc = angleSinCos
  let ra = ringRadius
  let rb = tubeRadius
  let extents = v3(ringRadius + tubeRadius, ringRadius + tubeRadius, tubeRadius)
  sdf3(
    dist = proc(p: Point3): Float =
      let q = p.V3 - center.V3
      let px = q.x.abs
      let k =
        if sc.y * px > sc.x * q.y: v2(px, q.y).dot(sc)
        else: v2(px, q.y).length
      (q.dot2 + ra*ra - 2*ra*k).sqrt - rb
    ,
    bounds = Bounds3(min: center - extents, max: center + extents),
  )


proc sdLink*(center: Point3, length, ringRadius, tubeRadius: Float): Sdf3 =
  ## exact link (torus stretched along Y), axis is Y
  let extents = v3(ringRadius + tubeRadius, length + tubeRadius, ringRadius + tubeRadius)
  sdf3(
    dist = proc(p: Point3): Float =
      let q = p.V3 - center.V3
      let qy = max(q.y.abs - length, 0)
      v2(v2(q.x, qy).length - ringRadius, q.z).length - tubeRadius
    ,
    bounds = Bounds3(min: center - extents, max: center + extents),
  )


proc sdInfiniteCylinder*(axisPoint: Point3, radius: Float): Sdf3 =
  ## exact infinite cylinder along the Y axis
  sdf3(
    dist = proc(p: Point3): Float = (p.xz - axisPoint.xz).length - radius,
    bounds = Bounds3(
      min: point3(axisPoint.x - radius, -Inf, axisPoint.z - radius),
      max: point3(axisPoint.x + radius, +Inf, axisPoint.z + radius),
    ),
  )


proc sdCappedCylinder*(center: Point3, radius, halfHeight: Float): Sdf3 =
  ## exact vertical cylinder along Y, centered at `center`
  let extents = v3(radius, halfHeight, radius)
  sdf3(
    dist = proc(p: Point3): Float =
      let q = p.V3 - center.V3
      let d = vabs(v2(v2(q.x, q.z).length, q.y)) - v2(radius, halfHeight)
      min(max(d.x, d.y), 0) + vmax(d, 0).length
    ,
    bounds = Bounds3(min: center - extents, max: center + extents),
  )


proc sdCappedCylinder*(a, b: Point3, radius: Float): Sdf3 =
  ## exact cylinder with flat caps between two points
  let ba = b.V3 - a.V3
  let baba = ba.dot2
  sdf3(
    dist = proc(p: Point3): Float =
      let pa = p.V3 - a.V3
      let paba = pa.dot(ba)
      let x = (pa.V3 * baba - ba * paba).length - radius * baba
      let y = (paba - baba*0.5).abs - baba*0.5
      let x2 = x*x
      let y2 = y*y*baba
      let d =
        if max(x, y) < 0: -min(x2, y2)
        else: (if x > 0: x2 else: 0) + (if y > 0: y2 else: 0)
      d.sign * d.abs.sqrt / baba
    ,
    bounds = Bounds3(min: vmin(a.V3, b.V3).toPoint, max: vmax(a.V3, b.V3).toPoint).expanded(radius),
  )


proc sdCone*(apex: Point3, angleSinCos: V2, height: Float): Sdf3 =
  ## exact finite cone, apex at `apex`, extending towards -Y by `height`
  ## `angleSinCos` is (sin, cos) of the angle between the cone axis and its surface
  let c = angleSinCos
  let h = height
  let baseRadius = h * c.x / c.y
  sdf3(
    dist = proc(p: Point3): Float =
      let q = h * v2(c.x/c.y, -1)
      let w = v2(v2(p.x - apex.x, p.z - apex.z).length, p.y - apex.y)
      let a = w - q * (w.dot(q) / q.dot2).clamp(0, 1)
      let b = w - q * v2((w.x / q.x).clamp(0, 1), 1)
      let k = q.y.sign
      let d = min(a.dot2, b.dot2)
      let s = max(k*(w.x*q.y - w.y*q.x), k*(w.y - q.y))
      d.sqrt * s.sign
    ,
    bounds = Bounds3(
      min: point3(apex.x - baseRadius, apex.y - h, apex.z - baseRadius),
      max: point3(apex.x + baseRadius, apex.y, apex.z + baseRadius),
    ),
  )


proc sdInfiniteCone*(apex: Point3, angleSinCos: V2): Sdf3 =
  ## exact infinite cone, apex at `apex`, opening towards -Y
  ## `angleSinCos` is (sin, cos) of the angle between the cone axis and its surface
  let c = angleSinCos
  sdf3(
    dist = proc(p: Point3): Float =
      let q = v2(v2(p.x - apex.x, p.z - apex.z).length, -(p.y - apex.y))
      let d = (q - c * max(q.dot(c), 0)).length
      d * (if q.x*c.y - q.y*c.x < 0: -1.0 else: 1.0)
    ,
    bounds = Bounds3(
      min: point3(-Inf, -Inf, -Inf),
      max: point3(+Inf, apex.y, +Inf),
    ),
  )


proc sdPlane*(pointOnPlane: Point3, normal: NormalVec3): Sdf3 =
  ## exact half-space: positive distance on the side the `normal` points to
  sdf3(
    dist = proc(p: Point3): Float = (p - pointOnPlane).dot(normal.V3),
    bounds = infiniteBounds3(),
  )


proc sdHexPrism*(center: Point3, hexRadius, halfHeight: Float): Sdf3 =
  ## exact hexagonal prism along Z, `hexRadius` is the distance from the center
  ## to the flat side of the hexagon (inradius)
  let h = v2(hexRadius, halfHeight)
  const k = v3(-0.8660254, 0.5, 0.57735)
  let extents = v3(1.1547005 * hexRadius, hexRadius, halfHeight)
  sdf3(
    dist = proc(p: Point3): Float =
      var p = vabs(p.V3 - center.V3)
      let t = min(k.x*p.x + k.y*p.y, 0)
      p.x -= 2 * t * k.x
      p.y -= 2 * t * k.y
      let d = v2(
        v2(p.x - p.x.clamp(-k.z*h.x, k.z*h.x), p.y - h.x).length * (p.y - h.x).sign,
        p.z - h.y,
      )
      min(max(d.x, d.y), 0) + vmax(d, 0).length
    ,
    bounds = Bounds3(min: center - extents, max: center + extents),
  )


proc sdCapsule*(a, b: Point3, radius: Float): Sdf3 =
  ## exact capsule (segment with round ends)
  let ba = b.V3 - a.V3
  sdf3(
    dist = proc(p: Point3): Float =
      let pa = p.V3 - a.V3
      let h = pa.dot(ba) / ba.dot2
      (pa - ba * h.clamp(0, 1)).length - radius
    ,
    bounds = Bounds3(min: vmin(a.V3, b.V3).toPoint, max: vmax(a.V3, b.V3).toPoint).expanded(radius),
  )


proc sdVerticalCapsule*(center: Point3, halfHeight, radius: Float): Sdf3 =
  ## exact capsule along Y: segment of height 2*`halfHeight` with round ends, centered at `center`
  let extents = v3(radius, halfHeight + radius, radius)
  sdf3(
    dist = proc(p: Point3): Float =
      let q = p.V3 - center.V3
      let qy = q.y - q.y.clamp(-halfHeight, halfHeight)
      v3(q.x, qy, q.z).length - radius
    ,
    bounds = Bounds3(min: center - extents, max: center + extents),
  )


proc sdRoundedCylinder*(center: Point3, radius, edgeRadius, halfHeight: Float): Sdf3 =
  ## exact vertical cylinder along Y with rounded edges
  let ra = radius
  let rb = edgeRadius
  let h = halfHeight
  let extents = v3(radius, halfHeight, radius)
  sdf3(
    dist = proc(p: Point3): Float =
      let q = p.V3 - center.V3
      let d = v2(v2(q.x, q.z).length - ra + rb, q.y.abs - h + rb)
      min(max(d.x, d.y), 0) + vmax(d, 0).length - rb
    ,
    bounds = Bounds3(min: center - extents, max: center + extents),
  )


proc sdCappedCone*(center: Point3, halfHeight, bottomRadius, topRadius: Float): Sdf3 =
  ## exact vertical truncated cone along Y, centered at `center`
  let h = halfHeight
  let r1 = bottomRadius
  let r2 = topRadius
  let extents = v3(max(r1, r2), h, max(r1, r2))
  sdf3(
    dist = proc(p: Point3): Float =
      let q = v2(v2(p.x - center.x, p.z - center.z).length, p.y - center.y)
      let k1 = v2(r2, h)
      let k2 = v2(r2 - r1, 2*h)
      let ca = v2(q.x - min(q.x, (if q.y < 0: r1 else: r2)), q.y.abs - h)
      let f = ((k1 - q).dot(k2) / k2.dot2).clamp(0, 1)
      let cb = q - k1 + k2 * f
      let s: Float = (if cb.x < 0 and ca.y < 0: -1 else: 1)
      s * min(ca.dot2, cb.dot2).sqrt
    ,
    bounds = Bounds3(min: center - extents, max: center + extents),
  )


proc sdCappedCone*(a, b: Point3, radiusA, radiusB: Float): Sdf3 =
  ## exact truncated cone between two points, `radiusA` at `a`, `radiusB` at `b`
  let ra = radiusA
  let rb = radiusB
  let rba = rb - ra
  let ba = b.V3 - a.V3
  let baba = ba.dot2
  sdf3(
    dist = proc(p: Point3): Float =
      let pa = p.V3 - a.V3
      let papa = pa.dot2
      let paba = pa.dot(ba) / baba
      let x = (papa - paba*paba*baba).sqrt
      let cax = max(0, x - (if paba < 0.5: ra else: rb))
      let cay = (paba - 0.5).abs - 0.5
      let k = rba*rba + baba
      let f = ((rba*(x - ra) + paba*baba) / k).clamp(0, 1)
      let cbx = x - ra - f*rba
      let cby = paba - f
      let s: Float = (if cbx < 0 and cay < 0: -1 else: 1)
      s * min(cax*cax + cay*cay*baba, cbx*cbx + cby*cby*baba).sqrt
    ,
    bounds = Bounds3(min: vmin(a.V3, b.V3).toPoint, max: vmax(a.V3, b.V3).toPoint).expanded(max(ra, rb)),
  )


proc sdSolidAngle*(apex: Point3, angleSinCos: V2, radius: Float): Sdf3 =
  ## exact spherical sector: part of a sphere of `radius` cut by a cone
  ## with the apex at `apex`, opening towards +Y
  ## `angleSinCos` is (sin, cos) of the angle between the cone axis and its surface
  let c = angleSinCos
  let ra = radius
  sdf3(
    dist = proc(p: Point3): Float =
      let q = v2(v2(p.x - apex.x, p.z - apex.z).length, p.y - apex.y)
      let l = q.length - ra
      let m = (q - c * q.dot(c).clamp(0, ra)).length
      max(l, m * (c.y*q.x - c.x*q.y).sign)
    ,
    bounds = Bounds3(
      min: point3(apex.x - ra, apex.y, apex.z - ra),
      max: point3(apex.x + ra, apex.y + ra, apex.z + ra),
    ),
  )


proc sdCutSphere*(center: Point3, radius, cutHeight: Float): Sdf3 =
  ## exact sphere with the part below the `center.y + cutHeight` plane cut off
  ## (the dome above the plane is kept; the flat face is at `center.y + cutHeight`)
  let r = radius
  let h = cutHeight
  let w = (r*r - h*h).sqrt
  let halfXZ = (if h >= 0: w else: r)
  sdf3(
    dist = proc(p: Point3): Float =
      let q = v2(v2(p.x - center.x, p.z - center.z).length, p.y - center.y)
      let s = max((h - r)*q.x*q.x + w*w*(h + r - 2*q.y), h*q.x - w*q.y)
      if s < 0: q.length - r
      elif q.x < w: h - q.y
      else: (q - v2(w, h)).length
    ,
    bounds = Bounds3(
      min: point3(center.x - halfXZ, center.y + h, center.z - halfXZ),
      max: point3(center.x + halfXZ, center.y + r, center.z + halfXZ),
    ),
  )


proc sdCutHollowSphere*(center: Point3, radius, cutHeight, thickness: Float): Sdf3 =
  ## exact hollow sphere shell of `thickness` thickness,
  ## with the part below the `center.y + cutHeight` plane cut off
  ## (the dome above the plane is kept; the flat edge is at `center.y + cutHeight`)
  let r = radius
  let h = cutHeight
  let t = thickness
  let w = (r*r - h*h).sqrt
  let outerRadius = r + t
  let outerW =
    if h >= 0: max(outerRadius*outerRadius - h*h, 0).sqrt
    else: outerRadius
  sdf3(
    dist = proc(p: Point3): Float =
      let q = v2(v2(p.x - center.x, p.z - center.z).length, p.y - center.y)
      (if h*q.x < w*q.y: (q - v2(w, h)).length else: (q.length - r).abs) - t
    ,
    bounds = Bounds3(
      min: point3(center.x - outerW, center.y + h, center.z - outerW),
      max: point3(center.x + outerW, center.y + outerRadius, center.z + outerW),
    ),
  )


proc sdDeathStar*(center: Point3, radius, secondRadius, secondOffset: Float): Sdf3 =
  ## exact "death star": sphere of `radius` with a spherical bite of `secondRadius`
  ## taken from the +X side, the second sphere center is `secondOffset` away along X
  let ra = radius
  let rb = secondRadius
  let d = secondOffset
  let a = (ra*ra - rb*rb + d*d) / (2*d)
  let b = max(ra*ra - a*a, 0).sqrt
  sdf3(
    dist = proc(p: Point3): Float =
      let q = p.V3 - center.V3
      let pq = v2(q.x, v2(q.y, q.z).length)
      if pq.x*b - pq.y*a > d * max(b - pq.y, 0):
        (pq - v2(a, b)).length
      else:
        max(pq.length - ra, -((pq - v2(d, 0)).length - rb))
    ,
    bounds = Bounds3(
      min: point3(center.x - ra, center.y - ra, center.z - ra),
      max: point3(center.x + ra, center.y + ra, center.z + ra),
    ),
  )


proc sdRoundCone*(center: Point3, bottomRadius, topRadius, height: Float): Sdf3 =
  ## exact round cone: spheres of `bottomRadius` (at `center`) and `topRadius`
  ## (at `center + (0, height, 0)`) connected with a smooth surface
  let r1 = bottomRadius
  let r2 = topRadius
  let h = height
  let b = (r1 - r2) / h
  let a = (1 - b*b).sqrt
  sdf3(
    dist = proc(p: Point3): Float =
      let q = v2(v2(p.x - center.x, p.z - center.z).length, p.y - center.y)
      let k = q.dot(v2(-b, a))
      if k < 0: q.length - r1
      elif k > a*h: (q - v2(0, h)).length - r2
      else: q.dot(v2(a, b)) - r1
    ,
    bounds = Bounds3(
      min: point3(center.x - max(r1, r2), center.y - r1, center.z - max(r1, r2)),
      max: point3(center.x + max(r1, r2), center.y + h + r2, center.z + max(r1, r2)),
    ),
  )


proc sdRoundCone*(a, b: Point3, radiusA, radiusB: Float): Sdf3 =
  ## exact round cone between two points with the specified end radii
  let r1 = radiusA
  let r2 = radiusB
  let ba = b.V3 - a.V3
  let l2 = ba.dot2
  let rr = r1 - r2
  let a2 = l2 - rr*rr
  let il2 = 1 / l2
  sdf3(
    dist = proc(p: Point3): Float =
      let pa = p.V3 - a.V3
      let y = pa.dot(ba)
      let z = y - l2
      let x2 = (pa.V3 * l2 - ba * y).dot2
      let y2 = y*y*l2
      let z2 = z*z*l2
      let k = rr.sign * rr*rr * x2
      if z.sign * a2 * z2 > k: (x2 + z2).sqrt * il2 - r2
      elif y.sign * a2 * y2 < k: (x2 + y2).sqrt * il2 - r1
      else: ((x2 * a2 * il2).sqrt + y*rr) * il2 - r1
    ,
    bounds = Bounds3(min: vmin(a.V3, b.V3).toPoint, max: vmax(a.V3, b.V3).toPoint).expanded(max(r1, r2)),
  )


proc sdVesicaSegment*(a, b: Point3, width: Float): Sdf3 =
  ## exact vesica: lens-shaped body built on the segment `a`-`b` of `width` width
  let w = width
  let c = ((a.V3 + b.V3) * 0.5).Point3
  let l = (b.V3 - a.V3).length
  let v = (b.V3 - a.V3) / l
  let r = 0.5 * l
  let d = 0.5 * (r*r - w*w) / w
  sdf3(
    dist = proc(p: Point3): Float =
      let y = (p - c).dot(v)
      let q = v2(((p - c) - v * y).length, y.abs)
      let hh =
        if r*q.x < d*(q.y - r): v3(0, r, 0)
        else: v3(-d, 0, d + w)
      (q - hh.xy).length - hh.z
    ,
    bounds = Bounds3(min: vmin(a.V3, b.V3).toPoint, max: vmax(a.V3, b.V3).toPoint).expanded(d + w),
  )


proc sdRhombus*(center: Point3, halfDiagonalX, halfDiagonalZ, halfHeight, edgeRadius: Float): Sdf3 =
  ## exact rhombus with diagonals along X and Z, centered at `center`
  let la = halfDiagonalX
  let lb = halfDiagonalZ
  let h = halfHeight
  let ra = edgeRadius
  sdf3(
    dist = proc(p: Point3): Float =
      let pp = vabs(p.V3 - center.V3)
      let f = (la*pp.x - lb*pp.z + lb*lb) / (la*la + lb*lb)
      let w = v2(pp.x, pp.z) - v2(la, lb) * v2(f, 1 - f)
      let q = v2(w.length * w.x.sign - ra, pp.y - h)
      min(max(q.x, q.y), 0) + vmax(q, 0).length
    ,
    bounds = Bounds3(
      min: point3(center.x - la, center.y - h, center.z - lb),
      max: point3(center.x + la, center.y + h, center.z + lb),
    ),
  )


proc sdOctahedron*(center: Point3, size: Float): Sdf3 =
  ## exact octahedron
  let s = size
  sdf3(
    dist = proc(p: Point3): Float =
      let pp = vabs(p.V3 - center.V3)
      let m = pp.x + pp.y + pp.z - s
      var q: V3
      if 3*pp.x < m: q = pp
      elif 3*pp.y < m: q = v3(pp.y, pp.z, pp.x)
      elif 3*pp.z < m: q = v3(pp.z, pp.x, pp.y)
      else: return m * 0.57735027
      let k = (0.5*(q.z - q.y + s)).clamp(0, s)
      v3(q.x, q.y - s + k, q.z - k).length
    ,
    bounds = Bounds3(
      min: point3(center.x - s, center.y - s, center.z - s),
      max: point3(center.x + s, center.y + s, center.z + s),
    ),
  )


proc sdOctahedronBound*(center: Point3, size: Float): Sdf3 =
  ## bound (not exact) octahedron: faster, but overestimates the distance
  let s = size
  sdf3(
    dist = proc(p: Point3): Float =
      let p = vabs(p.V3 - center.V3)
      (p.x + p.y + p.z - s) * 0.57735027
    ,
    bounds = Bounds3(
      min: point3(center.x - s, center.y - s, center.z - s),
      max: point3(center.x + s, center.y + s, center.z + s),
    ),
  )


proc sdPyramid*(center: Point3, height: Float): Sdf3 =
  ## exact pyramid with the base in the XZ plane (half-size 0.5) at `center.y`,
  ## and the apex at `center.y + height`
  let h = height
  let m2 = h*h + 0.25
  sdf3(
    dist = proc(p: Point3): Float =
      var pp = p.V3 - center.V3
      pp.x = pp.x.abs
      pp.z = pp.z.abs
      if pp.z > pp.x: swap pp.x, pp.z
      pp.x -= 0.5
      pp.z -= 0.5
      let q = v3(pp.z, h*pp.y - 0.5*pp.x, h*pp.x + 0.5*pp.y)
      let s = max(-q.x, 0)
      let t = ((q.y - 0.5*pp.z) / (m2 + 0.25)).clamp(0, 1)
      let aa = m2*(q.x + s)*(q.x + s) + q.y*q.y
      let bb = m2*(q.x + 0.5*t)*(q.x + 0.5*t) + (q.y - m2*t)*(q.y - m2*t)
      let d2: Float =
        if min(q.y, -q.x*m2 - q.y*0.5) > 0: 0
        else: min(aa, bb)
      ((d2 + q.z*q.z) / m2).sqrt * max(q.z, -pp.y).sign
    ,
    bounds = Bounds3(
      min: point3(center.x - 0.5, center.y, center.z - 0.5),
      max: point3(center.x + 0.5, center.y + h, center.z + 0.5),
    ),
  )


proc sdEllipsoid*(center: Point3, radii: V3): Sdf3 =
  ## approximate ellipsoid (lower bound, not an exact SDF)
  let r = radii
  sdf3(
    dist = proc(p: Point3): Float =
      let q = p.V3 - center.V3
      let k0 = (q / r).length
      let k1 = (q / (r * r)).length
      k0 * (k0 - 1) / k1
    ,
    bounds = Bounds3(min: center - r, max: center + r),
  )


proc sdTriPrism*(center: Point3, triangleSize, halfDepth: Float): Sdf3 =
  ## approximate triangular prism along Z (lower bound, not an exact SDF)
  ## triangle with the apex pointing up, `triangleSize` defines its size
  ## (base at y = -0.5*triangleSize, apex at y = +triangleSize)
  let h = v2(triangleSize, halfDepth)
  sdf3(
    dist = proc(p: Point3): Float =
      let q = vabs(p.V3 - center.V3)
      let y = p.y - center.y
      max(q.z - h.y, max(q.x*0.866025 + y*0.5, -y) - h.x*0.5)
    ,
    bounds = Bounds3(
      min: point3(center.x - 0.8660254*triangleSize, center.y - 0.5*triangleSize, center.z - halfDepth),
      max: point3(center.x + 0.8660254*triangleSize, center.y + triangleSize, center.z + halfDepth),
    ),
  )


proc udTriangle*(a, b, c: Point3): Sdf3 =
  ## unsigned distance to a triangle (a surface, not a solid:
  ## useful only in combination with other SDFs, cannot be polygonized on its own)
  let ba = b.V3 - a.V3
  let cb = c.V3 - b.V3
  let ac = a.V3 - c.V3
  let nor = ba.cross(ac)
  let dot2ba = ba.dot2
  let dot2cb = cb.dot2
  let dot2ac = ac.dot2
  let dot2nor = nor.dot2
  sdf3(
    dist = proc(p: Point3): Float =
      let pa = p.V3 - a.V3
      let pb = p.V3 - b.V3
      let pc = p.V3 - c.V3
      let signs =
        ba.cross(nor).dot(pa).sign +
        cb.cross(nor).dot(pb).sign +
        ac.cross(nor).dot(pc).sign
      if signs < 2:
        min(
          min(
            (ba * (pa.dot(ba) / dot2ba).clamp(0, 1) - pa).dot2,
            (cb * (pb.dot(cb) / dot2cb).clamp(0, 1) - pb).dot2,
          ),
          (ac * (pc.dot(ac) / dot2ac).clamp(0, 1) - pc).dot2,
        ).sqrt
      else:
        (nor.dot(pa) * nor.dot(pa) / dot2nor).sqrt
    ,
    bounds = Bounds3(
      min: vmin(vmin(a.V3, b.V3), c.V3).toPoint,
      max: vmax(vmax(a.V3, b.V3), c.V3).toPoint,
    ),
  )


proc udQuad*(a, b, c, d: Point3): Sdf3 =
  ## unsigned distance to a quad (a surface, not a solid:
  ## useful only in combination with other SDFs, cannot be polygonized on its own)
  let ba = b.V3 - a.V3
  let cb = c.V3 - b.V3
  let dc = d.V3 - c.V3
  let ad = a.V3 - d.V3
  let nor = ba.cross(ad)
  let dot2ba = ba.dot2
  let dot2cb = cb.dot2
  let dot2dc = dc.dot2
  let dot2ad = ad.dot2
  let dot2nor = nor.dot2
  sdf3(
    dist = proc(p: Point3): Float =
      let pa = p.V3 - a.V3
      let pb = p.V3 - b.V3
      let pc = p.V3 - c.V3
      let pd = p.V3 - d.V3
      let signs =
        ba.cross(nor).dot(pa).sign +
        cb.cross(nor).dot(pb).sign +
        dc.cross(nor).dot(pc).sign +
        ad.cross(nor).dot(pd).sign
      if signs < 3:
        min(
          min(
            min(
              (ba * (pa.dot(ba) / dot2ba).clamp(0, 1) - pa).dot2,
              (cb * (pb.dot(cb) / dot2cb).clamp(0, 1) - pb).dot2,
            ),
            (dc * (pc.dot(dc) / dot2dc).clamp(0, 1) - pc).dot2,
          ),
          (ad * (pd.dot(ad) / dot2ad).clamp(0, 1) - pd).dot2,
        ).sqrt
      else:
        (nor.dot(pa) * nor.dot(pa) / dot2nor).sqrt
    ,
    bounds = Bounds3(
      min: vmin(vmin(vmin(a.V3, b.V3), c.V3), d.V3).toPoint,
      max: vmax(vmax(vmax(a.V3, b.V3), c.V3), d.V3).toPoint,
    ),
  )
