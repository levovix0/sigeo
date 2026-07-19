import ../core/[vectors, points, bounds2, buildutils]
import ../macros/[interfaces]
export implementInterfaceFor

when sigeo_backend == SigeoOpencascade:
  import pkg/opencascade except string



makeInterface Curve2:
  # note that aliases are defined as a part of interface, to force that same aliases are defined for concrete curves (for consistency)
  # todo: {.forceAliases.}
  proc length(this;): Float
  proc pointAt(this; param: FloatParam): Point2
  proc pointAtParam(this; param: FloatParam): Point2  # todo: = this.pointAt(param)
  proc derAt(this; param: FloatParam): V2
  proc derAtParam(this; param: FloatParam): V2  # todo: = this.derAt(param)

  proc bounds(this; a: FloatParam, b: FloatParam): Bounds2
  proc cut(this; a: FloatParam, b: FloatParam): OwnedCurve2

  proc transform(this; m: M4): OwnedCurve2
  proc `*`(this; m: M4): OwnedCurve2  # todo: = this.transform(m)

  # todo
  # proc xAxisIntersection(this; y: Float): seq[FloatParam] {.optional.}
  # proc yAxisIntersection(this; x: Float): seq[FloatParam] {.optional.}

  proc `$`(this;): string

  when sigeo_backend == SigeoOpencascade:
    proc toOpencascadeShape(this;): TopoDS_Shape


proc view*(curves {.byref.}: seq[OwnedCurve2]): lent seq[Curve2] =
  ## yep, this is totaly safe, Curve2 is guarantied to have same binary representation as OwnedCurve2
  cast[ptr seq[Curve2]](curves.addr)[]


proc toOwnedCurve2*(c: Curve2): OwnedCurve2 =
  # todo: move to macros
  assert c.obj != nil
  result.vtable = c.vtable
  c.vtable.dup(c.obj, result.obj)


proc `$`*(c: OwnedCurve2): string =
  `$`(c.Curve2)


# --- generic curve operations ---

proc bounds*(curve: Curve2Concept): Bounds2 =
  ## bounding box of the whole curve
  curve.bounds(0.FloatParam, 1.FloatParam)

proc reverse*(this: Curve2Concept): auto =
  this.cut(1, 0)

proc points*(arc: Curve2Concept, count: int = 32): seq[Point2] =
  for i in 0..count:
    result.add arc.pointAt(i / count)


# --- numerical methods to implement optional interfaces ---

template numericIntersectionImpl(this: Curve2, cond: untyped) =
  var raw: seq[Float]
  var stack: seq[tuple[a0, a1: Float]] = @[(0.Float, 1.Float)]

  const tolerance = 1e-6

  const minParamSpan = 1e-12
  var steps = 0
  const maxSteps = 1_000  # safety limit for pathological cases (e.g. almost-overlapping curves)

  while stack.len > 0 and steps < maxSteps:
    inc steps
    let (a0, a1) = pop stack

    let boxA {.inject.} = this.bounds(a0.FloatParam, a1.FloatParam)
    if not cond: continue

    let sa = max(boxA.size.x, boxA.size.y)

    if (sa <= tolerance) or (a1 - a0 <= minParamSpan):
      result.add (a0 + a1) / 2
    elif a1 - a0 > minParamSpan:
      let m = (a0 + a1) / 2
      stack.add (a0, m)
      stack.add (m, a1)

  if raw.len == 0: return

proc xAxisIntersection*(this: Curve2; y: Float): seq[FloatParam] =
  numericIntersectionImpl(this, boxA.containsY(y))

proc yAxisIntersection*(this: Curve2; x: Float): seq[FloatParam] =
  numericIntersectionImpl(this, boxA.containsX(x))

