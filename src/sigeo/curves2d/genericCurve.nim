import ../core/[vectors, points]
import ./[lineSection, circleArc]

type
  Curve2dKind* = enum
    cuLineSection
    cuCircleArc

  GenericCruve2d* = object
    case kind*: Curve2dKind

    of cuLineSection:
      line: LineSection

    of cuCircleArc:
      circle: CircleArc




