import ../core/[vectors, points, placement]
import ./isurface3

type
  Plane3* = Placement

  CylinderSurface3* = object
    center*: Point3
    axisX*, axisY*, axisZ*: NormalVec3
    radius*: Float

  SphereSurface3* = object
    center*: Point3
    axisX*, axisY*, axisZ*: NormalVec3
    radius*: Float

  ThorusSurface3* = object
    center*: Point3
    axisX*, axisY*, axisZ*: NormalVec3
    innerRadius*, outerRadius*: Float

proc pointAt*(surface: Plane3, uv: Point2): Point3 =
  surface.pos + uv.x * surface.axisX + uv.y * surface.axisY

proc pointAt*(surface: CylinderSurface3, uv: Point2): Point3 =
  surface.center +
  sin(uv.x / surface.radius) * surface.radius * surface.axisX +
  cos(uv.x / surface.radius) * surface.radius * surface.axisY +
  uv.y * surface.axisZ

proc pointAt*(surface: SphereSurface3, uv: Point2): Point3 =
  let r = surface.radius * cos(uv.y / surface.radius)
  surface.center +
  sin(uv.x / r) * r * surface.axisX +
  cos(uv.x / r) * r * surface.axisY +
  sin(uv.y / surface.radius) * surface.radius * surface.axisZ

proc pointAt*(surface: ThorusSurface3, uv: Point2): Point3 =
  let sinX = sin(uv.x / surface.outerRadius)
  let cosX = cos(uv.x / surface.outerRadius)
  let center =
    surface.center +
    sinX * surface.outerRadius * surface.axisX +
    cosX * surface.outerRadius * surface.axisY
  let innerAxisX = sinX * surface.axisX + cosX * surface.axisY
  center +
  cos(uv.y / surface.innerRadius) * surface.innerRadius * innerAxisX +
  sin(uv.y / surface.innerRadius) * surface.innerRadius * surface.axisZ
  
  

Surface3.implementInterfaceFor(Plane3)
Surface3.implementInterfaceFor(CylinderSurface3)
Surface3.implementInterfaceFor(SphereSurface3)
Surface3.implementInterfaceFor(ThorusSurface3)

