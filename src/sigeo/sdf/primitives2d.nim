import std/[math]
import ./[common]


## Parametric 2D SDF primitives, based on Inigo Quilez's article
## "2D distance functions" (https://iquilezles.org/articles/distfunctions2d/)


proc modFloor(x, y: Float): Float {.inline.} =
  x - y * (x / y).floor


proc sdCircle*(center: Point2, radius: Float): Sdf2 =
  ## exact circle
  let half = v2(radius, radius)
  sdf2(
    dist = proc(p: Point2): Float = (p - center).length - radius,
    bounds = bounds2(center - half, center + half),
  )


proc sdBox*(center: Point2, halfSize: V2): Sdf2 =
  ## exact box
  sdf2(
    dist = proc(p: Point2): Float =
      let q = vabs(p.V2 - center.V2) - halfSize
      vmax(q, 0).length + min(max(q.x, q.y), 0)
    ,
    bounds = bounds2(center - halfSize, center + halfSize),
  )


proc sdRoundedBox*(center: Point2, halfSize: V2, radius: Float): Sdf2 =
  ## exact box with rounded corners, overall half-size is `halfSize`
  sdf2(
    dist = proc(p: Point2): Float =
      let q = vabs(p.V2 - center.V2) - halfSize + radius
      min(max(q.x, q.y), 0) + vmax(q, 0).length - radius
    ,
    bounds = bounds2(center - halfSize, center + halfSize),
  )


proc sdRoundedBox*(center: Point2, halfSize: V2, cornerTR, cornerBR, cornerBL, cornerTL: Float): Sdf2 =
  ## exact box with independently rounded corners (clockwise from the top-right one)
  let b = halfSize
  sdf2(
    dist = proc(p: Point2): Float =
      let q = p.V2 - center.V2
      var r: Float
      if q.x > 0:
        r = (if q.y > 0: cornerTR else: cornerBR)
      else:
        r = (if q.y > 0: cornerTL else: cornerBL)
      let w = vabs(q) - b + r
      min(max(w.x, w.y), 0) + vmax(w, 0).length - r
    ,
    bounds = bounds2(center - b, center + b),
  )


proc sdChamferBox*(center: Point2, halfSize: V2, chamfer: Float): Sdf2 =
  ## exact box with chamfered (bevelled) corners
  let b = halfSize
  const k = 1.0 - 2.0.sqrt
  sdf2(
    dist = proc(p: Point2): Float =
      var p = vabs(p.V2 - center.V2) - b
      if p.y > p.x: p = v2(p.y, p.x)
      p.y += chamfer
      if p.y < 0 and p.y + p.x*k < 0:
        return p.x
      if p.x < p.y:
        return (p.x + p.y) * 0.5.sqrt
      p.length
    ,
    bounds = bounds2(center - b, center + b),
  )


proc sdOrientedBox*(a, b: Point2, thickness: Float): Sdf2 =
  ## exact box from point `a` to point `b` of `thickness` thickness
  let l = (b.V2 - a.V2).length
  let d = (b.V2 - a.V2) / l
  let mid = (a.V2 + b.V2) * 0.5
  let half = v2(l, thickness) * 0.5
  sdf2(
    dist = proc(p: Point2): Float =
      var q = p.V2 - mid
      q = v2(d.x*q.x + d.y*q.y, -d.y*q.x + d.x*q.y)
      q = vabs(q) - half
      vmax(q, 0).length + min(max(q.x, q.y), 0)
    ,
    bounds = bounds2(vmin(a.V2, b.V2).toPoint, vmax(a.V2, b.V2).toPoint).expanded(thickness / 2),
  )


proc sdSegment*(a, b: Point2): Sdf2 =
  ## exact 2D distance to a line segment (unsigned, distance to the 1D shape itself)
  let
    ba = b.V2 - a.V2
    dot2ba = ba.dot2
  sdf2(
    dist = proc(p: Point2): Float =
      let pa = p.V2 - a.V2
      let h = (pa.dot(ba) / dot2ba).clamp(0.0, 1.0)
      (pa - ba * h).length
    ,
    bounds = bounds2(vmin(a.V2, b.V2).toPoint, vmax(a.V2, b.V2).toPoint),
  )


