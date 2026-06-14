import std/[math, algorithm, tables]
import ../[core]
import ./[icurve2, paths, lineSection, circleArc, ellipseArc]

type
  PathBuilder2* = object
    path*: Path2



proc add*(this: var Path2, c: LineSection2|CircleArc2|EllipseArc2) =
  if this.curves.len == 0:
    this.curves.add c.toOwnedCurve2
  elif this.pointAtParam(1) ~== c.pointAtParam(0):
    this.curves.add c.toOwnedCurve2
  elif this.pointAtParam(1) ~== c.pointAtParam(1):
    this.curves.add c.toOwnedCurve2
    this.reversed[this.curves.high] = true
  else:
    this.curves.add lineSection(this.pointAtParam(1), c.pointAtParam(0)).toOwnedCurve2
    this.curves.add c.toOwnedCurve2




