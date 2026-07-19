import ../core/[vectors, points, placement]
import ./isurface3

type
  Plane3* = Placement

proc pointAt*(surface: Plane3, uv: Point2): Point3 =
  surface.pos + uv.x * surface.axisX + uv.y * surface.axisY

Surface3.implementInterfaceFor(Plane3)