proc sdCapsule*(a, b: Point2, radius: Float): Sdf2 =
  ## exact 2D capsule (segment with round ends)
  let seg = sdSegment(a, b)
  sdf2(
    dist = proc(p: Point2): Float = seg.dist(p) - radius,
    bounds = seg.bounds2.expanded(radius),
  )


proc sdUnevenCapsule*(center: Point2, bottomRadius, topRadius, height: Float): Sdf2 =
  ## exact capsule along Y: sphere of `bottomRadius` at `center` connected
  ## with a sphere of `topRadius` at `center + (0, height)`
  let r1 = bottomRadius
  let r2 = topRadius
  let h = height
  let b = (r1 - r2) / h
  let a = (1 - b*b).sqrt
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.x = p.x.abs
      let k = p.dot(v2(-b, a))
      if k < 0: return p.length - r1
      if k > a*h: return (p - v2(0, h)).length - r2
      p.dot(v2(a, b)) - r1
    ,
    bounds = bounds2(
      point2(center.x - max(r1, r2), center.y - r1),
      point2(center.x + max(r1, r2), center.y + h + r2),
    ),
  )


proc sdRhombus*(center: Point2, halfDiagonals: V2): Sdf2 =
  ## exact rhombus with diagonals along the axes
  let b = v2(halfDiagonals.x, -halfDiagonals.y)
  let dot2b = b.dot2
  sdf2(
    dist = proc(p: Point2): Float =
      var p = vabs(p.V2 - center.V2)
      let h = (b.dot(p) + b.y*b.y).clamp(0, dot2b) / dot2b
      p -= b * v2(h, h - 1)
      p.length * p.x.sign
    ,
    bounds = bounds2(center - halfDiagonals, center + halfDiagonals),
  )


proc sdTrapezoid*(center: Point2, bottomHalfWidth, topHalfWidth, halfHeight: Float): Sdf2 =
  ## exact isosceles trapezoid: `bottomHalfWidth` at `center.y - halfHeight`,
  ## `topHalfWidth` at `center.y + halfHeight`
  let r1 = bottomHalfWidth
  let r2 = topHalfWidth
  let he = halfHeight
  let k1 = v2(r2, he)
  let k2 = v2(r2 - r1, 2*he)
  let dot2k2 = k2.dot2
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.x = p.x.abs
      let ca = v2(p.x - min(p.x, (if p.y < 0: r1 else: r2)), p.y.abs - he)
      let f = ((k1 - p).dot(k2) / dot2k2).clamp(0, 1)
      let cb = p - k1 + k2 * f
      let s: Float = (if cb.x < 0 and ca.y < 0: -1 else: 1)
      s * min(ca.dot2, cb.dot2).sqrt
    ,
    bounds = bounds2(
      point2(center.x - max(r1, r2), center.y - he),
      point2(center.x + max(r1, r2), center.y + he),
    ),
  )


proc sdParallelogram*(center: Point2, halfWidth, halfHeight, skew: Float): Sdf2 =
  ## exact parallelogram, `skew` shifts the top edge towards +X
  let wi = halfWidth
  let he = halfHeight
  let e = v2(skew, he)
  let dot2e = e.dot2
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      if p.y < 0: p = -p
      var w = p - e
      w.x -= w.x.clamp(-wi, wi)
      var d = v2(w.dot2, -w.y)
      let s = p.x*e.y - p.y*e.x
      if s < 0: p = -p
      var v = p - v2(wi, 0)
      v -= e * (v.dot(e) / dot2e).clamp(-1, 1)
      d = vmin(d, v2(v.dot2, wi*he - s.abs))
      d.x.sqrt * (-d.y).sign
    ,
    bounds = bounds2(
      point2(center.x - wi - skew.abs, center.y - he),
      point2(center.x + wi + skew.abs, center.y + he),
    ),
  )


