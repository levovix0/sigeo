import ../core/[vectors, points]
import ./isurface3

type
  CylinderSurface3* = object
    center*: Point3
    axisX*, axisY*, axisZ*: NormalVec3
    radius*: Float

proc pointAt*(surface: CylinderSurface3, uv: Point2): Point3 =
  surface.center +
  sin(uv.x / surface.radius) * surface.radius * surface.axisX +
  cos(uv.x / surface.radius) * surface.radius * surface.axisY +
  uv.y * surface.axisZ

Surface3.implementInterfaceFor(CylinderSurface3)