proc sdEquilateralTriangle*(center: Point2, halfSide: Float): Sdf2 =
  ## exact equilateral triangle pointing up, `halfSide` is the half of the side length
  let r = halfSide
  const k = 3.0.sqrt
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.x = p.x.abs - r
      p.y = p.y + r/k
      if p.x + k*p.y > 0:
        p = v2((p.x - k*p.y) / 2, (-k*p.x - p.y) / 2)
      p.x -= p.x.clamp(-2*r, 0)
      -p.length * p.y.sign
    ,
    bounds = bounds2(
      point2(center.x - r, center.y - r/k),
      point2(center.x + r, center.y + 2*r/k),
    ),
  )


proc sdTriangleIsosceles*(center: Point2, halfBase, height: Float): Sdf2 =
  ## exact isosceles triangle: base from `center - (halfBase, 0)` to `center + (halfBase, 0)`,
  ## apex at `center + (0, height)`
  let q = v2(halfBase, height)
  let dot2q = q.dot2
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.y = height - p.y  # the original formula has the apex at the origin
      p.x = p.x.abs
      let a = p - q * (p.dot(q) / dot2q).clamp(0, 1)
      let b = p - q * v2((p.x / q.x).clamp(0, 1), 1)
      let s = -q.y.sign
      let d = vmin(
        v2(a.dot2, s*(p.x*q.y - p.y*q.x)),
        v2(b.dot2, s*(p.y - q.y)),
      )
      -d.x.sqrt * d.y.sign
    ,
    bounds = bounds2(
      point2(center.x - halfBase, center.y),
      point2(center.x + halfBase, center.y + height),
    ),
  )


proc sdTriangle*(p0, p1, p2: Point2): Sdf2 =
  ## exact signed distance to an arbitrary triangle
  let
    e0 = p1.V2 - p0.V2
    e1 = p2.V2 - p1.V2
    e2 = p0.V2 - p2.V2
    dot2e0 = e0.dot2
    dot2e1 = e1.dot2
    dot2e2 = e2.dot2
    s = (e0.x*e2.y - e0.y*e2.x).sign
  var bounds: Bounds2
  for pt in [p0, p1, p2]: bounds.add pt

  sdf2(
    dist = proc(p: Point2): Float =
      let
        v0 = p.V2 - p0.V2
        v1 = p.V2 - p1.V2
        v2v = p.V2 - p2.V2
      let
        pq0 = v0 - e0 * (v0.dot(e0) / dot2e0).clamp(0, 1)
        pq1 = v1 - e1 * (v1.dot(e1) / dot2e1).clamp(0, 1)
        pq2 = v2v - e2 * (v2v.dot(e2) / dot2e2).clamp(0, 1)
      let d = vmin(
        vmin(
          v2(pq0.dot2, s*(v0.x*e0.y - v0.y*e0.x)),
          v2(pq1.dot2, s*(v1.x*e1.y - v1.y*e1.x)),
        ),
        v2(pq2.dot2, s*(v2v.x*e2.y - v2v.y*e2.x)),
      )
      -d.x.sqrt * d.y.sign
    ,
    bounds = bounds,
  )


proc sdPolygon*(points: openArray[Point2]): Sdf2 =
  ## exact signed distance to a closed polygon (a sketch made of a closed polyline)
  ## the points are captured by the SDF
  assert points.len >= 3
  let pts = @points
  let n = pts.len
  var bounds: Bounds2
  for pt in pts: bounds.add pt

  sdf2(
    dist = proc(p: Point2): Float =
      var d = (p.V2 - pts[0].V2).dot2
      var s = 1.0
      for i in 0..<n:
        let j = (i + n - 1) mod n
        let e = pts[j].V2 - pts[i].V2
        let w = p.V2 - pts[i].V2
        let dot2e = e.dot2
        let b = w - e * (if dot2e > 0: (w.dot(e) / dot2e).clamp(0, 1) else: 0.0)
        d = min(d, b.dot2)
        # crossing counter for the inside/outside sign
        let c1 = p.y >= pts[i].y
        let c2 = p.y < pts[j].y
        let c3 = e.x*w.y > e.y*w.x
        if (c1 and c2 and c3) or ((not c1) and (not c2) and (not c3)):
          s = -s
      s * d.sqrt
    ,
    bounds = bounds,
  )


proc sdPolyline*(points: openArray[Point2], closed = false): Sdf2 =
  ## unsigned distance to a polyline (a wire, not a solid: useful in combination
  ## with other SDFs, cannot be polygonized on its own)
  ## the points are captured by the SDF
  assert points.len >= 2
  let pts = @points
  let n = pts.len
  var bounds: Bounds2
  for pt in pts: bounds.add pt

  sdf2(
    dist = proc(p: Point2): Float =
      var d = Float(Inf)
      let segments =
        if closed: n
        else: n - 1
      for i in 0..<segments:
        let a = pts[i].V2
        let ba = pts[(i + 1) mod n].V2 - a
        let pa = p.V2 - a
        let dot2ba = ba.dot2
        let h =
          if dot2ba > 0: (pa.dot(ba) / dot2ba).clamp(0, 1)
          else: 0.0
        d = min(d, (pa - ba*h).dot2)
      d.sqrt
    ,
    bounds = bounds,
  )


proc sdBezier*(a, b, c: Point2): Sdf2 =
  ## exact unsigned distance to a quadratic bezier curve (from `a` to `c` through `b`)
  let
    pa0 = a.V2
    pb = b.V2
    pc = c.V2
  var bounds: Bounds2
  for pt in [a, b, c]: bounds.add pt

  sdf2(
    dist = proc(p: Point2): Float =
      let
        vA = pb - pa0
        vB = pa0 - 2.0*pb + pc
        vC = vA * 2.0
        vD = pa0 - p.V2
      let dot2vB = vB.dot2
      if dot2vB == 0:
        # degenerate bezier: a straight line from `a` to `c`
        let ba = pc - pa0
        let ppa = p.V2 - pa0
        let hh = (ppa.dot(ba) / ba.dot2).clamp(0, 1)
        return (ppa - ba*hh).length
      let kk = 1.0 / dot2vB
      let kx = kk * vA.dot(vB)
      let ky = kk * (2.0*vA.dot2 + vD.dot(vB)) / 3.0
      let kz = kk * vD.dot(vA)
      let pp = ky - kx*kx
      let q = kx*(2.0*kx*kx - 3.0*ky) + kz
      let h = q*q + 4.0*pp*pp*pp
      var res: Float
      if h >= 0:
        let hh = h.sqrt
        let x = (v2(hh, -hh) - q) / 2.0
        let uv = v2(x.x.sign * x.x.abs.pow(1.0/3.0), x.y.sign * x.y.abs.pow(1.0/3.0))
        let t = (uv.x + uv.y - kx).clamp(0, 1)
        res = (vD + (vC + vB*t)*t).dot2
      else:
        let z = (-pp).sqrt
        let v = (q / (pp*z*2.0)).clamp(-1, 1).arccos / 3.0
        let m = v.cos
        let n = v.sin * 1.732050808
        let tt = v3(m + m, -n - m, n - m) * z - v3(kx, kx, kx)
        let t0 = tt.x.clamp(0, 1)
        let t1 = tt.y.clamp(0, 1)
        res = min(
          (vD + (vC + vB*t0)*t0).dot2,
          (vD + (vC + vB*t1)*t1).dot2,
        )
      res.sqrt
    ,
    bounds = bounds,
  )


proc sdPentagon*(center: Point2, radius: Float): Sdf2 =
  ## exact regular pentagon with a flat top edge (pointy bottom), `radius` is the apothem
  const k = v3(0.809016994, 0.587785252, 0.726542528)
  let r = radius
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.x = p.x.abs
      p -= 2 * min(-k.x*p.x + k.y*p.y, 0) * v2(-k.x, k.y)
      p -= 2 * min( k.x*p.x + k.y*p.y, 0) * v2( k.x, k.y)
      p -= v2(p.x.clamp(-r*k.z, r*k.z), r)
      p.length * p.y.sign
    ,
    bounds = bounds2(
      point2(center.x - 1.3*r, center.y - 1.3*r),
      point2(center.x + 1.3*r, center.y + 1.3*r),
    ),
  )


proc sdHexagon*(center: Point2, radius: Float): Sdf2 =
  ## exact regular hexagon with flat top and bottom edges (pointy left and right),
  ## `radius` is the apothem (the distance from the center to the flat sides)
  const k = v3(-0.866025404, 0.5, 0.577350269)
  let r = radius
  sdf2(
    dist = proc(p: Point2): Float =
      var p = vabs(p.V2 - center.V2)
      p -= 2 * min(k.x*p.x + k.y*p.y, 0) * v2(k.x, k.y)
      p -= v2(p.x.clamp(-k.z*r, k.z*r), r)
      p.length * p.y.sign
    ,
    bounds = bounds2(
      point2(center.x - 1.1547005*r, center.y - r),
      point2(center.x + 1.1547005*r, center.y + r),
    ),
  )


proc sdOctogon*(center: Point2, radius: Float): Sdf2 =
  ## exact regular octagon with a flat top edge, `radius` is the apothem
  const k = v3(-0.9238795325, 0.3826834323, 0.4142135623)
  let r = radius
  sdf2(
    dist = proc(p: Point2): Float =
      var p = vabs(p.V2 - center.V2)
      p -= 2 * min( k.x*p.x + k.y*p.y, 0) * v2( k.x, k.y)
      p -= 2 * min(-k.x*p.x + k.y*p.y, 0) * v2(-k.x, k.y)
      p -= v2(p.x.clamp(-k.z*r, k.z*r), r)
      p.length * p.y.sign
    ,
    bounds = bounds2(
      point2(center.x - 1.1*r, center.y - 1.1*r),
      point2(center.x + 1.1*r, center.y + 1.1*r),
    ),
  )


proc sdHexagram*(center: Point2, radius: Float): Sdf2 =
  ## exact hexagram (six-pointed star) with the outer points at the radius of `2*radius`
  ## (a point at the top), `radius` is the distance to the flat inner corners ring
  const k = v4(-0.5, 0.8660254038, 0.5773502692, 1.7320508076)
  let r = radius
  sdf2(
    dist = proc(p: Point2): Float =
      var p = vabs(p.V2 - center.V2)
      p -= 2 * min(k.x*p.x + k.y*p.y, 0) * v2(k.x, k.y)
      p -= 2 * min(k.y*p.x + k.x*p.y, 0) * v2(k.y, k.x)
      p -= v2(p.x.clamp(r*k.z, r*k.w), r)
      p.length * p.y.sign
    ,
    bounds = bounds2(
      point2(center.x - k.w*r, center.y - 2*r),
      point2(center.x + k.w*r, center.y + 2*r),
    ),
  )


proc sdPentagram*(center: Point2, radius: Float): Sdf2 =
  ## exact pentagram (five-pointed star), `radius` is the circumradius
  const
    k1x = cos(PI/5)
    k2x = sin(PI/10)
    k1y = sin(PI/5)
    k2y = cos(PI/10)
    k1z = tan(PI/5)
  let r = radius
  let
    v1 = v2( k1x, -k1y)
    v2v = v2(-k1x, -k1y)
    v3 = v2( k2x, -k2y)
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.x = p.x.abs
      p -= 2 * max(v1.dot(p), 0) * v1
      p -= 2 * max(v2v.dot(p), 0) * v2v
      p.x = p.x.abs
      p.y -= r
      (p - v3 * p.dot(v3).clamp(0, k1z*r)).length * (p.y*v3.x - p.x*v3.y).sign
    ,
    bounds = bounds2(
      point2(center.x - r, center.y - r),
      point2(center.x + r, center.y + r),
    ),
  )


proc sdStar*(center: Point2, radius: Float, points: int, innerCorners: Float): Sdf2 =
  ## exact regular star with `points` outer corners
  ## `innerCorners` (m) is between 2 and `points`, 2 gives the sharpest inner corners
  let n = points.Float
  let m = innerCorners
  let an = Pi / n
  let en = Pi / m
  let acs = v2(an.cos, an.sin)
  let ecs = v2(en.cos, en.sin)
  let r = radius
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      let bn = modFloor(arctan2(p.x, p.y), 2*an) - an
      p = p.length * v2(bn.cos, bn.sin.abs)
      p -= r * acs
      p += ecs * (-p.dot(ecs)).clamp(0, r*acs.y/ecs.y)
      p.length * p.x.sign
    ,
    bounds = bounds2(
      point2(center.x - r, center.y - r),
      point2(center.x + r, center.y + r),
    ),
  )


proc sdPie*(center: Point2, apertureSinCos: V2, radius: Float): Sdf2 =
  ## exact pie (circle sector), the wedge is centered on the +Y direction
  ## `apertureSinCos` is (sin, cos) of the half-aperture angle
  let c = apertureSinCos
  let r = radius
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.x = p.x.abs
      let l = p.length - r
      let m = (p - c * p.dot(c).clamp(0, r)).length
      max(l, m * (c.y*p.x - c.x*p.y).sign)
    ,
    bounds = bounds2(
      point2(center.x - r, center.y - r),
      point2(center.x + r, center.y + r),
    ),
  )


proc sdCutDisk*(center: Point2, radius, cutHeight: Float): Sdf2 =
  ## exact disk with the part below the `center.y + cutHeight` line cut off
  ## (the dome above the line is kept; the flat edge is at `center.y + cutHeight`)
  let r = radius
  let h = cutHeight
  let w = (r*r - h*h).sqrt
  let halfWidth = (if h >= 0: w else: r)
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.x = p.x.abs
      let s = max((h - r)*p.x*p.x + w*w*(h + r - 2*p.y), h*p.x - w*p.y)
      if s < 0: p.length - r
      elif p.x < w: h - p.y
      else: (p - v2(w, h)).length
    ,
    bounds = bounds2(
      point2(center.x - halfWidth, center.y + h),
      point2(center.x + halfWidth, center.y + r),
    ),
  )


proc sdArc*(center: Point2, apertureSinCos: V2, ringRadius, tubeRadius: Float): Sdf2 =
  ## exact arc: a bent tube of `tubeRadius` thickness along a circle of `ringRadius`,
  ## the arc is centered on the +Y direction
  ## `apertureSinCos` is (sin, cos) of the half-aperture angle
  let sc = apertureSinCos
  let ra = ringRadius
  let rb = tubeRadius
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.x = p.x.abs
      ((if sc.y*p.x > sc.x*p.y: (p - sc*ra).length else: (p.length - ra).abs)) - rb
    ,
    bounds = bounds2(
      point2(center.x - ra*sc.x - rb, center.y + ra*sc.y - rb),
      point2(center.x + ra*sc.x + rb, center.y + ra + rb),
    ),
  )


proc sdRing*(center: Point2, gapDirection: NormalVec2, radius, thickness: Float): Sdf2 =
  ## exact ring with a gap in the `gapDirection`
  ## (the formula folds the space with abs(p.x), which mirrors the gap direction)
  let n = v2(gapDirection.V2.x, -gapDirection.V2.y)
  let r = radius
  let th = thickness
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.x = p.x.abs
      p = v2(n.x*p.x - n.y*p.y, n.y*p.x + n.x*p.y)
      max(
        (p.length - r).abs - th*0.5,
        v2(p.x, max(0, (r - p.y).abs - th*0.5)).length * p.x.sign,
      )
    ,
    bounds = bounds2(
      point2(center.x - r - th, center.y - r - th),
      point2(center.x + r + th, center.y + r + th),
    ),
  )


proc sdHorseshoe*(center: Point2, apertureSinCos: V2, radius, halfThickness, rounding: Float): Sdf2 =
  ## exact horseshoe opening towards -Y, `apertureSinCos` is (sin, cos) of the aperture
  let c = apertureSinCos
  let r = radius
  let w = v2(halfThickness, rounding)
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.x = p.x.abs
      let l = p.length
      p = v2(-c.x*p.x + c.y*p.y, c.y*p.x + c.x*p.y)
      p = v2(
        (if p.y > 0 or p.x > 0: p.x else: l * (-c.x).sign),
        (if p.x > 0: p.y else: l),
      )
      p = v2(p.x, (p.y - r).abs) - w
      vmax(p, 0).length + min(max(p.x, p.y), 0)
    ,
    bounds = bounds2(
      point2(center.x - r - w.x - w.y, center.y - r - w.x - w.y),
      point2(center.x + r + w.x + w.y, center.y + r + w.x + w.y),
    ),
  )


proc sdVesica*(center: Point2, halfWidth, halfHeight: Float): Sdf2 =
  ## exact vesica (lens): horizontal pointed oval with the tips at `center ± (halfWidth, 0)`
  ## and `halfHeight` half-height at the middle (requires `halfHeight <= halfWidth`)
  ## rotate the shape for a vertical lens
  let w = halfWidth
  let h = halfHeight
  let d = 0.5*(w*w - h*h) / h
  sdf2(
    dist = proc(p: Point2): Float =
      var p = vabs(p.V2 - center.V2)
      if w*p.y < d*(p.x - w):
        return (p - v2(w, 0)).length
      (p - v2(0, -d)).length - (d + h)
    ,
    bounds = bounds2(center - v2(w, h), center + v2(w, h)),
  )


proc sdOrientedVesica*(a, b: Point2, width: Float): Sdf2 =
  ## exact vesica (lens) built on the segment `a`-`b` of `width` width
  let w = width
  let r = 0.5*(b.V2 - a.V2).length
  let d = 0.5*(r*r - w*w) / w
  let v = (b.V2 - a.V2) / r
  let c = (a.V2 + b.V2) * 0.5
  sdf2(
    dist = proc(p: Point2): Float =
      let pc = p.V2 - c
      let q = 0.5 * vabs(v2(v.y*pc.x - v.x*pc.y, v.x*pc.x + v.y*pc.y))
      let hh =
        if r*q.x < d*(q.y - r): v3(0, r, 0)
        else: v3(-d, 0, d + w)
      (q - hh.xy).length - hh.z
    ,
    bounds = bounds2(vmin(a.V2, b.V2).toPoint, vmax(a.V2, b.V2).toPoint).expanded(d + w),
  )


proc sdMoon*(center: Point2, offset, outerRadius, innerRadius: Float): Sdf2 =
  ## exact moon: sphere of `outerRadius` with a spherical bite of `innerRadius`
  ## taken from the +X side, the bite center is `offset` away along X
  let d = offset
  let ra = outerRadius
  let rb = innerRadius
  let a = (ra*ra - rb*rb + d*d) / (2*d)
  let b = max(ra*ra - a*a, 0).sqrt
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.y = p.y.abs
      if d*(p.x*b - p.y*a) > d*d * max(b - p.y, 0):
        return (p - v2(a, b)).length
      max(p.length - ra, -((p - v2(d, 0)).length - rb))
    ,
    bounds = bounds2(
      point2(center.x - ra, center.y - ra),
      point2(center.x + ra, center.y + ra),
    ),
  )


proc sdRoundedCross*(center: Point2, h: Float): Sdf2 =
  ## exact rounded cross with four bulged arms, inscribed into the (-1..1) box;
  ## `h` in (0..1] controls the bulge of the arms
  let k = 0.5*(h + 1.0/h)
  sdf2(
    dist = proc(p: Point2): Float =
      var p = vabs(p.V2 - center.V2)
      if p.x < 1 and p.y < p.x*(k - h) + h:
        return k - (p - v2(1, k)).length
      (min((p - v2(0, h)).dot2, (p - v2(1, 0)).dot2)).sqrt
    ,
    bounds = bounds2(
      point2(center.x - k, center.y - k),
      point2(center.x + k, center.y + k),
    ),
  )


proc sdCross*(center: Point2, halfThickness, halfLength, rounding: Float): Sdf2 =
  ## cross (plus sign) with arms of `halfLength` half-length and `halfThickness`
  ## half-thickness, rounded by `rounding`
  let b = v2(halfThickness, halfLength)
  let r = rounding
  let extent = max(b.x, b.y) + r
  sdf2(
    dist = proc(p: Point2): Float =
      var p = vabs(p.V2 - center.V2)
      if p.y > p.x: p = v2(p.y, p.x)
      let q = p - b
      let k = max(q.y, q.x)
      let w =
        if k > 0: q
        else: v2(b.y - p.x, -k)
      k.sign * vmax(w, 0).length + r
    ,
    bounds = bounds2(center - v2(extent, extent), center + v2(extent, extent)),
  )


proc sdRoundedX*(center: Point2, width, rounding: Float): Sdf2 =
  ## exact X shape (crossed diagonals) of `width` width, rounded by `rounding`
  let w = width
  let r = rounding
  sdf2(
    dist = proc(p: Point2): Float =
      let p = vabs(p.V2 - center.V2)
      (p - min(p.x + p.y, w) * 0.5).length - r
    ,
    bounds = bounds2(
      point2(center.x - w/2 - r, center.y - w/2 - r),
      point2(center.x + w/2 + r, center.y + w/2 + r),
    ),
  )


proc sdEgg*(center: Point2, halfHeight, bottomRadius, topRadius, bulge: Float): Sdf2 =
  ## exact egg shape: circles of `bottomRadius` (at `center`) and `topRadius`
  ## (at `center + (0, halfHeight)`) connected with a bulging side surface
  let he = halfHeight
  let ra = bottomRadius
  let rb = topRadius
  let bu = bulge
  # precomputed for any given shape
  let r = 0.5*(he + ra + rb) / bu
  let da = r - ra
  let db = r - rb
  let yy = (db*db - da*da - he*he) / (2*he)
  let xx = (da*da - yy*yy).sqrt
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.x = p.x.abs
      let k = p.y*xx - p.x*yy
      if k > 0 and k < he*(p.x + xx):
        return (p + v2(xx, yy)).length - r
      min(p.length - ra, v2(p.x, p.y - he).length - rb)
    ,
    bounds = bounds2(
      point2(center.x - max(ra, rb), center.y - ra),
      point2(center.x + max(ra, rb), center.y + he + rb),
    ),
  )


proc sdHeart*(center: Point2): Sdf2 =
  ## exact heart, fits into a box of roughly (-1..1, -0.2..1.2) around the center
  sdf2(
    dist = proc(p: Point2): Float =
      var p = p.V2 - center.V2
      p.x = p.x.abs
      if p.y + p.x > 1:
        return (p - v2(0.25, 0.75)).length - 2.0.sqrt / 4.0
      let m = max(p.x + p.y, 0)
      sqrt(min((p - v2(0, 1)).dot2, (p - v2(m*0.5, m*0.5)).dot2)) * (p.x - p.y).sign
    ,
    bounds = bounds2(
      point2(center.x - 1.2, center.y - 1.2),
      point2(center.x + 1.2, center.y + 1.2),
    ),
  )


proc sdEllipse*(center: Point2, radii: V2): Sdf2 =
  ## exact ellipse
  let ab = radii
  sdf2(
    dist = proc(p: Point2): Float =
      var p = vabs(p.V2 - center.V2)
      var ab = ab
      if p.x > p.y:
        p = v2(p.y, p.x)
        ab = v2(ab.y, ab.x)
      let l = ab.y*ab.y - ab.x*ab.x
      let m = ab.x*p.x / l
      let m2 = m*m
      let n = ab.y*p.y / l
      let n2 = n*n
      let c = (m2 + n2 - 1.0) / 3.0
      let c3 = c*c*c
      let q = c3 + m2*n2*2.0
      let d = c3 + m2*n2
      let g = m + m*n2
      var co: Float
      if d < 0:
        let hh = (q / c3).clamp(-1, 1).arccos / 3.0
        let s = hh.cos
        let t = hh.sin * 3.0.sqrt
        let rx = (-c*(s + t + 2.0) + m2).sqrt
        let ry = (-c*(s - t + 2.0) + m2).sqrt
        co = (ry + l.sign * rx + g.abs / (rx*ry) - m) / 2.0
      else:
        let hh = 2.0*m*n*d.sqrt
        let s = (q + hh).sign * (q + hh).abs.pow(1.0/3.0)
        let u = (q - hh).sign * (q - hh).abs.pow(1.0/3.0)
        let rx = -s - u - c*4.0 + 2.0*m2
        let ry = (s - u) * 3.0.sqrt
        let rm = (rx*rx + ry*ry).sqrt
        co = (ry / (rm - rx).sqrt + 2.0*g/rm - m) / 2.0
      let rr = ab * v2(co, (1.0 - co*co).sqrt)
      (rr - p).length * (p.y - rr.y).sign
    ,
    bounds = bounds2(center - ab, center + ab),
  )
